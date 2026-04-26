use serde::{Deserialize, Serialize};

use crate::error::Result;
use crate::models::{
    normalize_code, normalize_optional_string, normalize_required_string, parse_date,
    validate_percentage, validate_score,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateProjectInput {
    pub user_id: String,
    pub name: String,
    pub status_code: String,
    pub started_on: String,
    pub ended_on: Option<String>,
    pub ai_enable_ratio: Option<i32>,
    pub score: Option<i32>,
    pub note: Option<String>,
    pub tag_ids: Vec<String>,
}

impl CreateProjectInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        normalize_required_string("name", &self.name)?;
        normalize_code("status_code", &self.status_code)?;
        parse_date("started_on", &self.started_on)?;
        if let Some(ended_on) = &self.ended_on {
            parse_date("ended_on", ended_on)?;
        }
        validate_percentage("ai_enable_ratio", self.ai_enable_ratio)?;
        validate_score("score", self.score)?;
        Ok(())
    }

    pub fn normalized_name(&self) -> String {
        self.name.trim().to_string()
    }

    pub fn normalized_status_code(&self) -> String {
        self.status_code.trim().to_lowercase()
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }

    pub fn normalized_ended_on(&self) -> Option<String> {
        normalize_optional_string(&self.ended_on)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct Project {
    pub id: String,
    pub user_id: String,
    pub name: String,
    pub status_code: String,
    pub started_on: String,
    pub ended_on: Option<String>,
    pub ai_enable_ratio: Option<i32>,
    pub score: Option<i32>,
    pub note: Option<String>,
    pub is_deleted: bool,
    pub created_at: String,
    pub updated_at: String,
}
