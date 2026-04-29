use std::collections::{BTreeMap, BTreeSet};

use chrono::{Datelike, Duration, Local, NaiveDate, NaiveTime};

use crate::error::Result;
use crate::models::{
    AiDraftKind, AiParseDraft, AiParseInput, AiParseResult, AiServiceConfig, ParseContext,
};

use super::orchestrator::ParserEngine;

#[derive(Debug, Clone)]
struct TimePoint {
    period: Option<String>,
    hour: u32,
    minute: u32,
    start: usize,
    end: usize,
}

#[derive(Debug, Clone)]
struct TimeRange {
    start_time: String,
    end_time: String,
    duration_minutes: i64,
}

#[derive(Debug, Clone)]
struct Money {
    amount: String,
    explicit_unit: bool,
    start: usize,
    end: usize,
}

#[derive(Debug, Default, Clone)]
pub struct RuleParserEngine;

impl ParserEngine for RuleParserEngine {
    fn parse(
        &self,
        input: &AiParseInput,
        context: &ParseContext,
        _config: Option<&AiServiceConfig>,
    ) -> Result<AiParseResult> {
        if input.raw_text.trim().is_empty() {
            return Ok(AiParseResult::empty(
                "rule",
                Some("empty input".to_string()),
            ));
        }

        let context_date = input.resolved_context_date();
        let segments = split_segments(&input.raw_text);
        let mut items = Vec::new();
        let mut warnings = Vec::new();

        for segment in segments {
            let occurred_on = resolve_date(&segment, &context_date);
            let draft = try_parse_learning(&segment, &occurred_on, context)
                .or_else(|| try_parse_income(&segment, &occurred_on, context))
                .or_else(|| try_parse_expense(&segment, &occurred_on, context))
                .or_else(|| try_parse_time(&segment, &occurred_on, context));

            match draft {
                Some(draft) => {
                    if let Some(warning) = &draft.warning {
                        warnings.push(format!("{}: {}", draft.kind.as_str(), warning));
                    }
                    items.push(draft);
                }
                None => {
                    let mut payload = BTreeMap::new();
                    payload.insert("date".to_string(), occurred_on.clone());
                    payload.insert("raw".to_string(), segment.clone());
                    items.push(AiParseDraft::new(
                        AiDraftKind::Unknown,
                        payload,
                        0.2,
                        "rule",
                        Some("unrecognized".to_string()),
                    ));
                    warnings.push(format!("unrecognized line: {segment}"));
                }
            }
        }

        Ok(AiParseResult {
            request_id: uuid::Uuid::now_v7().to_string(),
            items,
            warnings,
            parser_used: "rule".to_string(),
        })
    }
}

fn split_segments(raw_text: &str) -> Vec<String> {
    let mut normalized = raw_text.replace('\r', "\n");
    for token in ["；", ";", "。", "！", "？"] {
        normalized = normalized.replace(token, "\n");
    }
    for token in ["然后", "接着", "另外", "还有", "并且"] {
        normalized = normalized.replace(token, "\n");
    }

    normalized
        .split('\n')
        .map(str::trim)
        .map(|segment| {
            segment
                .trim_start_matches('-')
                .trim_start_matches('•')
                .trim()
                .to_string()
        })
        .filter(|segment| !segment.is_empty())
        .collect()
}

