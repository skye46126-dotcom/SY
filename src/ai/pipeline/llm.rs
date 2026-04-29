use std::collections::BTreeMap;
use std::time::Duration;

use serde::{Deserialize, Serialize};
use serde_json::{Value, json};

use crate::ai::{ParserEngine, RuleParserEngine};
use crate::error::{LifeOsError, Result};
use crate::models::{
    AiDraftKind, AiParseInput, AiServiceConfig, DraftField, DraftFieldSource, DraftLinks,
    DraftProjectLink, DraftTagLink, IgnoredContext, ParseContext, ParsePipelineResult,
    ReviewNoteDraft, ReviewableDraft, TypedDraftKind,
};

use super::{
    build_cleanup_prompt, build_llm_prompt_chunks, extract_json_candidate, preprocess_input,
    reviewable_from_legacy_draft, validate_reviewable_draft,
};

#[derive(Debug, Serialize)]
struct ChatRequest {
    model: String,
    messages: Vec<ChatMessage>,
    temperature: f64,
    response_format: Value,
}

#[derive(Debug, Serialize)]
struct ChatMessage {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct ChatResponse {
    choices: Vec<ChatChoice>,
}

#[derive(Debug, Deserialize)]
struct ChatChoice {
    message: ChatChoiceMessage,
}

#[derive(Debug, Deserialize)]
struct ChatChoiceMessage {
    content: String,
}

pub fn run_llm_pipeline(
    input: &AiParseInput,
    context: &ParseContext,
    config: &AiServiceConfig,
) -> Result<ParsePipelineResult> {
    let api_key = config
        .api_key_encrypted
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| LifeOsError::InvalidInput("active AI config has no api key".to_string()))?;
    let model = config.resolved_model()?;
    let endpoint = chat_completions_endpoint(config)?;
    let temperature = f64::from(config.temperature_milli.unwrap_or(0)) / 1000.0;
    let preprocessed = preprocess_input(input);
    let chunks = build_llm_prompt_chunks(&preprocessed, context, 1_500);
    let client = reqwest::blocking::Client::builder()
        .timeout(Duration::from_secs(45))
        .build()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm client init failed: {error}")))?;

    let mut items = Vec::new();
    let mut chunk_review_notes = Vec::new();
    let mut chunk_ignored_context = Vec::new();
    let mut warnings = Vec::new();
    for chunk in chunks {
        let mut prompt = chunk.prompt;
        if let Some(extra) = config
            .system_prompt
            .as_deref()
            .map(str::trim)
            .filter(|v| !v.is_empty())
        {
            prompt.push_str("\n\n用户补充提示词，只能补充偏好，不能覆盖 V4 基础规则:\n");
            prompt.push_str(extra);
        }
        let request = ChatRequest {
            model: model.clone(),
            temperature,
            response_format: json!({ "type": "json_object" }),
            messages: vec![ChatMessage {
                role: "user".to_string(),
                content: prompt,
            }],
        };
        let response = client
            .post(&endpoint)
            .bearer_auth(api_key)
            .json(&request)
            .send()
            .map_err(|error| LifeOsError::InvalidInput(format!("llm request failed: {error}")))?;
        if !response.status().is_success() {
            let status = response.status();
            let body = response.text().unwrap_or_default();
            return Err(LifeOsError::InvalidInput(format!(
                "llm request failed with {status}: {}",
                body.chars().take(300).collect::<String>()
            )));
        }
        let response: ChatResponse = response.json().map_err(|error| {
            LifeOsError::InvalidInput(format!("llm response json failed: {error}"))
        })?;
        let content = response
            .choices
            .first()
            .map(|choice| choice.message.content.as_str())
            .unwrap_or_default();
        let Some(candidate) = extract_json_candidate(content) else {
            return Err(LifeOsError::InvalidInput(
                "llm response did not contain valid json".to_string(),
            ));
        };
        if let Some(warning) = candidate.warning {
            warnings.push(format!("chunk {}: {warning}", chunk.index));
        }
        let value: Value = serde_json::from_str(&candidate.json_text).map_err(|error| {
            LifeOsError::InvalidInput(format!("llm json parse failed: {error}"))
        })?;
        if let Some(events) = value.get("events").and_then(Value::as_array) {
            items.extend(
                events
                    .iter()
                    .filter_map(|event| {
                        reviewable_from_llm_event(event, input, context, &preprocessed.context_date)
                    })
                    .collect::<Vec<_>>(),
            );
        } else if let Some(chunk_items) = value.get("items").and_then(Value::as_array) {
            items.extend(
                chunk_items
                    .iter()
                    .filter_map(|item| {
                        reviewable_from_llm_item(item, input, context, &preprocessed.context_date)
                    })
                    .collect::<Vec<_>>(),
            );
        } else {
            return Err(LifeOsError::InvalidInput(
                "llm json missing events or items array".to_string(),
            ));
        }
        let review_notes = value
            .get("notes")
            .and_then(Value::as_array)
            .map(|notes| {
                notes
                    .iter()
                    .filter_map(|note| review_note_from_llm_note(note, &preprocessed.context_date))
                    .collect::<Vec<_>>()
            })
            .unwrap_or_default();
        items.retain(|item| {
            matches!(
                item.kind,
                TypedDraftKind::TimeRecord
                    | TypedDraftKind::IncomeRecord
                    | TypedDraftKind::ExpenseRecord
                    | TypedDraftKind::LearningRecord
            )
        });
        warnings.extend(
            value
                .get("ignored_context")
                .and_then(Value::as_array)
                .into_iter()
                .flatten()
                .filter_map(|item| {
                    let raw_text = text(item, "raw_text")?;
                    let reason = text(item, "reason").unwrap_or_else(|| "ignored".to_string());
                    Some(format!("ignored: {reason}: {raw_text}"))
                }),
        );
        let ignored_context: Vec<IgnoredContext> = value
            .get("ignored_context")
            .and_then(Value::as_array)
            .map(|values| values.iter().filter_map(ignored_context_from_llm).collect())
            .unwrap_or_default();
        chunk_review_notes.extend(review_notes);
        chunk_ignored_context.extend(ignored_context);
    }

