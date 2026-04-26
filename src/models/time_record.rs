use chrono::{DateTime, SecondsFormat, Utc};
use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{
    normalize_code, normalize_optional_string, normalize_required_string, validate_percentage,
    validate_score,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProjectAllocation {
    pub project_id: String,
    pub weight_ratio: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateTimeRecordInput {
    pub user_id: String,
    pub started_at: String,
    pub ended_at: String,
    pub category_code: String,
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

impl CreateTimeRecordInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_code("category_code", &self.category_code)?;

        let started_at = self.started_at()?;
        let ended_at = self.ended_at()?;
        if ended_at <= started_at {
            return Err(LifeOsError::InvalidInput(
                "ended_at must be later than started_at".to_string(),
            ));
        }
        if self.duration_minutes()? <= 0 {
            return Err(LifeOsError::InvalidInput(
                "duration_minutes must be positive".to_string(),
            ));
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

    pub fn started_at(&self) -> Result<DateTime<Utc>> {
        parse_rfc3339_utc(&self.started_at)
    }

    pub fn ended_at(&self) -> Result<DateTime<Utc>> {
        parse_rfc3339_utc(&self.ended_at)
    }

    pub fn duration_minutes(&self) -> Result<i64> {
        let started = self.started_at()?;
        let ended = self.ended_at()?;
        Ok((ended - started).num_minutes())
    }

    pub fn normalized_category_code(&self) -> String {
        self.category_code.trim().to_lowercase()
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
    pub started_at: String,
    pub ended_at: String,
    pub duration_minutes: i64,
    pub category_code: String,
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