fn try_parse_learning(
    line: &str,
    occurred_on: &str,
    context: &ParseContext,
) -> Option<AiParseDraft> {
    if !contains_any(
        line,
        &[
            "学习", "复习", "阅读", "课程", "刷题", "听课", "看书", "study", "learn",
        ],
    ) {
        return None;
    }

    let range = parse_time_range(line);
    let mut duration_minutes = parse_duration_minutes(line);
    if duration_minutes.is_none() {
        duration_minutes = range.as_ref().map(|value| value.duration_minutes);
    }

    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), occurred_on.to_string());
    payload.insert("content".to_string(), extract_learning_content(line));
    payload.insert(
        "application_level".to_string(),
        infer_learning_level(line).to_string(),
    );
    if let Some(range) = range {
        payload.insert("start_time".to_string(), range.start_time);
        payload.insert("end_time".to_string(), range.end_time);
    }
    if let Some(duration_minutes) = duration_minutes {
        payload.insert("duration_minutes".to_string(), duration_minutes.to_string());
    } else {
        payload.insert("duration_minutes".to_string(), "60".to_string());
    }

    attach_scores_and_ai_ratio(&mut payload, line);
    attach_context_mentions(&mut payload, line, context);

    let warning = if duration_minutes.is_none() {
        Some("defaulted duration to 60m".to_string())
    } else {
        None
    };

    Some(AiParseDraft::new(
        AiDraftKind::Learning,
        payload,
        if warning.is_some() { 0.64 } else { 0.84 },
        "rule",
        warning,
    ))
}

fn try_parse_income(line: &str, occurred_on: &str, context: &ParseContext) -> Option<AiParseDraft> {
    if !contains_any(
        line,
        &[
            "收入", "工资", "到账", "回款", "奖金", "报销", "转入", "income",
        ],
    ) {
        return None;
    }
    let money = extract_money(line)?;
    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), occurred_on.to_string());
    payload.insert("amount".to_string(), money.amount.clone());
    payload.insert(
        "source".to_string(),
        extract_income_source(line, &money)
            .filter(|value| !value.is_empty())
            .unwrap_or_else(|| "收入".to_string()),
    );
    payload.insert("type".to_string(), infer_income_type(line).to_string());
    if contains_any(line, &["被动", "自动收入", "passive"]) {
        payload.insert("is_passive".to_string(), "true".to_string());
    }

    attach_ai_ratio(&mut payload, line);
    attach_context_mentions(&mut payload, line, context);

    Some(AiParseDraft::new(
        AiDraftKind::Income,
        payload,
        if money.explicit_unit { 0.84 } else { 0.74 },
        "rule",
        None,
    ))
}

fn try_parse_expense(
    line: &str,
    occurred_on: &str,
    context: &ParseContext,
) -> Option<AiParseDraft> {
    if !contains_any(
        line,
        &[
            "花", "支出", "消费", "买", "付款", "付了", "开销", "expense",
        ],
    ) {
        return None;
    }
    let money = extract_money(line)?;
    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), occurred_on.to_string());
    payload.insert("amount".to_string(), money.amount.clone());
    let note = strip_money_phrase(line, &money);
    payload.insert(
        "category".to_string(),
        infer_expense_category(&note).to_string(),
    );
    payload.insert(
        "note".to_string(),
        if note.is_empty() {
            line.trim().to_string()
        } else {
            note
        },
    );

    attach_ai_ratio(&mut payload, line);
    attach_context_mentions(&mut payload, line, context);

    Some(AiParseDraft::new(
        AiDraftKind::Expense,
        payload,
        if money.explicit_unit { 0.84 } else { 0.74 },
        "rule",
        None,
    ))
}

fn try_parse_time(line: &str, occurred_on: &str, context: &ParseContext) -> Option<AiParseDraft> {
    let range = parse_time_range(line);
    let duration_minutes =
        parse_duration_minutes(line).or_else(|| range.as_ref().map(|value| value.duration_minutes));
    if range.is_none() && duration_minutes.is_none() {
        return None;
    }

    let mut payload = BTreeMap::new();
    payload.insert("date".to_string(), occurred_on.to_string());
    payload.insert(
        "description".to_string(),
        extract_time_description(line).unwrap_or_else(|| line.trim().to_string()),
    );
    payload.insert(
        "category".to_string(),
        infer_time_category(line).to_string(),
    );
    if let Some(range) = range {
        payload.insert("start_time".to_string(), range.start_time);
        payload.insert("end_time".to_string(), range.end_time);
    }
    if let Some(duration_minutes) = duration_minutes {
        payload.insert("duration_minutes".to_string(), duration_minutes.to_string());
    }

    attach_scores_and_ai_ratio(&mut payload, line);
    attach_context_mentions(&mut payload, line, context);

    let warning = if !payload.contains_key("start_time") {
        Some("no explicit time range".to_string())
    } else {
        None
    };

    Some(AiParseDraft::new(
        AiDraftKind::Time,
        payload,
        if warning.is_some() { 0.68 } else { 0.82 },
        "rule",
        warning,
    ))
}

