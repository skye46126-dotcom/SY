use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{
    CaptureInboxAutoCommitResult, CaptureInboxEntry, CaptureInboxProcessResult, ParserMode,
    normalize_code, normalize_optional_string, normalize_required_string, parse_date,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CaptureBufferSessionStatus {
    Active,
    Processed,
    Committed,
    Archived,
}

impl CaptureBufferSessionStatus {
    pub fn from_str(value: &str) -> Result<Self> {
        let normalized = normalize_code("capture_buffer_session.status", value)?;
        match normalized.as_str() {
            "active" => Ok(Self::Active),
            "processed" => Ok(Self::Processed),
            "committed" => Ok(Self::Committed),
            "archived" => Ok(Self::Archived),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported capture buffer session status: {other}"
            ))),
        }
    }

    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Active => "active",
            Self::Processed => "processed",
            Self::Committed => "committed",
            Self::Archived => "archived",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureBufferSession {
    pub id: String,
    pub user_id: String,
    pub source: String,
    pub entry_point: String,
    pub context_date: Option<String>,
    pub route_hint: Option<String>,
    pub mode_hint: Option<String>,
    pub parser_mode_hint: Option<ParserMode>,
    pub status: CaptureBufferSessionStatus,
    pub item_count: usize,
    pub latest_combined_text: Option<String>,
    pub latest_inbox_id: Option<String>,
    pub processed_at: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateCaptureBufferSessionInput {
    pub user_id: String,
    pub source: String,
    pub entry_point: String,
    pub context_date: Option<String>,
    pub route_hint: Option<String>,
    pub mode_hint: Option<String>,
    pub parser_mode_hint: Option<ParserMode>,
}

impl CreateCaptureBufferSessionInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("source", &self.source)?;
        normalize_required_string("entry_point", &self.entry_point)?;
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
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureBufferItem {
    pub id: String,
    pub session_id: String,
    pub user_id: String,
    pub sequence_no: i64,
    pub raw_text: String,
    pub source: String,
    pub input_kind: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct AppendCaptureBufferItemInput {
    pub user_id: String,
    pub session_id: Option<String>,
    pub source: String,
    pub entry_point: Option<String>,
    pub context_date: Option<String>,
    pub route_hint: Option<String>,
    pub mode_hint: Option<String>,
    pub parser_mode_hint: Option<ParserMode>,
    pub raw_text: String,
    pub input_kind: Option<String>,
}

impl AppendCaptureBufferItemInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("source", &self.source)?;
        normalize_required_string("raw_text", &self.raw_text)?;
        if let Some(context_date) = &self.context_date {
            parse_date("context_date", context_date)?;
        }
        let _ = self.normalized_input_kind()?;
        Ok(())
    }

    pub fn normalized_source(&self) -> Result<String> {
        normalize_code("source", &self.source)
    }

    pub fn normalized_entry_point(&self) -> Option<String> {
        normalize_optional_string(&self.entry_point).map(|value| value.to_lowercase())
    }

    pub fn normalized_input_kind(&self) -> Result<String> {
        let normalized = self
            .input_kind
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .unwrap_or("text")
            .to_lowercase();
        if normalized == "text" || normalized == "voice" {
            Ok(normalized)
        } else {
            Err(LifeOsError::InvalidInput(format!(
                "unsupported capture buffer input kind: {normalized}"
            )))
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureBufferAppendResult {
    pub session: CaptureBufferSession,
    pub item: CaptureBufferItem,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureBufferItemsResult {
    pub session: CaptureBufferSession,
    pub items: Vec<CaptureBufferItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProcessCaptureBufferSessionInput {
    pub user_id: String,
    pub session_id: String,
    pub auto_commit: bool,
}

impl ProcessCaptureBufferSessionInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("session_id", &self.session_id)?;
        Ok(())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureBufferProcessResult {
    pub session: CaptureBufferSession,
    pub items: Vec<CaptureBufferItem>,
    pub combined_text: String,
    pub inbox_entry: CaptureInboxEntry,
    pub process_result: CaptureInboxProcessResult,
    pub auto_commit_result: Option<CaptureInboxAutoCommitResult>,
}
