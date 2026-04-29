use std::path::Path;

use serde_json::Value;

use crate::db::Database;
use crate::error::{LifeOsError, Result};
use crate::models::{
    AiCaptureCommitInput, AiCaptureCommitResult, AiDraftKind, AiParseDraft, AiParseInput,
    CaptureInboxAutoCommitResult, CaptureInboxEntry, CaptureInboxProcessResult, CaptureInboxStatus,
    CaptureSessionProfile, CommitCaptureDraftEnvelopeInput, CommitReviewableDraftInput,
    CreateCaptureInboxEntryInput, DraftStatus, ParserMode, PrepareCaptureSessionInput,
    ProcessCaptureInboxAndCommitInput, ProcessCaptureInboxInput, ReviewNoteDraft, TypedDraftKind,
};
use crate::repositories::capture_inbox_repository::CaptureInboxRepository;
use crate::services::ai_service::AiService;

#[derive(Debug, Clone)]
pub struct CaptureService {
    database: Database,
}

impl CaptureService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn enqueue_capture_inbox(
        &self,
        input: &CreateCaptureInboxEntryInput,
    ) -> Result<CaptureInboxEntry> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        CaptureInboxRepository::enqueue(&mut connection, input)
    }

    pub fn list_capture_inbox(
        &self,
        user_id: &str,
        status_filter: Option<CaptureInboxStatus>,
        limit: usize,
    ) -> Result<Vec<CaptureInboxEntry>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CaptureInboxRepository::list(&connection, user_id, status_filter, limit)
    }

    pub fn get_capture_inbox(
        &self,
        user_id: &str,
        inbox_id: &str,
    ) -> Result<Option<CaptureInboxEntry>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        CaptureInboxRepository::get(&connection, user_id, inbox_id)
    }

    pub fn process_capture_inbox(
        &self,
        input: &ProcessCaptureInboxInput,
    ) -> Result<CaptureInboxProcessResult> {
        self.database.initialize()?;
        input.validate()?;

        let mut connection = self.database.connect()?;
        let entry = CaptureInboxRepository::get(&connection, &input.user_id, &input.inbox_id)?
            .ok_or_else(|| {
                LifeOsError::InvalidInput(format!(
                    "capture inbox entry not found: {}",
                    input.inbox_id
                ))
            })?;
        CaptureInboxRepository::mark_parsing(&mut connection, &input.user_id, &input.inbox_id)?;
        drop(connection);

        let parse_result = AiService::new(self.database.path()).parse_input_v2(&AiParseInput {
            user_id: input.user_id.clone(),
            raw_text: entry.raw_text.clone(),
            context_date: entry.context_date.clone(),
            parser_mode_override: input
                .parser_mode_override
                .clone()
                .or(entry.parser_mode_hint.clone()),
        });

        match parse_result {
            Ok(draft_envelope) => {
                let mut connection = self.database.connect()?;
                let updated_entry = CaptureInboxRepository::save_process_success(
                    &mut connection,
                    &input.user_id,
                    &input.inbox_id,
                    &draft_envelope,
                )?;
                Ok(CaptureInboxProcessResult {
                    entry: updated_entry,
                    draft_envelope,
                })
            }
            Err(error) => {
                let mut connection = self.database.connect()?;
                let _ = CaptureInboxRepository::save_process_failure(
                    &mut connection,
                    &input.user_id,
                    &input.inbox_id,
                    &error.to_string(),
                );
                Err(error)
            }
        }
    }

    pub fn commit_capture_draft_envelope(
        &self,
        input: &CommitCaptureDraftEnvelopeInput,
    ) -> Result<AiCaptureCommitResult> {
        self.database.initialize()?;
        input.validate()?;

        let drafts = input
            .items
            .iter()
            .filter(|item| is_submittable_reviewable(item))
            .map(reviewable_to_legacy_draft)
            .collect::<Result<Vec<_>>>()?;
        let review_notes = input
            .review_notes
            .iter()
            .filter(|note| is_savable_review_note(note))
            .cloned()
            .collect::<Vec<_>>();
        if drafts.is_empty() && review_notes.is_empty() {
            return Err(LifeOsError::InvalidInput(
                "没有可提交的记录或可保存的复盘素材".to_string(),
            ));
        }

        let skipped = input
            .items
            .iter()
            .filter(|item| is_needs_review_record(item) && !item.user_confirmed)
            .count();
        let commit_input = AiCaptureCommitInput {
            user_id: input.user_id.clone(),
            request_id: Some(input.resolved_request_id()),
            context_date: Some(input.resolved_context_date()),
            drafts,
            review_notes,
            options: input.options.clone(),
        };
        let mut result = AiService::new(self.database.path()).commit_capture(&commit_input)?;
        result.skipped = skipped;

        if let Some(inbox_id) = input.inbox_id.as_deref() {
            let mut connection = self.database.connect()?;
            if result.failures.is_empty() && result.note_failures.is_empty() {
                CaptureInboxRepository::mark_committed(
                    &mut connection,
                    &input.user_id,
                    inbox_id,
                    Some(&result.request_id),
                    &result.warnings,
                )?;
            } else {
                let summary = format!(
                    "commit failures={}, note_failures={}",
                    result.failures.len(),
                    result.note_failures.len()
                );
                CaptureInboxRepository::save_process_failure(
                    &mut connection,
                    &input.user_id,
                    inbox_id,
                    &summary,
                )?;
            }
        }

        Ok(result)
    }

    pub fn process_capture_inbox_and_commit(
        &self,
        input: &ProcessCaptureInboxAndCommitInput,
    ) -> Result<CaptureInboxAutoCommitResult> {
        input.validate()?;
        let process_result = self.process_capture_inbox(&ProcessCaptureInboxInput {
            user_id: input.user_id.clone(),
            inbox_id: input.inbox_id.clone(),
            parser_mode_override: input.parser_mode_override.clone(),
        })?;
        let has_auto_committable_items = process_result
            .draft_envelope
            .items
            .iter()
            .any(|item| item.validation.status == DraftStatus::CommitReady)
            || process_result
                .draft_envelope
                .review_notes
                .iter()
                .any(|note| is_savable_review_note(note));

        let commit_result = if has_auto_committable_items {
            Some(
                self.commit_capture_draft_envelope(&CommitCaptureDraftEnvelopeInput {
                    user_id: input.user_id.clone(),
                    inbox_id: Some(input.inbox_id.clone()),
                    request_id: Some(process_result.draft_envelope.request_id.clone()),
                    context_date: process_result.entry.context_date.clone(),
                    items: process_result
                        .draft_envelope
                        .items
                        .iter()
                        .cloned()
                        .map(|draft| CommitReviewableDraftInput {
                            draft,
                            user_confirmed: false,
                        })
                        .collect(),
                    review_notes: process_result.draft_envelope.review_notes.clone(),
                    options: crate::models::AiCommitOptions::default(),
                })?,
            )
        } else {
            None
        };

        Ok(CaptureInboxAutoCommitResult {
            process_result,
            commit_result,
        })
    }

    pub fn prepare_capture_session(
        &self,
        input: &PrepareCaptureSessionInput,
    ) -> Result<CaptureSessionProfile> {
        self.database.initialize()?;
        input.validate()?;

        let inbox_entry = match input.inbox_id.as_deref() {
            Some(inbox_id) => self.get_capture_inbox(&input.user_id, inbox_id)?,
            None => None,
        };
        let route_hint = input.route_hint.clone().or_else(|| {
            inbox_entry
                .as_ref()
                .and_then(|entry| entry.route_hint.clone())
        });
        let record_type = input
            .record_type_hint
            .clone()
            .or_else(|| {
                inbox_entry
                    .as_ref()
                    .and_then(|entry| entry.record_type_hint.clone())
            })
            .or_else(|| route_query_value(route_hint.as_deref(), "type"));
        let mode = input
            .mode_hint
            .clone()
            .or_else(|| {
                inbox_entry
                    .as_ref()
                    .and_then(|entry| entry.mode_hint.clone())
            })
            .or_else(|| route_query_value(route_hint.as_deref(), "mode"))
            .unwrap_or_else(|| infer_mode(inbox_entry.as_ref()));
        let active_parser_mode = AiService::new(self.database.path())
            .get_active_service_config(&input.user_id)?
            .map(|config| config.parser_mode);
        let parser_mode = input
            .parser_mode_override
            .clone()
            .or_else(|| {
                inbox_entry
                    .as_ref()
                    .and_then(|entry| entry.parser_mode_hint.clone())
            })
            .or(active_parser_mode)
            .unwrap_or_else(|| infer_parser_mode(&mode, inbox_entry.as_ref()));
        let prefill_text = input
            .prefill_text
            .clone()
            .or_else(|| inbox_entry.as_ref().map(|entry| entry.raw_text.clone()));
        let context_date = inbox_entry
            .as_ref()
            .and_then(|entry| entry.context_date.clone());
        let route = build_capture_route(route_hint.as_deref(), &mode, record_type.as_deref());
        let auto_commit_capable = matches!(mode.as_str(), "ai" | "voice")
            && inbox_entry.as_ref().is_some_and(|entry| {
                matches!(
                    entry.status,
                    CaptureInboxStatus::Queued | CaptureInboxStatus::DraftReady
                )
            });
        let mut defaults_applied = Vec::new();
        if input.mode_hint.is_none()
            && inbox_entry
                .as_ref()
                .and_then(|entry| entry.mode_hint.clone())
                .is_none()
        {
            defaults_applied.push("mode".to_string());
        }
        if input.parser_mode_override.is_none()
            && inbox_entry
                .as_ref()
                .and_then(|entry| entry.parser_mode_hint.clone())
                .is_none()
        {
            defaults_applied.push("parser_mode".to_string());
        }
        if input.record_type_hint.is_none()
            && inbox_entry
                .as_ref()
                .and_then(|entry| entry.record_type_hint.clone())
                .is_none()
        {
            defaults_applied.push("record_type".to_string());
        }

        Ok(CaptureSessionProfile {
            user_id: input.user_id.clone(),
            inbox_id: input.inbox_id.clone(),
            source: inbox_entry.as_ref().map(|entry| entry.source.clone()),
            entry_point: inbox_entry.as_ref().map(|entry| entry.entry_point.clone()),
            route,
            mode: mode.clone(),
            record_type,
            parser_mode,
            context_date,
            prefill_text,
            focus_input: mode != "manual",
            auto_commit_capable,
            defaults_applied,
        })
    }
}