fn resolve_date(line: &str, context_date: &str) -> String {
    let anchor = NaiveDate::parse_from_str(context_date, "%Y-%m-%d")
        .unwrap_or_else(|_| Local::now().date_naive());
    if line.contains("前天") {
        return anchor
            .checked_sub_signed(Duration::days(2))
            .unwrap_or(anchor)
            .to_string();
    }
    if line.contains("昨天") {
        return anchor
            .checked_sub_signed(Duration::days(1))
            .unwrap_or(anchor)
            .to_string();
    }
    if line.contains("明天") {
        return anchor
            .checked_add_signed(Duration::days(1))
            .unwrap_or(anchor)
            .to_string();
    }
    if line.contains("后天") {
        return anchor
            .checked_add_signed(Duration::days(2))
            .unwrap_or(anchor)
            .to_string();
    }
    if line.contains("今天") {
        return anchor.to_string();
    }

    for token in extract_date_tokens(line) {
        if let Ok(parsed) = NaiveDate::parse_from_str(&token, "%Y-%m-%d") {
            return parsed.to_string();
        }
        if let Ok(parsed) = NaiveDate::parse_from_str(&token, "%Y/%m/%d") {
            return parsed.to_string();
        }
        if let Some(parsed) = parse_month_day(&token, anchor.year()) {
            return parsed.to_string();
        }
    }

    anchor.to_string()
}

fn extract_date_tokens(line: &str) -> Vec<String> {
    let mut buffer = String::new();
    for ch in line.chars() {
        if ch.is_ascii_digit() || matches!(ch, '-' | '/' | '月' | '日') {
            buffer.push(ch);
        } else {
            buffer.push(' ');
        }
    }
    buffer.split_whitespace().map(ToString::to_string).collect()
}

fn parse_month_day(token: &str, year: i32) -> Option<NaiveDate> {
    let normalized = token.replace('月', "-").replace('日', "").replace('/', "-");
    let mut parts = normalized.split('-').filter(|segment| !segment.is_empty());
    let month = parts.next()?.parse::<u32>().ok()?;
    let day = parts.next()?.parse::<u32>().ok()?;
    NaiveDate::from_ymd_opt(year, month, day)
}

fn parse_time_range(line: &str) -> Option<TimeRange> {
    let points = extract_time_points(line);
    if points.len() >= 2 {
        for window in points.windows(2) {
            let between = &line[window[0].end..window[1].start];
            if is_range_separator(between) {
                return build_time_range(&window[0], &window[1]);
            }
        }
    }
    parse_simple_hour_range(line)
}

fn extract_time_points(line: &str) -> Vec<TimePoint> {
    let mut points = Vec::new();
    let chars: Vec<(usize, char)> = line.char_indices().collect();
    let mut index = 0;
    while index < chars.len() {
        let byte_index = chars[index].0;
        let period = matched_period(&line[byte_index..]);
        let mut cursor = index;
        if let Some(period) = &period {
            cursor += period.chars().count();
        }
        while cursor < chars.len() && chars[cursor].1.is_whitespace() {
            cursor += 1;
        }
        let Some((hour, next_cursor)) = parse_u32(chars.as_slice(), cursor, 2) else {
            index += 1;
            continue;
        };
        let mut cursor = next_cursor;
        while cursor < chars.len() && chars[cursor].1.is_whitespace() {
            cursor += 1;
        }

        let mut explicit = false;
        let mut minute = 0;
        if cursor < chars.len() && matches!(chars[cursor].1, ':' | '：' | '.') {
            explicit = true;
            cursor += 1;
            let Some((parsed_minute, next)) = parse_u32(chars.as_slice(), cursor, 2) else {
                index += 1;
                continue;
            };
            minute = parsed_minute;
            cursor = next;
        } else if cursor < chars.len() && matches!(chars[cursor].1, '点' | '时') {
            explicit = true;
            cursor += 1;
            while cursor < chars.len() && chars[cursor].1.is_whitespace() {
                cursor += 1;
            }
            if cursor < chars.len() && chars[cursor].1 == '半' {
                minute = 30;
                cursor += 1;
            } else if let Some((parsed_minute, next)) = parse_u32(chars.as_slice(), cursor, 2) {
                minute = parsed_minute;
                cursor = next;
                if cursor < chars.len() && chars[cursor].1 == '分' {
                    cursor += 1;
                }
            }
        }

        if explicit && hour <= 23 && minute <= 59 {
            points.push(TimePoint {
                period: period.clone().map(ToString::to_string),
                hour,
                minute,
                start: byte_index,
                end: if cursor < chars.len() {
                    chars[cursor].0
                } else {
                    line.len()
                },
            });
            index = cursor;
        } else {
            index += 1;
        }
    }
    points
}