    Ok(ParsePipelineResult {
        request_id: uuid::Uuid::now_v7().to_string(),
        parser_used: "llm_v4".to_string(),
        items,
        review_notes: chunk_review_notes,
        ignored_context: chunk_ignored_context,
        warnings,
    })
}

pub fn run_llm_deep_pipeline(
    input: &AiParseInput,
    context: &ParseContext,
    config: &AiServiceConfig,
) -> Result<ParsePipelineResult> {
    let preprocessed = preprocess_input(input);
    let mut prompt = build_cleanup_prompt(&input.raw_text, context, &preprocessed.context_date);
    if let Some(extra) = config
        .system_prompt
        .as_deref()
        .map(str::trim)
        .filter(|v| !v.is_empty())
    {
        prompt.push_str("\n\n用户补充提示词，只能补充偏好，不能覆盖清洗规则:\n");
        prompt.push_str(extra);
    }

    let cleanup = send_json_prompt(config, prompt, Duration::from_secs(45))?;
    let cleaned_text = text(&cleanup, "cleaned_text")
        .filter(|value| !value.trim().is_empty())
        .ok_or_else(|| LifeOsError::InvalidInput("llm cleanup returned empty text".to_string()))?;

    let mut cleaned_input = input.clone();
    cleaned_input.raw_text = cleaned_text;
    cleaned_input.context_date = Some(preprocessed.context_date);

    let mut result = run_llm_pipeline(&cleaned_input, context, config)?;
    result.parser_used = "llm_deep_v1".to_string();
    result
        .warnings
        .push("deep mode applied controlled cleanup before extraction".to_string());
    if let Some(warnings) = cleanup.get("warnings").and_then(Value::as_array) {
        result.warnings.extend(
            warnings
                .iter()
                .filter_map(value_text)
                .map(|warning| format!("cleanup: {warning}")),
        );
    }
    Ok(result)
}