fn is_submittable_reviewable(item: &CommitReviewableDraftInput) -> bool {
    if is_commit_ready_reviewable(item) {
        return true;
    }
    item.draft.validation.status == DraftStatus::NeedsReview && item.user_confirmed
}

fn is_commit_ready_reviewable(item: &CommitReviewableDraftInput) -> bool {
    is_committable_reviewable(item) && item.draft.validation.status == DraftStatus::CommitReady
}

fn is_committable_reviewable(item: &CommitReviewableDraftInput) -> bool {
    matches!(
        item.draft.kind,
        TypedDraftKind::TimeRecord
            | TypedDraftKind::IncomeRecord
            | TypedDraftKind::ExpenseRecord
            | TypedDraftKind::LearningRecord
    ) && matches!(
        item.draft.validation.status,
        DraftStatus::CommitReady | DraftStatus::NeedsReview
    )
}

fn is_needs_review_record(item: &CommitReviewableDraftInput) -> bool {
    is_committable_reviewable(item) && item.draft.validation.status == DraftStatus::NeedsReview
}

fn is_savable_review_note(note: &ReviewNoteDraft) -> bool {
    !note.content.trim().is_empty() && note.visibility != "hidden"
}

fn reviewable_to_legacy_draft(item: &CommitReviewableDraftInput) -> Result<AiParseDraft> {
    let kind = match item.draft.kind {
        TypedDraftKind::TimeRecord => AiDraftKind::Time,
        TypedDraftKind::IncomeRecord => AiDraftKind::Income,
        TypedDraftKind::ExpenseRecord => AiDraftKind::Expense,
        TypedDraftKind::LearningRecord => AiDraftKind::Learning,
        _ => AiDraftKind::Unknown,
    };
    if kind == AiDraftKind::Unknown {
        return Err(LifeOsError::InvalidInput(format!(
            "unsupported reviewable draft kind: {}",
            item.draft.kind.as_str()
        )));
    }

    let mut payload = std::collections::BTreeMap::new();
    for (key, field) in &item.draft.fields {
        if let Some(value) = field_value_to_string(field.value.as_ref()) {
            if !value.trim().is_empty() {
                payload.insert(key.clone(), value);
            }
        }
    }
    let projects = item
        .draft
        .links
        .projects
        .iter()
        .map(|link| link.name.trim())
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>()
        .join(",");
    let tags = item
        .draft
        .links
        .tags
        .iter()
        .map(|link| link.name.trim())
        .filter(|value| !value.is_empty())
        .collect::<Vec<_>>()
        .join(",");
    if !projects.is_empty() {
        payload.insert("project_names".to_string(), projects);
    }
    if !tags.is_empty() {
        payload.insert("tag_names".to_string(), tags);
    }
    if !item.draft.raw_text.trim().is_empty() {
        payload.insert("raw".to_string(), item.draft.raw_text.clone());
    }
    if let Some(note) = item
        .draft
        .note
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
    {
        payload.insert("note".to_string(), note.to_string());
    }

    Ok(AiParseDraft {
        draft_id: item.draft.draft_id.clone(),
        kind,
        payload,
        confidence: item.draft.confidence.clamp(0.0, 1.0),
        source: item.draft.source.clone(),
        warning: join_warnings(&item.draft.validation.warnings),
    })
}

