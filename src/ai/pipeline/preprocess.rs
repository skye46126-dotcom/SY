use crate::models::AiParseInput;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreprocessedSegment {
    pub index: usize,
    pub raw_text: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PreprocessedInput {
    pub user_id: String,
    pub raw_text: String,
    pub context_date: String,
    pub segments: Vec<PreprocessedSegment>,
}

pub fn preprocess_input(input: &AiParseInput) -> PreprocessedInput {
    let mut normalized = input.raw_text.replace('\r', "\n");
    for token in ["；", ";", "。", "！", "？"] {
        normalized = normalized.replace(token, "\n");
    }
    for token in ["然后", "接着", "另外", "还有", "并且"] {
        normalized = normalized.replace(token, "\n");
    }

    let raw_segments = normalized
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
        .collect::<Vec<_>>();
    let segments = merge_related_segments(raw_segments)
        .into_iter()
        .enumerate()
        .map(|(index, raw_text)| PreprocessedSegment { index, raw_text })
        .collect();

    PreprocessedInput {
        user_id: input.user_id.clone(),
        raw_text: input.raw_text.trim().to_string(),
        context_date: input.resolved_context_date(),
        segments,
    }
}

fn merge_related_segments(segments: Vec<String>) -> Vec<String> {
    let mut merged: Vec<String> = Vec::new();
    for segment in segments {
        if let Some(last) = merged.last_mut()
            && should_merge_segments(last, &segment)
        {
            last.push('\n');
            last.push_str(&segment);
            continue;
        }
        merged.push(segment);
    }
    merged
}

fn should_merge_segments(previous: &str, current: &str) -> bool {
    let previous_tail = previous
        .lines()
        .rev()
        .find(|line| !line.trim().is_empty())
        .unwrap_or(previous)
        .trim();
    if is_section_heading(current) {
        return false;
    }
    if is_date_heading(previous_tail) || is_period_heading(previous_tail) {
        return true;
    }
    if is_standalone_time_expression(previous_tail) && !is_section_heading(current) {
        return true;
    }
    false
}

fn is_section_heading(text: &str) -> bool {
    let trimmed = text.trim();
    trimmed.starts_with('#')
        || trimmed.ends_with('：')
        || matches!(
            trimmed,
            "反思" | "复盘" | "社交" | "学习" | "工作" | "支出" | "收入"
        )
}

fn is_period_heading(text: &str) -> bool {
    matches!(
        text.trim(),
        "早上" | "上午" | "中午" | "下午" | "晚上" | "凌晨" | "傍晚" | "回寝室"
    )
}

fn is_date_heading(text: &str) -> bool {
    let trimmed = text.trim();
    if trimmed.is_empty() || trimmed.chars().count() > 10 {
        return false;
    }
    let normalized = trimmed.replace('月', ".").replace('日', "");
    let mut parts = normalized
        .split(['.', '/', '-'])
        .filter(|part| !part.is_empty());
    let Some(left) = parts.next() else {
        return false;
    };
    let Some(right) = parts.next() else {
        return false;
    };
    parts.next().is_none()
        && left.chars().all(|ch| ch.is_ascii_digit())
        && right.chars().all(|ch| ch.is_ascii_digit())
}

fn is_standalone_time_expression(text: &str) -> bool {
    let trimmed = text.trim();
    if trimmed.is_empty() || trimmed.chars().count() > 24 {
        return false;
    }
    let has_digit = trimmed.chars().any(|ch| ch.is_ascii_digit());
    let has_time_marker = [':', '.', '-', '~', '～', '到', '至', '点', '时']
        .iter()
        .any(|marker| trimmed.contains(*marker));
    let has_action = [
        "工作", "开发", "优化", "写", "做", "学习", "看", "答疑", "洗澡", "课程", "作业", "玩",
        "睡", "吃", "买", "出", "下课", "上课", "冥想", "锻炼",
    ]
    .iter()
    .any(|keyword| trimmed.contains(keyword));
    has_digit && has_time_marker && !has_action
}

#[cfg(test)]
mod tests {
    use crate::models::AiParseInput;

    use super::preprocess_input;

    #[test]
    fn splits_common_capture_connectors() {
        let input = AiParseInput {
            user_id: "u1".to_string(),
            raw_text: "上午工作2小时；然后学习 Rust 1小时\n- 花了 20元".to_string(),
            context_date: Some("2026-04-25".to_string()),
            parser_mode_override: None,
        };
        let result = preprocess_input(&input);
        assert_eq!(result.context_date, "2026-04-25");
        assert_eq!(result.segments.len(), 3);
        assert_eq!(result.segments[0].raw_text, "上午工作2小时");
        assert_eq!(result.segments[1].raw_text, "学习 Rust 1小时");
        assert_eq!(result.segments[2].raw_text, "花了 20元");
    }

    #[test]
    fn merges_time_anchors_with_following_action_lines() {
        let input = AiParseInput {
            user_id: "u1".to_string(),
            raw_text: "中午\n12-1点\n修skyos\n\n下午\n5-9点\n做UI优化".to_string(),
            context_date: Some("2026-04-25".to_string()),
            parser_mode_override: None,
        };
        let result = preprocess_input(&input);
        assert_eq!(result.segments.len(), 2);
        assert!(result.segments[0].raw_text.contains("12-1点"));
        assert!(result.segments[0].raw_text.contains("修skyos"));
        assert!(result.segments[1].raw_text.contains("5-9点"));
        assert!(result.segments[1].raw_text.contains("做UI优化"));
    }
}