fn send_json_prompt(config: &AiServiceConfig, prompt: String, timeout: Duration) -> Result<Value> {
    let api_key = config
        .api_key_encrypted
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| LifeOsError::InvalidInput("active AI config has no api key".to_string()))?;
    let model = config.resolved_model()?;
    let endpoint = chat_completions_endpoint(config)?;
    let temperature = f64::from(config.temperature_milli.unwrap_or(0)) / 1000.0;
    let client = reqwest::blocking::Client::builder()
        .timeout(timeout)
        .build()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm client init failed: {error}")))?;
    let request = ChatRequest {
        model,
        temperature,
        response_format: json!({ "type": "json_object" }),
        messages: vec![ChatMessage {
            role: "user".to_string(),
            content: prompt,
        }],
    };
    let response = client
        .post(&endpoint)
        .bearer_auth(api_key)
        .json(&request)
        .send()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm request failed: {error}")))?;
    if !response.status().is_success() {
        let status = response.status();
        let body = response.text().unwrap_or_default();
        return Err(LifeOsError::InvalidInput(format!(
            "llm request failed with {status}: {}",
            body.chars().take(300).collect::<String>()
        )));
    }
    let response: ChatResponse = response
        .json()
        .map_err(|error| LifeOsError::InvalidInput(format!("llm response json failed: {error}")))?;
    let content = response
        .choices
        .first()
        .map(|choice| choice.message.content.as_str())
        .unwrap_or_default();
    let Some(candidate) = extract_json_candidate(content) else {
        return Err(LifeOsError::InvalidInput(
            "llm response did not contain valid json".to_string(),
        ));
    };
    serde_json::from_str(&candidate.json_text)
        .map_err(|error| LifeOsError::InvalidInput(format!("llm json parse failed: {error}")))
}

fn chat_completions_endpoint(config: &AiServiceConfig) -> Result<String> {
    let base = config
        .resolved_base_url()?
        .ok_or_else(|| LifeOsError::InvalidInput("AI base_url is required".to_string()))?;
    let trimmed = base.trim().trim_end_matches('/');
    if trimmed.ends_with("/chat/completions") {
        Ok(trimmed.to_string())
    } else {
        Ok(format!("{trimmed}/chat/completions"))
    }
}

fn reviewable_from_llm_event(
    event: &Value,
    _input: &AiParseInput,
    context: &ParseContext,
    context_date: &str,
) -> Option<ReviewableDraft> {
    let record_type = text(event, "record_type")
        .or_else(|| text(event, "kind"))
        .unwrap_or_default();
    let kind = match record_type.as_str() {
        "time" | "time_record" => TypedDraftKind::TimeRecord,
        "learning" | "learning_record" => TypedDraftKind::LearningRecord,
        "income" | "income_record" => TypedDraftKind::IncomeRecord,
        "expense" | "expense_record" => TypedDraftKind::ExpenseRecord,
        _ => return None,
    };
    let normalized = normalized_event_item(event, &kind, context_date);
    reviewable_from_llm_item_core(&Value::Object(normalized), context, context_date, false)
}

fn event_raw_text(event: &Value) -> Option<String> {
    text(event, "raw_text").or_else(|| {
        let mut parts = Vec::new();
        if let Some(time_text) = text(event, "time_text") {
            parts.push(time_text);
        }
        if let Some(activity) = text(event, "activity_text") {
            parts.push(activity);
        }
        if let Some(money) = text(event, "money_text") {
            parts.push(money);
        }
        let raw = parts.join(" ");
        (!raw.trim().is_empty()).then_some(raw)
    })
}

fn review_note_from_llm_note(note: &Value, context_date: &str) -> Option<ReviewNoteDraft> {
    let content = text(note, "content").or_else(|| text(note, "raw_text"))?;
    let raw_text = text(note, "raw_text").unwrap_or_else(|| content.clone());
    let title = text(note, "title").unwrap_or_else(|| note_title(&content));
    let note_type = text(note, "note_type").unwrap_or_else(|| infer_note_type(&content));
    let mut draft = ReviewNoteDraft::new(
        raw_text,
        title,
        normalize_note_type_text(&note_type),
        content,
        "ai_capture",
        note.get("confidence").and_then(Value::as_f64),
    );
    draft.occurred_on = Some(text(note, "occurred_on").unwrap_or_else(|| context_date.to_string()));
    draft.visibility = text(note, "visibility").unwrap_or_else(|| "compact".to_string());
    Some(draft)
}

fn ignored_context_from_llm(item: &Value) -> Option<IgnoredContext> {
    Some(IgnoredContext {
        raw_text: text(item, "raw_text")?,
        reason: text(item, "reason").unwrap_or_else(|| "ignored".to_string()),
    })
}

fn reviewable_from_llm_item(
    item: &Value,
    input: &AiParseInput,
    context: &ParseContext,
    context_date: &str,
) -> Option<ReviewableDraft> {
    let _ = input;
    reviewable_from_llm_item_core(item, context, context_date, true)
}