fn field_value_to_string(value: Option<&Value>) -> Option<String> {
    match value {
        Some(Value::Null) | None => None,
        Some(Value::String(value)) => Some(value.clone()),
        Some(Value::Bool(value)) => Some(value.to_string()),
        Some(Value::Number(value)) => Some(value.to_string()),
        Some(other) => Some(other.to_string()),
    }
}

fn join_warnings(warnings: &[String]) -> Option<String> {
    let joined = warnings
        .iter()
        .map(|warning| warning.trim())
        .filter(|warning| !warning.is_empty())
        .collect::<Vec<_>>()
        .join("; ");
    if joined.is_empty() {
        None
    } else {
        Some(joined)
    }
}

fn infer_mode(entry: Option<&CaptureInboxEntry>) -> String {
    match entry.map(|entry| entry.entry_point.as_str()) {
        Some("voice") => "voice".to_string(),
        _ => "ai".to_string(),
    }
}

fn infer_parser_mode(mode: &str, entry: Option<&CaptureInboxEntry>) -> ParserMode {
    match (mode, entry.map(|entry| entry.entry_point.as_str())) {
        ("voice", _) => ParserMode::Deep,
        ("ai", Some("quick_capture" | "launcher_shortcut" | "quick_settings")) => ParserMode::Fast,
        ("ai", _) => ParserMode::Auto,
        _ => ParserMode::Rule,
    }
}

fn route_query_value(route_hint: Option<&str>, key: &str) -> Option<String> {
    let route_hint = route_hint?;
    let (_, query) = route_hint.split_once('?')?;
    query.split('&').find_map(|pair| {
        let (name, value) = pair.split_once('=')?;
        if name == key && !value.trim().is_empty() {
            Some(value.to_string())
        } else {
            None
        }
    })
}

fn build_capture_route(route_hint: Option<&str>, mode: &str, record_type: Option<&str>) -> String {
    if let Some(route_hint) = route_hint.filter(|value| !value.trim().is_empty()) {
        return route_hint.to_string();
    }
    let mut route = format!("/capture?mode={mode}");
    if let Some(record_type) = record_type.filter(|value| !value.trim().is_empty()) {
        route.push_str("&type=");
        route.push_str(record_type);
    }
    route
}
