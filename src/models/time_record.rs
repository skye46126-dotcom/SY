use chrono::{DateTime, SecondsFormat, Utc};
use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{
    normalize_code, normalize_optional_string, normalize_required_string, parse_date,
    parse_optional_rfc3339_utc, validate_percentage, validate_score,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProjectAllocation {
    pub project_id: String,
    pub weight_ratio: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateTimeRecordInput {
    pub user_id: String,
    pub occurred_on: Option<String>,
    pub started_at: Option<String>,
    pub ended_at: Option<String>,
    pub duration_minutes: Option<i64>,
    pub category_code: String,
    pub content: Option<String>,
    pub application_level_code: Option<String>,
    pub efficiency_score: Option<i32>,
    pub value_score: Option<i32>,
    pub state_score: Option<i32>,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: Option<String>,
    pub is_public_pool: bool,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

impl Default for CreateTimeRecordInput {
    fn default() -> Self {
        Self {
            user_id: String::new(),
            occurred_on: None,
            started_at: None,
            ended_at: None,
            duration_minutes: None,
            category_code: String::new(),
            content: None,
            application_level_code: None,
            efficiency_score: None,
            value_score: None,
            state_score: None,
            ai_assist_ratio: None,
            note: None,
            source: None,
            is_public_pool: false,
            project_allocations: Vec::new(),
            tag_ids: Vec::new(),
        }
    }
}

impl CreateTimeRecordInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_code("category_code", &self.category_code)?;
        parse_date("occurred_on", &self.resolved_occurred_on()?)?;
        normalize_required_string("content", &self.resolved_content())?;

        let started_at = parse_optional_rfc3339_utc("started_at", &self.started_at)?;
        let ended_at = parse_optional_rfc3339_utc("ended_at", &self.ended_at)?;
        match (started_at, ended_at) {
            (Some(started_at), Some(ended_at)) if ended_at <= started_at => {
                return Err(LifeOsError::InvalidInput(
                    "ended_at must be later than started_at".to_string(),
                ));
            }
            (Some(_), Some(_)) | (None, None) => {}
            _ => {
                return Err(LifeOsError::InvalidInput(
                    "started_at and ended_at must be both set or both empty".to_string(),
                ));
            }
        }

        if self.duration_minutes()? <= 0 {
            return Err(LifeOsError::InvalidInput(
                "duration_minutes must be positive".to_string(),
            ));
        }
        if let Some(level) = &self.application_level_code {
            normalize_code("application_level_code", level)?;
        }

        validate_score("efficiency_score", self.efficiency_score)?;
        validate_score("value_score", self.value_score)?;
        validate_score("state_score", self.state_score)?;
        validate_percentage("ai_assist_ratio", self.ai_assist_ratio)?;
        for allocation in &self.project_allocations {
            normalize_required_string("project_allocation.project_id", &allocation.project_id)?;
            if allocation.weight_ratio <= 0.0 {
                return Err(LifeOsError::InvalidInput(
                    "project allocation weight_ratio must be positive".to_string(),
                ));
            }
        }

        Ok(())
    }

    pub fn started_at(&self) -> Result<Option<DateTime<Utc>>> {
        parse_optional_rfc3339_utc("started_at", &self.started_at)
    }

    pub fn ended_at(&self) -> Result<Option<DateTime<Utc>>> {
        parse_optional_rfc3339_utc("ended_at", &self.ended_at)
    }

    pub fn duration_minutes(&self) -> Result<i64> {
        if let Some(duration_minutes) = self.duration_minutes {
            return Ok(duration_minutes);
        }
        match (self.started_at()?, self.ended_at()?) {
            (Some(started), Some(ended)) => Ok((ended - started).num_minutes()),
            _ => Err(LifeOsError::InvalidInput(
                "duration_minutes is required when started_at/ended_at are empty".to_string(),
            )),
        }
    }

    pub fn normalized_category_code(&self) -> String {
        self.category_code.trim().to_lowercase()
    }

    pub fn normalized_application_level_code(&self) -> Option<String> {
        normalize_optional_string(&self.application_level_code).map(|value| value.to_lowercase())
    }

    pub fn resolved_occurred_on(&self) -> Result<String> {
        if let Some(occurred_on) = normalize_optional_string(&self.occurred_on) {
            return Ok(occurred_on);
        }
        if let Some(started_at) = self.started_at()? {
            return Ok(started_at.date_naive().to_string());
        }
        Err(LifeOsError::InvalidInput(
            "occurred_on is required when started_at is empty".to_string(),
        ))
    }

    pub fn resolved_content(&self) -> String {
        normalize_optional_string(&self.content)
            .or_else(|| normalize_optional_string(&self.note))
            .unwrap_or_else(|| self.normalized_category_code())
    }

    pub fn normalized_source(&self) -> String {
        normalize_optional_string(&self.source).unwrap_or_else(|| "manual".to_string())
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TimeRecord {
    pub id: String,
    pub user_id: String,
    pub occurred_on: String,
    pub started_at: Option<String>,
    pub ended_at: Option<String>,
    pub duration_minutes: i64,
    pub category_code: String,
    pub content: String,
    pub application_level_code: Option<String>,
    pub efficiency_score: Option<i32>,
    pub value_score: Option<i32>,
    pub state_score: Option<i32>,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: String,
    pub is_public_pool: bool,
    pub created_at: String,
    pub updated_at: String,
}

pub fn parse_rfc3339_utc(value: &str) -> Result<DateTime<Utc>> {
    DateTime::parse_from_rfc3339(value)
        .map(|value| value.with_timezone(&Utc))
        .map_err(|error| LifeOsError::Timestamp(error.to_string()))
}

pub fn to_utc_string(value: DateTime<Utc>) -> String {
    value.to_rfc3339_opts(SecondsFormat::Secs, true)
}