fn reviewable_from_llm_item_core(
    item: &Value,
    context: &ParseContext,
    context_date: &str,
    allow_rule_fallback: bool,
) -> Option<ReviewableDraft> {
    let kind = typed_kind_from_str(text(item, "kind").as_deref());
    if !matches!(
        kind,
        TypedDraftKind::TimeRecord
            | TypedDraftKind::IncomeRecord
            | TypedDraftKind::ExpenseRecord
            | TypedDraftKind::LearningRecord
    ) {
        return None;
    }
    if allow_rule_fallback
        && let Some(draft) = reviewable_from_existing_rules(item, context, context_date, &kind)
    {
        return Some(merge_llm_fields_into_rule_draft(draft, item, context_date));
    }

    let mut draft = ReviewableDraft::new(kind.clone(), "llm");
    draft.raw_text = text(item, "raw_text").unwrap_or_default();
    draft.title = text(item, "title")
        .or_else(|| text(item, "description"))
        .or_else(|| text(item, "content"))
        .or_else(|| text(item, "raw_text"))
        .unwrap_or_else(|| kind.as_str().to_string());
    draft.note = text(item, "note");
    draft.unmapped_text = text(item, "unmapped_text");
    draft.confidence = item
        .get("confidence")
        .and_then(Value::as_f64)
        .unwrap_or(0.75)
        .clamp(0.0, 1.0);
    draft.fields = fields_from_llm_item(item, &kind, context_date);
    draft.links = links_from_llm_item(item, &kind, context);
    let mut warnings: Vec<String> = item
        .get("warnings")
        .and_then(Value::as_array)
        .map(|values| values.iter().filter_map(value_text).collect())
        .unwrap_or_default();
    warnings.extend(field_level_warnings(&draft.fields, &kind));
    draft.validation = validate_reviewable_draft(&kind, &draft.fields, &draft.links, warnings);
    Some(draft)
}

fn reviewable_from_existing_rules(
    item: &Value,
    context: &ParseContext,
    context_date: &str,
    expected_kind: &TypedDraftKind,
) -> Option<ReviewableDraft> {
    let raw_text = text(item, "raw_text")
        .or_else(|| text(item, "title"))
        .filter(|value| !value.trim().is_empty())?;
    let parse_input = AiParseInput {
        user_id: String::new(),
        raw_text,
        context_date: Some(context_date.to_string()),
        parser_mode_override: None,
    };
    let legacy = RuleParserEngine.parse(&parse_input, context, None).ok()?;
    let expected_legacy = expected_kind.legacy_kind();
    let mut selected = legacy
        .items
        .iter()
        .find(|draft| draft.kind == expected_legacy)
        .cloned()
        .or_else(|| {
            legacy
                .items
                .iter()
                .find(|draft| draft.kind != AiDraftKind::Unknown)
                .cloned()
        })?;
    if selected.kind == AiDraftKind::Unknown {
        return None;
    }
    selected.source = "llm_rule".to_string();
    if let Some(confidence) = item.get("confidence").and_then(Value::as_f64) {
        selected.confidence = selected.confidence.max(confidence.clamp(0.0, 1.0));
    }
    Some(reviewable_from_legacy_draft(selected, context))
}

fn normalized_event_item(
    event: &Value,
    kind: &TypedDraftKind,
    context_date: &str,
) -> serde_json::Map<String, Value> {
    let mut normalized = serde_json::Map::new();
    normalized.insert("kind".to_string(), Value::String(kind.as_str().to_string()));
    normalized.insert(
        "raw_text".to_string(),
        Value::String(event_raw_text(event).unwrap_or_default()),
    );
    normalized.insert(
        "title".to_string(),
        Value::String(
            text(event, "title")
                .or_else(|| text(event, "activity_text"))
                .unwrap_or_else(|| kind.as_str().to_string()),
        ),
    );
    normalized.insert(
        "date".to_string(),
        Value::String(text(event, "date").unwrap_or_else(|| context_date.to_string())),
    );
    if let Some(activity) = text(event, "activity_text") {
        let key = if *kind == TypedDraftKind::LearningRecord {
            "content"
        } else if *kind == TypedDraftKind::IncomeRecord {
            "source"
        } else {
            "description"
        };
        normalized.insert(key.to_string(), Value::String(activity));
    }
    if let Some(domain) = text(event, "domain") {
        normalized.insert("category".to_string(), Value::String(domain));
    }
    if let Some(money) = text(event, "money_text").or_else(|| text(event, "money")) {
        normalized.insert("amount".to_string(), Value::String(money));
    }
    for key in ["time_text", "start_time", "end_time", "duration_minutes"] {
        if let Some(value) = event.get(key) {
            normalized.insert(key.to_string(), value.clone());
        }
    }
    if let Some(note) = text(event, "note_text").or_else(|| text(event, "note")) {
        normalized.insert("note".to_string(), Value::String(note));
    }
    for key in [
        "efficiency_score",
        "value_score",
        "state_score",
        "ai_assist_ratio",
        "application_level",
        "is_passive",
        "confidence",
        "warnings",
        "project_texts",
        "tag_texts",
    ] {
        if let Some(value) = event.get(key) {
            normalized.insert(key.to_string(), value.clone());
        }
    }
    normalized
}