fn matched_period(text: &str) -> Option<&'static str> {
    ["上午", "早上", "中午", "下午", "晚上", "凌晨", "傍晚"]
        .into_iter()
        .find(|period| text.starts_with(period))
}

fn parse_u32(chars: &[(usize, char)], start: usize, max_len: usize) -> Option<(u32, usize)> {
    let mut value = String::new();
    let mut cursor = start;
    while cursor < chars.len() && chars[cursor].1.is_ascii_digit() && value.len() < max_len {
        value.push(chars[cursor].1);
        cursor += 1;
    }
    if value.is_empty() {
        return None;
    }
    Some((value.parse().ok()?, cursor))
}

fn is_range_separator(text: &str) -> bool {
    let normalized = text.trim();
    ["到", "至", "-", "~", "～", "—"]
        .iter()
        .any(|token| normalized.contains(token))
}

fn parse_simple_hour_range(line: &str) -> Option<TimeRange> {
    let separators = ["到", "至", "-", "~", "～", "—"];
    let separator = separators
        .iter()
        .find(|separator| line.contains(**separator))?;
    let mut parts = line.splitn(2, separator);
    let left = parts.next()?.trim();
    let right = parts.next()?.trim();
    let left_hour = trailing_hour(left)?;
    let right_hour = leading_hour(right)?;
    let start = TimePoint {
        period: matched_period(left).map(ToString::to_string),
        hour: left_hour,
        minute: 0,
        start: 0,
        end: left.len(),
    };
    let end = TimePoint {
        period: matched_period(right).map(ToString::to_string),
        hour: right_hour,
        minute: 0,
        start: left.len(),
        end: line.len(),
    };
    build_time_range(&start, &end)
}

fn trailing_hour(text: &str) -> Option<u32> {
    let digits: String = text
        .chars()
        .rev()
        .take_while(|ch| ch.is_ascii_digit())
        .collect::<String>()
        .chars()
        .rev()
        .collect();
    digits.parse().ok()
}

fn leading_hour(text: &str) -> Option<u32> {
    let digits: String = text.chars().take_while(|ch| ch.is_ascii_digit()).collect();
    digits.parse().ok()
}

fn build_time_range(start: &TimePoint, end: &TimePoint) -> Option<TimeRange> {
    let start_time = to_24h(start.period.as_deref(), start.hour, start.minute)?;
    let inferred_end_period = end.period.as_deref().or(start.period.as_deref());
    let end_time = to_24h(inferred_end_period, end.hour, end.minute)?;
    let start_time = NaiveTime::parse_from_str(&start_time, "%H:%M").ok()?;
    let end_time = NaiveTime::parse_from_str(&end_time, "%H:%M").ok()?;
    let mut duration_minutes = end_time.signed_duration_since(start_time).num_minutes();
    if duration_minutes <= 0 {
        duration_minutes += 24 * 60;
    }
    Some(TimeRange {
        start_time: start_time.format("%H:%M").to_string(),
        end_time: end_time.format("%H:%M").to_string(),
        duration_minutes,
    })
}

