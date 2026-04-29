use std::collections::BTreeMap;

use serde_json::Value;

use crate::models::{DraftField, DraftLinks, DraftStatus, DraftValidation, TypedDraftKind};

pub fn validate_reviewable_draft(
    kind: &TypedDraftKind,
    fields: &BTreeMap<String, DraftField>,
    links: &DraftLinks,
    mut warnings: Vec<String>,
) -> DraftValidation {
    if kind.reference_only() {
        warnings.extend(link_warnings(links));
        return DraftValidation {
            status: DraftStatus::ReferenceOnly,
            missing_required: Vec::new(),
            blocking_errors: Vec::new(),
            warnings,
        };
    }

    if *kind == TypedDraftKind::Unknown {
        return DraftValidation::from_issues(
            Vec::new(),
            vec!["unknown draft cannot be committed".to_string()],
            warnings,
        );
    }

    let mut missing = fields
        .iter()
        .filter_map(|(key, field)| field.is_missing_required().then(|| key.clone()))
        .collect::<Vec<_>>();
    let mut blocking_errors = Vec::new();

    if *kind == TypedDraftKind::TimeRecord {
        if field_string(fields, "time_status").as_deref() == Some("anchor_event") {
            warnings.push(
                "single time anchor is kept as reference-only and cannot be committed as a time record"
                    .to_string(),
            );
            warnings.extend(link_warnings(links));
            return DraftValidation {
                status: DraftStatus::ReferenceOnly,
                missing_required: Vec::new(),
                blocking_errors: Vec::new(),
                warnings,
            };
        }
        let has_duration = has_value(fields, "duration_minutes");
        let has_time_window = has_value(fields, "start_time") && has_value(fields, "end_time");
        if !has_duration && !has_time_window {
            missing.push("duration_minutes_or_time_window".to_string());
        } else if has_duration && !has_time_window {
            warnings.push("time draft has duration but no explicit time window".to_string());
        }
    }

    for key in ["efficiency_score", "value_score", "state_score"] {
        if let Some(value) = field_i64(fields, key)
            && !(0..=10).contains(&value)
        {
            blocking_errors.push(format!("{key} must be between 0 and 10"));
        }
    }
    if let Some(value) = field_i64(fields, "ai_assist_ratio")
        && !(0..=100).contains(&value)
    {
        blocking_errors.push("ai_assist_ratio must be between 0 and 100".to_string());
    }
    if let Some(value) = field_i64(fields, "duration_minutes")
        && value <= 0
    {
        blocking_errors.push("duration_minutes must be positive".to_string());
    }

    warnings.extend(link_warnings(links));
    DraftValidation::from_issues(missing, blocking_errors, warnings)
}

fn has_value(fields: &BTreeMap<String, DraftField>, key: &str) -> bool {
    fields.get(key).is_some_and(|field| match &field.value {
        Some(Value::String(value)) => !value.trim().is_empty(),
        Some(Value::Null) | None => false,
        Some(_) => true,
    })
}

fn field_string(fields: &BTreeMap<String, DraftField>, key: &str) -> Option<String> {
    fields.get(key).and_then(|field| match &field.value {
        Some(Value::String(value)) => Some(value.trim().to_string()),
        _ => None,
    })
}

fn field_i64(fields: &BTreeMap<String, DraftField>, key: &str) -> Option<i64> {
    fields.get(key).and_then(|field| match &field.value {
        Some(Value::Number(value)) => value.as_i64(),
        Some(Value::String(value)) => value.trim().parse::<i64>().ok(),
        _ => None,
    })
}

fn link_warnings(links: &DraftLinks) -> Vec<String> {
    links
        .projects
        .iter()
        .flat_map(|link| link.warnings.clone())
        .chain(links.tags.iter().flat_map(|link| link.warnings.clone()))
        .collect()
}
