use crate::ai::{ParserEngine, RuleParserEngine};
use crate::error::Result;
use crate::models::{
    AiParseInput, DraftStatus, IgnoredContext, ParseContext, ParsePipelineResult, ReviewNoteDraft,
    TypedDraftKind,
};

use super::{preprocess_input, reviewable_from_legacy_result};

pub fn run_rule_pipeline(
    input: &AiParseInput,
    context: &ParseContext,
) -> Result<ParsePipelineResult> {
    let preprocessed = preprocess_input(input);
    let mut normalized_input = input.clone();
    normalized_input.raw_text = preprocessed
        .segments
        .iter()
        .map(|segment| segment.raw_text.replace('\n', " "))
        .collect::<Vec<_>>()
        .join("\n");
    normalized_input.context_date = Some(preprocessed.context_date);
    let legacy = RuleParserEngine.parse(&normalized_input, context, None)?;
    let mut result = reviewable_from_legacy_result(legacy, context);
    let mut items = Vec::new();
    for item in result.items {
        if item.kind == TypedDraftKind::ReferenceNote {
            result.review_notes.push(ReviewNoteDraft::new(
                item.raw_text.clone(),
                note_title(&item.raw_text),
                infer_note_type(&item.raw_text),
                item.raw_text.clone(),
                "ai_capture",
                Some(item.confidence),
            ));
        } else if item.kind == TypedDraftKind::TimeMarker
            || item.validation.status == DraftStatus::ReferenceOnly
        {
            result.ignored_context.push(IgnoredContext {
                raw_text: item.raw_text.clone(),
                reason: "reference_or_time_anchor".to_string(),
            });
        } else {
            items.push(item);
        }
    }
    result.items = items;
    Ok(result)
}

fn note_title(raw: &str) -> String {
    let trimmed = raw.trim();
    let title = trimmed.chars().take(18).collect::<String>();
    if title.is_empty() {
        "复盘素材".to_string()
    } else {
        title
    }
}

fn infer_note_type(raw: &str) -> &'static str {
    let lower = raw.to_lowercase();
    if lower.contains("gpt") || lower.contains("ai") || raw.contains("辅助") {
        "ai_usage"
    } else if raw.contains("计划") || raw.contains("明天") || lower.contains("plan") {
        "plan"
    } else if raw.contains("风险") || raw.contains("问题") || raw.contains("隐患") {
        "risk"
    } else if raw.contains("感觉") || raw.contains("状态") || raw.contains("情绪") {
        "feeling"
    } else if raw.contains("总结") || raw.contains("复盘") {
        "summary"
    } else {
        "reflection"
    }
}