fn to_24h(period: Option<&str>, hour: u32, minute: u32) -> Option<String> {
    if hour > 23 || minute > 59 {
        return None;
    }
    let mut hour = hour;
    match period.unwrap_or_default() {
        "下午" | "晚上" | "傍晚" => {
            if hour < 12 {
                hour += 12;
            }
        }
        "凌晨" | "早上" | "上午" => {
            if hour == 12 {
                hour = 0;
            }
        }
        "中午" => {
            if hour < 11 {
                hour += 12;
            }
        }
        _ => {}
    }
    Some(format!("{hour:02}:{minute:02}"))
}

fn parse_duration_minutes(line: &str) -> Option<i64> {
    if line.contains("半小时") {
        return Some(30);
    }
    let numbers = extract_numeric_tokens(line);
    for (value, suffix) in numbers {
        if suffix.contains("小时") || suffix.starts_with('h') {
            return Some((value * 60.0).round() as i64);
        }
        if suffix.contains("分钟") || suffix.starts_with("min") || suffix == "m" {
            return Some(value.round() as i64);
        }
    }
    None
}

fn extract_numeric_tokens(line: &str) -> Vec<(f64, String)> {
    let chars: Vec<(usize, char)> = line.char_indices().collect();
    let mut tokens = Vec::new();
    let mut index = 0;
    while index < chars.len() {
        if !chars[index].1.is_ascii_digit() {
            index += 1;
            continue;
        }
        let start = index;
        let mut number = String::new();
        while index < chars.len()
            && (chars[index].1.is_ascii_digit() || chars[index].1 == '.')
            && number.len() < 16
        {
            number.push(chars[index].1);
            index += 1;
        }
        let suffix_start = if index < chars.len() {
            chars[index].0
        } else {
            line.len()
        };
        let suffix_end = line[suffix_start..]
            .char_indices()
            .take(8)
            .last()
            .map(|(offset, ch)| suffix_start + offset + ch.len_utf8())
            .unwrap_or(suffix_start);
        if let Ok(value) = number.parse::<f64>() {
            tokens.push((value, line[suffix_start..suffix_end].trim().to_lowercase()));
        }
        if index == start {
            index += 1;
        }
    }
    tokens
}

fn extract_money(line: &str) -> Option<Money> {
    let chars: Vec<(usize, char)> = line.char_indices().collect();
    let mut best: Option<Money> = None;
    let mut index = 0;
    while index < chars.len() {
        if !chars[index].1.is_ascii_digit() {
            index += 1;
            continue;
        }
        let start = chars[index].0;
        let mut number = String::new();
        while index < chars.len()
            && (chars[index].1.is_ascii_digit() || chars[index].1 == '.')
            && number.len() < 16
        {
            number.push(chars[index].1);
            index += 1;
        }
        let end = if index < chars.len() {
            chars[index].0
        } else {
            line.len()
        };
        let prefix_start = line[..start]
            .char_indices()
            .rev()
            .take(4)
            .last()
            .map(|(offset, _)| offset)
            .unwrap_or(0);
        let prefix = line[prefix_start..start].to_lowercase();
        let suffix_end = line[end..]
            .char_indices()
            .take(4)
            .last()
            .map(|(offset, ch)| end + offset + ch.len_utf8())
            .unwrap_or(end);
        let suffix = line[end..suffix_end].to_lowercase();
        if suffix.trim_start().starts_with('%') {
            continue;
        }
        if looks_like_time_number(&prefix, &suffix) {
            continue;
        }

        let value = number.parse::<f64>().ok()?;
        let explicit_unit = prefix.contains('¥')
            || prefix.contains('￥')
            || prefix.contains("rmb")
            || prefix.contains("人民币")
            || suffix.contains("万")
            || suffix.contains('w')
            || suffix.contains("千")
            || suffix.contains('k')
            || suffix.contains("元")
            || suffix.contains("块")
            || suffix.contains("分");

        let mut amount = value;
        if suffix.contains("万") || suffix.split_whitespace().any(|value| value == "w") {
            amount *= 10_000.0;
        } else if suffix.contains("千") || suffix.split_whitespace().any(|value| value == "k") {
            amount *= 1_000.0;
        } else if suffix.contains("分") && !suffix.contains("元") && !suffix.contains("块") {
            amount /= 100.0;
        }

        let candidate = Money {
            amount: strip_trailing_zeros(amount),
            explicit_unit,
            start,
            end,
        };
        match &best {
            None => best = Some(candidate),
            Some(current) if candidate.explicit_unit && !current.explicit_unit => {
                best = Some(candidate);
            }
            Some(current) if candidate.end >= current.end => best = Some(candidate),
            _ => {}
        }
    }
    best
}

