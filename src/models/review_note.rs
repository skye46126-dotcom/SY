use serde::{Deserialize, Serialize};
use uuid::Uuid;

use crate::error::{LifeOsError, Result};
use crate::models::{
    normalize_code, normalize_optional_string, normalize_required_string, parse_date,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReviewNote {
    pub id: String,
    pub user_id: String,
    pub occurred_on: String,
    pub note_type: String,
    pub title: String,
    pub content: String,
    pub source: String,
    pub visibility: String,
    pub confidence: Option<f64>,
    pub raw_text: Option<String>,
    pub linked_record_kind: Option<String>,
    pub linked_record_id: Option<String>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReviewNoteDraft {
    pub draft_id: String,
    pub raw_text: String,
    pub occurred_on: Option<String>,
    pub note_type: String,
    pub title: String,
    pub content: String,
    pub source: String,
    pub visibility: String,
    pub confidence: Option<f64>,
    pub linked_record_kind: Option<String>,
    pub linked_record_id: Option<String>,
}

impl ReviewNoteDraft {
    pub fn new(
        raw_text: impl Into<String>,
        title: impl Into<String>,
        note_type: impl Into<String>,
        content: impl Into<String>,
        source: impl Into<String>,
        confidence: Option<f64>,
    ) -> Self {
        Self {
            draft_id: Uuid::now_v7().to_string(),
            raw_text: raw_text.into(),
            occurred_on: None,
            note_type: note_type.into(),
            title: title.into(),
            content: content.into(),
            source: source.into(),
            visibility: "compact".to_string(),
            confidence,
            linked_record_kind: None,
            linked_record_id: None,
        }
    }

    pub fn validate(&self) -> Result<()> {
        normalize_required_string("content", &self.content)?;
        normalize_note_type(&self.note_type)?;
        normalize_note_source(&self.source)?;
        normalize_note_visibility(&self.visibility)?;
        if let Some(occurred_on) = &self.occurred_on {
            parse_date("occurred_on", occurred_on)?;
        }
        validate_confidence(self.confidence)?;
        if let Some(kind) = &self.linked_record_kind {
            normalize_linked_record_kind(kind)?;
        }
        Ok(())
    }

    pub fn to_create_input(
        &self,
        user_id: &str,
        context_date: &str,
    ) -> Result<CreateReviewNoteInput> {
        self.validate()?;
        Ok(CreateReviewNoteInput {
            user_id: user_id.to_string(),
            occurred_on: self
                .occurred_on
                .as_deref()
                .map(str::trim)
                .filter(|value| !value.is_empty())
                .unwrap_or(context_date)
                .to_string(),
            note_type: self.note_type.clone(),
            title: self.title.clone(),
            content: self.content.clone(),
            source: self.source.clone(),
            visibility: self.visibility.clone(),
            confidence: self.confidence,
            raw_text: normalize_optional_string(&Some(self.raw_text.clone())),
            linked_record_kind: self.linked_record_kind.clone(),
            linked_record_id: self.linked_record_id.clone(),
        })
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct IgnoredContext {
    pub raw_text: String,
    pub reason: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateReviewNoteInput {
    pub user_id: String,
    pub occurred_on: String,
    pub note_type: String,
    pub title: String,
    pub content: String,
    pub source: String,
    pub visibility: String,
    pub confidence: Option<f64>,
    pub raw_text: Option<String>,
    pub linked_record_kind: Option<String>,
    pub linked_record_id: Option<String>,
}

impl CreateReviewNoteInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        parse_date("occurred_on", &self.occurred_on)?;
        normalize_note_type(&self.note_type)?;
        normalize_required_string("title", &self.title)?;
        normalize_required_string("content", &self.content)?;
        normalize_note_source(&self.source)?;
        normalize_note_visibility(&self.visibility)?;
        validate_confidence(self.confidence)?;
        if let Some(kind) = &self.linked_record_kind {
            normalize_linked_record_kind(kind)?;
        }
        Ok(())
    }

    pub fn normalized_note_type(&self) -> Result<String> {
        normalize_note_type(&self.note_type)
    }

    pub fn normalized_source(&self) -> Result<String> {
        normalize_note_source(&self.source)
    }

    pub fn normalized_visibility(&self) -> Result<String> {
        normalize_note_visibility(&self.visibility)
    }

    pub fn normalized_title(&self) -> String {
        self.title.trim().to_string()
    }

    pub fn normalized_content(&self) -> String {
        self.content.trim().to_string()
    }

    pub fn normalized_raw_text(&self) -> Option<String> {
        normalize_optional_string(&self.raw_text)
    }

    pub fn normalized_linked_record_kind(&self) -> Result<Option<String>> {
        self.linked_record_kind
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(normalize_linked_record_kind)
            .transpose()
    }

    pub fn normalized_linked_record_id(&self) -> Option<String> {
        normalize_optional_string(&self.linked_record_id)
    }
}

fn normalize_note_type(value: &str) -> Result<String> {
    let normalized = normalize_code("note_type", value)?;
    match normalized.as_str() {
        "reflection" | "feeling" | "plan" | "idea" | "context" | "ai_usage" | "risk"
        | "summary" => Ok(normalized),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported review note type: {other}"
        ))),
    }
}

fn normalize_note_source(value: &str) -> Result<String> {
    let normalized = normalize_code("source", value)?;
    match normalized.as_str() {
        "manual" | "ai_capture" | "import" => Ok(normalized),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported review note source: {other}"
        ))),
    }
}

fn normalize_note_visibility(value: &str) -> Result<String> {
    let normalized = normalize_code("visibility", value)?;
    match normalized.as_str() {
        "hidden" | "compact" | "normal" => Ok(normalized),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported review note visibility: {other}"
        ))),
    }
}

fn normalize_linked_record_kind(value: &str) -> Result<String> {
    let normalized = normalize_code("linked_record_kind", value)?;
    match normalized.as_str() {
        "time" | "income" | "expense" => Ok(normalized),
        other => Err(LifeOsError::InvalidInput(format!(
            "unsupported linked record kind: {other}"
        ))),
    }
}

fn validate_confidence(value: Option<f64>) -> Result<()> {
    if let Some(value) = value
        && !(0.0..=1.0).contains(&value)
    {
        return Err(LifeOsError::InvalidInput(
            "confidence must be between 0.0 and 1.0".to_string(),
        ));
    }
    Ok(())
}
