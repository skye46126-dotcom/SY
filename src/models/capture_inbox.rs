use serde::{Deserialize, Serialize};
use serde_json::Value;

use crate::error::{LifeOsError, Result};
use crate::models::{
    AiCaptureCommitResult, ParsePipelineResult, ParserMode, normalize_code,
    normalize_optional_string, normalize_required_string, parse_date,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CaptureInboxStatus {
    Queued,
    Parsing,
    DraftReady,
    Committed,
    Failed,
    Archived,
}

impl CaptureInboxStatus {
    pub fn from_str(value: &str) -> Result<Self> {
        let normalized = normalize_code("capture_inbox.status", value)?;
        match normalized.as_str() {
            "queued" => Ok(Self::Queued),
            "parsing" => Ok(Self::Parsing),
            "draft_ready" => Ok(Self::DraftReady),
            "committed" => Ok(Self::Committed),
            "failed" => Ok(Self::Failed),
            "archived" => Ok(Self::Archived),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported capture inbox status: {other}"
            ))),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Queued => "queued",
            Self::Parsing => "parsing",
            Self::DraftReady => "draft_ready",
            Self::Committed => "committed",
            Self::Failed => "failed",
            Self::Archived => "archived",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateCaptureInboxEntryInput {
    pub user_id: String,
    pub source: String,
    pub entry_point: String,
    pub raw_text: String,
    pub context_date: Option<String>,
    pub route_hint: Option<String>,
    pub record_type_hint: Option<String>,
    pub mode_hint: Option<String>,
    pub parser_mode_hint: Option<ParserMode>,
    pub device_context: Option<Value>,
}

impl CreateCaptureInboxEntryInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("source", &self.source)?;
        normalize_required_string("entry_point", &self.entry_point)?;
        normalize_required_string("raw_text", &self.raw_text)?;
        if let Some(context_date) = &self.context_date {
            parse_date("context_date", context_date)?;
        }
        Ok(())
    }

    pub fn normalized_source(&self) -> Result<String> {
        normalize_code("source", &self.source)
    }

    pub fn normalized_entry_point(&self) -> Result<String> {
        normalize_code("entry_point", &self.entry_point)
    }

    pub fn normalized_route_hint(&self) -> Option<String> {
        normalize_optional_string(&self.route_hint)
    }

    pub fn normalized_record_type_hint(&self) -> Option<String> {
        normalize_optional_string(&self.record_type_hint).map(|value| value.to_lowercase())
    }

    pub fn normalized_mode_hint(&self) -> Option<String> {
        normalize_optional_string(&self.mode_hint).map(|value| value.to_lowercase())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureInboxEntry {
    pub id: String,
    pub user_id: String,
    pub source: String,
    pub entry_point: String,
    pub raw_text: String,
    pub context_date: Option<String>,
    pub route_hint: Option<String>,
    pub record_type_hint: Option<String>,
    pub mode_hint: Option<String>,
    pub parser_mode_hint: Option<ParserMode>,
    pub device_context: Option<Value>,
    pub status: CaptureInboxStatus,
    pub request_id: Option<String>,
    pub draft_envelope: Option<Value>,
    pub warnings: Vec<String>,
    pub error_message: Option<String>,
    pub processed_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProcessCaptureInboxInput {
    pub user_id: String,
    pub inbox_id: String,
    pub parser_mode_override: Option<ParserMode>,
}

impl ProcessCaptureInboxInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("inbox_id", &self.inbox_id)?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureInboxProcessResult {
    pub entry: CaptureInboxEntry,
    pub draft_envelope: ParsePipelineResult,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProcessCaptureInboxAndCommitInput {
    pub user_id: String,
    pub inbox_id: String,
    pub parser_mode_override: Option<ParserMode>,
}

impl ProcessCaptureInboxAndCommitInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("inbox_id", &self.inbox_id)?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureInboxAutoCommitResult {
    pub process_result: CaptureInboxProcessResult,
    pub commit_result: Option<AiCaptureCommitResult>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct PrepareCaptureSessionInput {
    pub user_id: String,
    pub inbox_id: Option<String>,
    pub route_hint: Option<String>,
    pub record_type_hint: Option<String>,
    pub mode_hint: Option<String>,
    pub parser_mode_override: Option<ParserMode>,
    pub prefill_text: Option<String>,
}

impl PrepareCaptureSessionInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureSessionProfile {
    pub user_id: String,
    pub inbox_id: Option<String>,
    pub source: Option<String>,
    pub entry_point: Option<String>,
    pub route: String,
    pub mode: String,
    pub record_type: Option<String>,
    pub parser_mode: ParserMode,
    pub context_date: Option<String>,
    pub prefill_text: Option<String>,
    pub focus_input: bool,
    pub auto_commit_capable: bool,
    pub defaults_applied: Vec<String>,
}