fn looks_like_time_number(prefix: &str, suffix: &str) -> bool {
    let prefix = prefix.trim_end();
    let suffix = suffix.trim_start();
    suffix.starts_with(':')
        || suffix.starts_with('：')
        || suffix.starts_with('点')
        || suffix.starts_with('时')
        || prefix.ends_with(':')
        || prefix.ends_with('：')
        || prefix.ends_with('点')
        || prefix.ends_with('时')
}

fn strip_trailing_zeros(value: f64) -> String {
    let mut text = format!("{value:.4}");
    while text.contains('.') && text.ends_with('0') {
        text.pop();
    }
    if text.ends_with('.') {
        text.pop();
    }
    text
}

fn strip_money_phrase(line: &str, money: &Money) -> String {
    let mut text = String::new();
    text.push_str(&line[..money.start]);
    text.push_str(&line[money.end..]);
    collapse_spaces(text.trim())
}

fn extract_income_source(line: &str, money: &Money) -> Option<String> {
    let stripped = strip_money_phrase(line, money);
    let cleaned = collapse_spaces(
        stripped
            .replace("收入", "")
            .replace("到账", "")
            .replace("进账", "")
            .replace("回款", "")
            .replace("工资", "")
            .replace("奖金", "")
            .replace("报销", "")
            .replace("今天", "")
            .replace("昨天", "")
            .replace("前天", "")
            .trim(),
    );
    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned)
    }
}

fn extract_time_description(line: &str) -> Option<String> {
    let mut description = line.to_string();
    if let Some(range) = parse_time_range(line) {
        description = description
            .replace(&range.start_time, "")
            .replace(&range.end_time, "");
    }
    for token in ["小时", "分钟", "点", "时", "半小时"] {
        description = description.replace(token, " ");
    }
    let cleaned = collapse_spaces(description.trim());
    if cleaned.is_empty() {
        None
    } else {
        Some(cleaned)
    }
}

fn extract_learning_content(line: &str) -> String {
    let base = extract_time_description(line).unwrap_or_else(|| line.trim().to_string());
    let cleaned = collapse_spaces(
        base.replace("学习", "")
            .replace("复习", "")
            .replace("阅读", "")
            .replace("课程", "")
            .replace("刷题", "")
            .replace("听课", "")
            .replace("看书", "")
            .trim(),
    );
    if cleaned.is_empty() {
        line.trim().to_string()
    } else {
        cleaned
    }
}

fn infer_time_category(line: &str) -> &'static str {
    let lower = line.to_lowercase();
    if contains_any(&lower, &["学习", "阅读", "课程", "learn"]) {
        return "learning";
    }
    if contains_any(&lower, &["通勤", "做饭", "家务", "生活", "life"]) {
        return "life";
    }
    if contains_any(&lower, &["娱乐", "电影", "游戏", "entertain"]) {
        return "entertainment";
    }
    if contains_any(&lower, &["休息", "睡", "rest"]) {
        return "rest";
    }
    if contains_any(&lower, &["社交", "朋友", "聚会", "social"]) {
        return "social";
    }
    "work"
}

fn infer_income_type(line: &str) -> &'static str {
    let lower = line.to_lowercase();
    if contains_any(&lower, &["工资", "薪", "salary"]) {
        return "salary";
    }
    if contains_any(&lower, &["项目", "回款", "外包", "project"]) {
        return "project";
    }
    if contains_any(&lower, &["投资", "分红", "invest"]) {
        return "investment";
    }
    if contains_any(&lower, &["系统", "补贴", "system"]) {
        return "system";
    }
    "other"
}

