use serde::{Deserialize, Serialize};

use crate::error::Result;
use crate::models::{
    ProjectAllocation, normalize_code, normalize_optional_string, normalize_required_string,
    parse_date, validate_percentage, validate_positive_amount,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateIncomeRecordInput {
    pub user_id: String,
    pub occurred_on: String,
    pub source_name: String,
    pub type_code: String,
    pub amount_cents: i64,
    pub is_passive: bool,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: Option<String>,
    pub is_public_pool: bool,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

impl CreateIncomeRecordInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        parse_date("occurred_on", &self.occurred_on)?;
        normalize_required_string("source_name", &self.source_name)?;
        normalize_code("type_code", &self.type_code)?;
        validate_positive_amount("amount_cents", self.amount_cents)?;
        validate_percentage("ai_assist_ratio", self.ai_assist_ratio)?;
        for allocation in &self.project_allocations {
            normalize_required_string("project_allocation.project_id", &allocation.project_id)?;
            if allocation.weight_ratio <= 0.0 {
                return Err(crate::error::LifeOsError::InvalidInput(
                    "project allocation weight_ratio must be positive".to_string(),
                ));
            }
        }
        Ok(())
    }

    pub fn normalized_type_code(&self) -> String {
        self.type_code.trim().to_lowercase()
    }

    pub fn normalized_source(&self) -> String {
        normalize_optional_string(&self.source).unwrap_or_else(|| "manual".to_string())
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct IncomeRecord {
    pub id: String,
    pub user_id: String,
    pub occurred_on: String,
    pub source_name: String,
    pub type_code: String,
    pub amount_cents: i64,
    pub is_passive: bool,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: String,
    pub is_public_pool: bool,
    pub created_at: String,
    pub updated_at: String,
}