fn merge_llm_fields_into_rule_draft(
    mut draft: ReviewableDraft,
    item: &Value,
    context_date: &str,
) -> ReviewableDraft {
    overlay_text_field(
        &mut draft,
        "date",
        normalized_date_text(text(item, "date"), context_date),
    );
    overlay_text_field(
        &mut draft,
        "start_time",
        normalized_clock_text(text(item, "start_time")),
    );
    overlay_text_field(
        &mut draft,
        "end_time",
        normalized_clock_text(text(item, "end_time")),
    );
    overlay_value_field(
        &mut draft,
        "duration_minutes",
        item.get("duration_minutes").cloned(),
    );
    overlay_text_field(&mut draft, "note", text(item, "note"));
    if draft.kind == TypedDraftKind::TimeRecord {
        overlay_text_field(&mut draft, "description", text(item, "description"));
    }
    if draft.kind == TypedDraftKind::LearningRecord {
        overlay_text_field(&mut draft, "content", text(item, "content"));
    }
    if draft.kind == TypedDraftKind::IncomeRecord {
        overlay_text_field(&mut draft, "source", text(item, "source"));
    }
    let warnings = item
        .get("warnings")
        .and_then(Value::as_array)
        .map(|values| values.iter().filter_map(value_text).collect())
        .unwrap_or_default();
    draft.validation =
        validate_reviewable_draft(&draft.kind, &draft.fields, &draft.links, warnings);
    draft
}

fn overlay_text_field(draft: &mut ReviewableDraft, key: &str, value: Option<String>) {
    let Some(value) = value.filter(|value| !value.trim().is_empty()) else {
        return;
    };
    draft.fields.insert(
        key.to_string(),
        DraftField::from_string(value, DraftFieldSource::Ai).with_confidence(draft.confidence),
    );
}

fn overlay_value_field(draft: &mut ReviewableDraft, key: &str, value: Option<Value>) {
    let Some(value) = value.filter(|value| !value.is_null()) else {
        return;
    };
    draft.fields.insert(
        key.to_string(),
        DraftField::new(Some(value), DraftFieldSource::Ai).with_confidence(draft.confidence),
    );
}

fn fields_from_llm_item(
    item: &Value,
    kind: &TypedDraftKind,
    context_date: &str,
) -> BTreeMap<String, DraftField> {
    let mut fields = BTreeMap::new();
    insert_text_field(
        &mut fields,
        "date",
        normalized_date_text(text(item, "date"), context_date),
    );
    insert_text_field(&mut fields, "amount", text(item, "amount"));
    insert_text_field(&mut fields, "category", text(item, "category"));
    insert_text_field(&mut fields, "source", text(item, "source"));
    insert_text_field(&mut fields, "type", text(item, "type"));
    insert_text_field(
        &mut fields,
        "application_level",
        text(item, "application_level"),
    );
    insert_text_field(&mut fields, "description", text(item, "description"));
    insert_text_field(&mut fields, "content", text(item, "content"));
    insert_text_field(&mut fields, "note", text(item, "note"));
    insert_text_field(&mut fields, "raw", text(item, "raw_text"));
    insert_text_field(&mut fields, "time_text", text(item, "time_text"));
    insert_text_field(&mut fields, "start_time", text(item, "start_time"));
    insert_text_field(&mut fields, "end_time", text(item, "end_time"));
    if let Some(value) = item
        .get("duration_minutes")
        .filter(|value| !value.is_null())
    {
        fields.insert(
            "duration_minutes".to_string(),
            DraftField::new(Some(value.clone()), DraftFieldSource::Ai),
        );
    }
    for key in [
        "efficiency_score",
        "value_score",
        "state_score",
        "ai_assist_ratio",
        "is_passive",
    ] {
        if let Some(value) = item.get(key).filter(|value| !value.is_null()) {
            fields.insert(
                key.to_string(),
                DraftField::new(Some(value.clone()), DraftFieldSource::Ai),
            );
        }
    }
    if let Some(facets) = item.get("facets").and_then(Value::as_array) {
        let text = facets
            .iter()
            .filter_map(value_text)
            .collect::<Vec<_>>()
            .join(", ");
        insert_text_field(&mut fields, "facets", Some(text));
    }
    mark_required_fields(kind, &mut fields);
    fields
}