fn infer_expense_category(line: &str) -> &'static str {
    let lower = line.to_lowercase();
    if contains_any(&lower, &["订阅", "会员", "subscription"]) {
        return "subscription";
    }
    if contains_any(&lower, &["投资", "理财", "invest"]) {
        return "investment";
    }
    if contains_any(
        &lower,
        &["咖啡", "吃", "玩", "旅行", "电影", "聚餐", "experience"],
    ) {
        return "experience";
    }
    "necessary"
}

fn infer_learning_level(line: &str) -> &'static str {
    let lower = line.to_lowercase();
    if contains_any(&lower, &["成果", "产出", "result"]) {
        return "result";
    }
    if contains_any(&lower, &["实践", "应用", "落地", "apply", "applied"]) {
        return "applied";
    }
    "input"
}

fn attach_scores_and_ai_ratio(payload: &mut BTreeMap<String, String>, line: &str) {
    if let Some(value) = extract_named_number(line, &["效率", "效能"], 1.0, 10.0) {
        payload.insert("efficiency_score".to_string(), value.round().to_string());
    }
    if let Some(value) = extract_named_number(line, &["价值", "产出"], 1.0, 10.0) {
        payload.insert("value_score".to_string(), value.round().to_string());
    }
    if let Some(value) = extract_named_number(line, &["状态", "专注", "精力"], 1.0, 10.0) {
        payload.insert("state_score".to_string(), value.round().to_string());
    }
    attach_ai_ratio(payload, line);
}

fn attach_ai_ratio(payload: &mut BTreeMap<String, String>, line: &str) {
    if let Some(value) = extract_named_number(line, &["AI", "人工智能"], 0.0, 100.0) {
        payload.insert("ai_ratio".to_string(), value.round().to_string());
    }
}

fn extract_named_number(line: &str, keywords: &[&str], min: f64, max: f64) -> Option<f64> {
    for keyword in keywords {
        if let Some(index) = line.find(keyword) {
            let tail = &line[index + keyword.len()..];
            let number = first_number(tail)?;
            if number >= min && number <= max {
                return Some(number);
            }
        }
    }
    None
}

fn first_number(text: &str) -> Option<f64> {
    let mut number = String::new();
    let mut found = false;
    for ch in text.chars() {
        if ch.is_ascii_digit() || ch == '.' {
            found = true;
            number.push(ch);
        } else if found {
            break;
        }
    }
    number.parse().ok()
}

fn attach_context_mentions(
    payload: &mut BTreeMap<String, String>,
    line: &str,
    context: &ParseContext,
) {
    let lower = line.to_lowercase();

    let mut project_names = BTreeSet::new();
    let mut sorted_projects = context.project_names.clone();
    sorted_projects.sort_by_key(|value| usize::MAX - value.chars().count());
    for project_name in sorted_projects {
        if !project_name.trim().is_empty() && lower.contains(&project_name.to_lowercase()) {
            project_names.insert(project_name);
        }
    }
    if !project_names.is_empty() {
        payload.insert(
            "project_names".to_string(),
            project_names.into_iter().collect::<Vec<_>>().join(","),
        );
    }

    let mut tag_names = BTreeSet::new();
    let mut sorted_tags = context.tag_names.clone();
    sorted_tags.sort_by_key(|value| usize::MAX - value.chars().count());
    for tag_name in sorted_tags {
        if !tag_name.trim().is_empty() && lower.contains(&tag_name.to_lowercase()) {
            tag_names.insert(tag_name);
        }
    }
    if !tag_names.is_empty() {
        payload.insert(
            "tag_names".to_string(),
            tag_names.into_iter().collect::<Vec<_>>().join(","),
        );
    }
}

fn contains_any(text: &str, keywords: &[&str]) -> bool {
    keywords.iter().any(|keyword| text.contains(keyword))
}

fn collapse_spaces(text: impl AsRef<str>) -> String {
    text.as_ref()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}
