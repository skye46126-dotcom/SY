use std::collections::BTreeMap;

use crate::models::{
    AiDraftKind, AiParseDraft, AiParseResult, DraftField, DraftFieldSource, ParseContext,
    ParsePipelineResult, ReviewableDraft, TypedDraftKind,
};

use super::{links_from_legacy, validate_reviewable_draft};

pub fn reviewable_from_legacy_result(
    legacy: AiParseResult,
    context: &ParseContext,
) -> ParsePipelineResult {
    let request_id = legacy.request_id;
    let parser_used = legacy.parser_used;
    let mut warnings = legacy.warnings;
    let items = legacy
        .items
        .into_iter()
        .map(|draft| reviewable_from_legacy_draft(draft, context))
        .collect();
    if parser_used == "orchestrator" {
        warnings.push("parser orchestration returned an empty or fallback result".to_string());
    }
    ParsePipelineResult {
        request_id,
        parser_used,
        items,
        review_notes: Vec::new(),
        ignored_context: Vec::new(),
        warnings,
    }
}

pub fn reviewable_from_legacy_draft(
    legacy: AiParseDraft,
    context: &ParseContext,
) -> ReviewableDraft {
    let kind = typed_kind_from_legacy(&legacy);
    let mut draft = ReviewableDraft::new(kind.clone(), legacy.source.clone());
    draft.draft_id = legacy.draft_id.clone();
    draft.confidence = legacy.confidence;
    draft.raw_text = first_payload_value(&legacy, &["raw", "description", "note", "content"])
        .unwrap_or_default();
    draft.title = build_title(&kind, &legacy);
    draft.note = build_note(&kind, &legacy);
    draft.unmapped_text =
        first_payload_value(&legacy, &["raw"]).filter(|value| match &draft.note {
            Some(note) => !note.contains(value.trim()),
            None => true,
        });
    draft.fields = fields_from_legacy(&legacy);
    enrich_v3_fields(&kind, &mut draft.fields, &legacy);
    draft.links = links_from_legacy(&legacy, context);

    let mut warnings = Vec::new();
    if let Some(warning) = legacy.warning.clone() {
        warnings.push(warning);
    }
    draft.validation = validate_reviewable_draft(&kind, &draft.fields, &draft.links, warnings);
    draft
}

fn typed_kind_from_legacy(legacy: &AiParseDraft) -> TypedDraftKind {
    if legacy.kind != AiDraftKind::Unknown {
        return TypedDraftKind::from_legacy(&legacy.kind);
    }
    if first_payload_value(legacy, &["raw"]).is_some_and(|raw| is_time_marker_text(&raw)) {
        return TypedDraftKind::TimeMarker;
    }
    TypedDraftKind::ReferenceNote
}

fn enrich_v3_fields(
    kind: &TypedDraftKind,
    fields: &mut BTreeMap<String, DraftField>,
    legacy: &AiParseDraft,
) {
    if *kind == TypedDraftKind::TimeRecord {
        let status =
            if has_payload_value(legacy, "start_time") && has_payload_value(legacy, "end_time") {
                "complete_time_window"
            } else if has_payload_value(legacy, "duration_minutes") {
                "duration_only"
            } else if has_payload_value(legacy, "start_time") {
                "partial_start"
            } else if has_payload_value(legacy, "end_time") {
                "partial_end"
            } else {
                "unknown_time"
            };
        fields.insert(
            "time_status".to_string(),
            DraftField::from_string(status, DraftFieldSource::Rule),
        );
    }

    if kind.reference_only() {
        fields.insert(
            "reference_kind".to_string(),
            DraftField::from_string(kind.as_str(), DraftFieldSource::Rule),
        );
        if *kind == TypedDraftKind::TimeMarker {
            if let Some(raw) = first_payload_value(legacy, &["raw", "note", "description"]) {
                if let Some(time_text) = extract_time_marker_text(&raw) {
                    fields.insert(
                        "time_text".to_string(),
                        DraftField::from_string(time_text, DraftFieldSource::Rule),
                    );
                    fields.insert(
                        "time_status".to_string(),
                        DraftField::from_string("anchor_event", DraftFieldSource::Rule),
                    );
                }
            }
        }
        if let Some(raw) = first_payload_value(legacy, &["raw", "note", "description"]) {
            fields.insert(
                "reference_text".to_string(),
                DraftField::from_string(raw, DraftFieldSource::Legacy),
            );
        }
    }
}