fn field_level_warnings(
    fields: &BTreeMap<String, DraftField>,
    kind: &TypedDraftKind,
) -> Vec<String> {
    let mut warnings = Vec::new();
    if *kind == TypedDraftKind::TimeRecord || *kind == TypedDraftKind::LearningRecord {
        let start = field_string(fields, "start_time").and_then(|value| parse_clock_value(&value));
        let end = field_string(fields, "end_time").and_then(|value| parse_clock_value(&value));
        let duration = field_i64(fields, "duration_minutes");
        if let (Some(start), Some(end), Some(duration)) = (start, end, duration) {
            let mut minutes = end.signed_duration_since(start).num_minutes();
            if minutes <= 0 {
                minutes += 24 * 60;
            }
            if (minutes - duration).abs() > 5 {
                warnings.push(format!(
                    "llm duration mismatch: start/end implies {minutes} minutes but duration_minutes is {duration}"
                ));
            }
        }
        if start.is_none() ^ end.is_none() {
            warnings.push("llm provided only one side of time window".to_string());
        }
    }
    warnings
}

fn links_from_llm_item(item: &Value, kind: &TypedDraftKind, context: &ParseContext) -> DraftLinks {
    let projects = string_array(item, "project_texts")
        .into_iter()
        .map(|name| {
            let name_exists = context
                .project_names
                .iter()
                .any(|candidate| candidate.eq_ignore_ascii_case(&name));
            DraftProjectLink {
                project_id: None,
                name,
                weight_ratio: 1.0,
                source: DraftFieldSource::Ai,
                resolution_status: if name_exists {
                    "name_matched"
                } else {
                    "unresolved"
                }
                .to_string(),
                warnings: if name_exists {
                    Vec::new()
                } else {
                    vec!["project reference is not resolved to an id".to_string()]
                },
            }
        })
        .collect();
    let tags = string_array(item, "tag_texts")
        .into_iter()
        .map(|name| {
            let name_exists = context
                .tag_names
                .iter()
                .any(|candidate| candidate.eq_ignore_ascii_case(&name));
            DraftTagLink {
                tag_id: None,
                name,
                scope: Some(kind.as_str().to_string()),
                source: DraftFieldSource::Ai,
                resolution_status: if name_exists {
                    "name_matched"
                } else {
                    "unresolved"
                }
                .to_string(),
                warnings: if name_exists {
                    Vec::new()
                } else {
                    vec!["tag reference is not resolved to an id".to_string()]
                },
            }
        })
        .collect();
    DraftLinks {
        projects,
        tags,
        dimensions: Vec::new(),
    }
}

fn typed_kind_from_str(value: Option<&str>) -> TypedDraftKind {
    match value.unwrap_or_default() {
        "time_record" => TypedDraftKind::TimeRecord,
        "income_record" => TypedDraftKind::IncomeRecord,
        "expense_record" => TypedDraftKind::ExpenseRecord,
        "learning_record" => TypedDraftKind::LearningRecord,
        "monthly_cost_baseline" => TypedDraftKind::MonthlyCostBaseline,
        "recurring_expense_rule" => TypedDraftKind::RecurringExpenseRule,
        "capex_cost" => TypedDraftKind::CapexCost,
        "operating_settings" => TypedDraftKind::OperatingSettings,
        "project" => TypedDraftKind::Project,
        "tag" => TypedDraftKind::Tag,
        "dimension_option" => TypedDraftKind::DimensionOption,
        "time_marker" => TypedDraftKind::TimeMarker,
        "reference_note" => TypedDraftKind::ReferenceNote,
        _ => TypedDraftKind::Unknown,
    }
}

