use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{
    ProjectAllocation, normalize_code, normalize_optional_string, normalize_required_string,
    parse_date, parse_optional_rfc3339_utc, validate_percentage, validate_score,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateLearningRecordInput {
    pub user_id: String,
    pub occurred_on: String,
    pub started_at: Option<String>,
    pub ended_at: Option<String>,
    pub content: String,
    pub duration_minutes: i64,
    pub application_level_code: String,
    pub efficiency_score: Option<i32>,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: Option<String>,
    pub is_public_pool: bool,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

impl CreateLearningRecordInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        parse_date("occurred_on", &self.occurred_on)?;
        normalize_required_string("content", &self.content)?;
        normalize_code("application_level_code", &self.application_level_code)?;
        validate_score("efficiency_score", self.efficiency_score)?;
        validate_percentage("ai_assist_ratio", self.ai_assist_ratio)?;
        if self.duration_minutes < 0 {
            return Err(LifeOsError::InvalidInput(
                "duration_minutes must be zero or positive".to_string(),
            ));
        }

        let started_at = parse_optional_rfc3339_utc("started_at", &self.started_at)?;
        let ended_at = parse_optional_rfc3339_utc("ended_at", &self.ended_at)?;
        if let (Some(started_at), Some(ended_at)) = (started_at, ended_at)
            && ended_at <= started_at
        {
            return Err(LifeOsError::InvalidInput(
                "ended_at must be later than started_at".to_string(),
            ));
        }

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

    pub fn normalized_application_level_code(&self) -> String {
        self.application_level_code.trim().to_lowercase()
    }

    pub fn normalized_source(&self) -> String {
        normalize_optional_string(&self.source).unwrap_or_else(|| "manual".to_string())
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LearningRecord {
    pub id: String,
    pub user_id: String,
    pub occurred_on: String,
    pub started_at: Option<String>,
    pub ended_at: Option<String>,
    pub content: String,
    pub duration_minutes: i64,
    pub application_level_code: String,
    pub efficiency_score: Option<i32>,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: String,
    pub is_public_pool: bool,
    pub created_at: String,
    pub updated_at: String,
}