fn fields_from_legacy(legacy: &AiParseDraft) -> BTreeMap<String, DraftField> {
    let mut fields = BTreeMap::new();
    for (key, value) in &legacy.payload {
        if matches!(
            key.as_str(),
            "project"
                | "projects"
                | "project_names"
                | "project_allocations"
                | "tag"
                | "tags"
                | "tag_names"
                | "tag_ids"
                | "raw"
        ) {
            continue;
        }
        fields.insert(
            key.clone(),
            DraftField::from_string(value.clone(), DraftFieldSource::Legacy)
                .with_confidence(legacy.confidence),
        );
    }
    mark_required_fields(&legacy.kind, &mut fields);
    fields
}

fn mark_required_fields(kind: &AiDraftKind, fields: &mut BTreeMap<String, DraftField>) {
    let required = match kind {
        AiDraftKind::Time => vec!["date"],
        AiDraftKind::Income => vec!["date", "amount", "source", "type"],
        AiDraftKind::Expense => vec!["date", "amount", "category"],
        AiDraftKind::Unknown => Vec::new(),
    };
    for key in required {
        fields
            .entry(key.to_string())
            .or_insert_with(|| DraftField::new(None, DraftFieldSource::Default))
            .required = true;
    }
}

fn build_title(kind: &TypedDraftKind, legacy: &AiParseDraft) -> String {
    match kind {
        TypedDraftKind::TimeRecord => {
            let description = first_payload_value(legacy, &["description", "note"])
                .unwrap_or_else(|| "时间记录".to_string());
            let duration = first_payload_value(legacy, &["duration_minutes"])
                .map(|value| format!(" · {value}分钟"))
                .unwrap_or_default();
            format!("{description}{duration}")
        }
        TypedDraftKind::IncomeRecord => {
            let source = first_payload_value(legacy, &["source", "source_name"])
                .unwrap_or_else(|| "收入".to_string());
            let amount = first_payload_value(legacy, &["amount", "amount_yuan", "amount_cents"])
                .map(|value| format!(" · {value}"))
                .unwrap_or_default();
            format!("{source}{amount}")
        }
        TypedDraftKind::ExpenseRecord => {
            let note = first_payload_value(legacy, &["note", "category"])
                .unwrap_or_else(|| "支出".to_string());
            let amount = first_payload_value(legacy, &["amount", "amount_yuan", "amount_cents"])
                .map(|value| format!(" · {value}"))
                .unwrap_or_default();
            format!("{note}{amount}")
        }
        TypedDraftKind::TimeMarker => {
            let time = first_payload_value(legacy, &["raw"])
                .and_then(|raw| extract_time_marker_text(&raw))
                .unwrap_or_else(|| "时间锚点".to_string());
            let raw =
                first_payload_value(legacy, &["raw"]).unwrap_or_else(|| "时间锚点".to_string());
            format!("{time} · {raw}")
        }
        _ => first_payload_value(legacy, &["raw"]).unwrap_or_else(|| "未识别草稿".to_string()),
    }
}