fn mark_required_fields(kind: &TypedDraftKind, fields: &mut BTreeMap<String, DraftField>) {
    let required = match kind {
        TypedDraftKind::TimeRecord => ["date", "category"].as_slice(),
        TypedDraftKind::IncomeRecord => ["date", "amount", "source"].as_slice(),
        TypedDraftKind::ExpenseRecord => ["date", "amount", "category"].as_slice(),
        TypedDraftKind::LearningRecord => {
            ["date", "content", "duration_minutes", "application_level"].as_slice()
        }
        _ => [].as_slice(),
    };
    for key in required {
        fields
            .entry((*key).to_string())
            .or_insert_with(|| DraftField::new(None, DraftFieldSource::Default))
            .required = true;
    }
}

fn insert_text_field(fields: &mut BTreeMap<String, DraftField>, key: &str, value: Option<String>) {
    if let Some(value) = value
        .map(|value| value.trim().to_string())
        .filter(|v| !v.is_empty())
    {
        fields.insert(
            key.to_string(),
            DraftField::from_string(value, DraftFieldSource::Ai),
        );
    }
}

fn normalized_date_text(value: Option<String>, context_date: &str) -> Option<String> {
    let value = value
        .map(|value| value.trim().to_string())
        .filter(|value| !value.is_empty())
        .unwrap_or_else(|| context_date.to_string());
    if is_iso_date(&value) {
        Some(value)
    } else {
        Some(context_date.to_string())
    }
}

fn normalized_clock_text(value: Option<String>) -> Option<String> {
    let value = value?.trim().replace('：', ":").replace('.', ":");
    let parts = value.split(':').collect::<Vec<_>>();
    if parts.len() != 2 {
        return None;
    }
    let hour = parts[0].trim().parse::<u32>().ok()?;
    let minute = parts[1].trim().parse::<u32>().ok()?;
    if hour > 23 || minute > 59 {
        return None;
    }
    Some(format!("{hour:02}:{minute:02}"))
}

fn parse_clock_value(value: &str) -> Option<chrono::NaiveTime> {
    chrono::NaiveTime::parse_from_str(value.trim(), "%H:%M").ok()
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

fn is_iso_date(value: &str) -> bool {
    let bytes = value.as_bytes();
    bytes.len() == 10
        && bytes[0..4].iter().all(u8::is_ascii_digit)
        && bytes[4] == b'-'
        && bytes[5..7].iter().all(u8::is_ascii_digit)
        && bytes[7] == b'-'
        && bytes[8..10].iter().all(u8::is_ascii_digit)
}

fn string_array(item: &Value, key: &str) -> Vec<String> {
    item.get(key)
        .and_then(Value::as_array)
        .map(|values| values.iter().filter_map(value_text).collect())
        .unwrap_or_default()
}

fn text(item: &Value, key: &str) -> Option<String> {
    item.get(key).and_then(value_text)
}

fn value_text(value: &Value) -> Option<String> {
    match value {
        Value::String(value) => Some(value.trim().to_string()).filter(|value| !value.is_empty()),
        Value::Number(value) => Some(value.to_string()),
        Value::Bool(value) => Some(value.to_string()),
        _ => None,
    }
}

fn note_title(content: &str) -> String {
    let title = content.trim().chars().take(18).collect::<String>();
    if title.is_empty() {
        "复盘素材".to_string()
    } else {
        title
    }
}

fn infer_note_type(content: &str) -> String {
    let lower = content.to_lowercase();
    if lower.contains("gpt") || lower.contains("ai") || content.contains("辅助") {
        "ai_usage".to_string()
    } else if content.contains("计划") || content.contains("明天") || lower.contains("plan") {
        "plan".to_string()
    } else if content.contains("风险") || content.contains("问题") || content.contains("隐患")
    {
        "risk".to_string()
    } else if content.contains("感觉") || content.contains("状态") || content.contains("情绪")
    {
        "feeling".to_string()
    } else if content.contains("总结") || content.contains("复盘") {
        "summary".to_string()
    } else {
        "reflection".to_string()
    }
}

fn normalize_note_type_text(value: &str) -> String {
    match value.trim().to_lowercase().as_str() {
        "reflection" | "feeling" | "plan" | "idea" | "context" | "ai_usage" | "risk"
        | "summary" => value.trim().to_lowercase(),
        _ => "reflection".to_string(),
    }
}