fn build_note(kind: &TypedDraftKind, legacy: &AiParseDraft) -> Option<String> {
    let explicit_note = first_payload_value(legacy, &["note"]);
    let fallback = match kind {
        TypedDraftKind::TimeRecord => first_payload_value(legacy, &["content", "description"]),
        TypedDraftKind::IncomeRecord => first_payload_value(legacy, &["source"]),
        TypedDraftKind::ExpenseRecord => explicit_note.clone(),
        _ => first_payload_value(legacy, &["raw"]),
    };
    explicit_note
        .or(fallback)
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn first_payload_value(legacy: &AiParseDraft, keys: &[&str]) -> Option<String> {
    keys.iter()
        .find_map(|key| legacy.payload.get(*key))
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
}

fn has_payload_value(legacy: &AiParseDraft, key: &str) -> bool {
    legacy
        .payload
        .get(key)
        .is_some_and(|value| !value.trim().is_empty())
}

fn is_time_marker_text(raw: &str) -> bool {
    if raw.trim().is_empty() || raw.chars().count() > 80 {
        return false;
    }
    if contains_any_ci(raw, &["分钟", "小时", "min", "hour", "元", "块", "¥", "$"]) {
        return false;
    }
    if raw.contains('-') || raw.contains('~') || raw.contains('到') || raw.contains('至') {
        return false;
    }
    extract_time_marker_text(raw).is_some()
}

fn extract_time_marker_text(raw: &str) -> Option<String> {
    extract_colon_time(raw)
        .or_else(|| extract_dot_time(raw))
        .or_else(|| extract_chinese_time(raw))
}

fn extract_colon_time(raw: &str) -> Option<String> {
    let bytes = raw.as_bytes();
    let mut index = 0;
    while index < bytes.len() {
        if !bytes[index].is_ascii_digit() {
            index += 1;
            continue;
        }
        let start = index;
        let hour = read_digits(bytes, &mut index, 2)?;
        if index >= bytes.len() || bytes[index] != b':' {
            index = start + 1;
            continue;
        }
        index += 1;
        let minute = read_digits(bytes, &mut index, 2)?;
        if hour <= 23 && minute <= 59 {
            return Some(format!("{hour:02}:{minute:02}"));
        }
        index = start + 1;
    }
    None
}

fn extract_dot_time(raw: &str) -> Option<String> {
    let bytes = raw.as_bytes();
    let mut index = 0;
    while index < bytes.len() {
        if !bytes[index].is_ascii_digit() {
            index += 1;
            continue;
        }
        let start = index;
        let hour = read_digits(bytes, &mut index, 2)?;
        if index >= bytes.len() || bytes[index] != b'.' {
            index = start + 1;
            continue;
        }
        index += 1;
        let minute_start = index;
        let minute = read_digits(bytes, &mut index, 2)?;
        if index - minute_start == 2 && hour <= 23 && minute <= 59 {
            return Some(format!("{hour:02}:{minute:02}"));
        }
        index = start + 1;
    }
    None
}

fn extract_chinese_time(raw: &str) -> Option<String> {
    let chars: Vec<char> = raw.chars().collect();
    let mut index = 0;
    while index < chars.len() {
        if !chars[index].is_ascii_digit() {
            index += 1;
            continue;
        }
        let start = index;
        let Some(hour) = read_char_digits(&chars, &mut index, 2) else {
            index += 1;
            continue;
        };
        if index >= chars.len() || !matches!(chars[index], '点' | '时') {
            index = start + 1;
            continue;
        }
        index += 1;
        let minute = if index < chars.len() && chars[index] == '半' {
            30
        } else {
            read_char_digits(&chars, &mut index, 2).unwrap_or(0)
        };
        if hour <= 23 && minute <= 59 {
            return Some(format!("{hour:02}:{minute:02}"));
        }
        index = start + 1;
    }
    None
}

fn read_digits(bytes: &[u8], index: &mut usize, max_len: usize) -> Option<u32> {
    let start = *index;
    let mut value = 0_u32;
    let mut count = 0;
    while *index < bytes.len() && bytes[*index].is_ascii_digit() && count < max_len {
        value = value * 10 + u32::from(bytes[*index] - b'0');
        *index += 1;
        count += 1;
    }
    (*index > start).then_some(value)
}

fn read_char_digits(chars: &[char], index: &mut usize, max_len: usize) -> Option<u32> {
    let start = *index;
    let mut value = 0_u32;
    let mut count = 0;
    while *index < chars.len() && chars[*index].is_ascii_digit() && count < max_len {
        value = value * 10 + chars[*index].to_digit(10)?;
        *index += 1;
        count += 1;
    }
    (*index > start).then_some(value)
}

fn contains_any_ci(text: &str, needles: &[&str]) -> bool {
    let lower = text.to_lowercase();
    needles.iter().any(|needle| lower.contains(needle))
}
