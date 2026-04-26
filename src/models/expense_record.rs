use serde::{Deserialize, Serialize};

use crate::error::Result;
use crate::models::{
    ProjectAllocation, normalize_code, normalize_optional_string, normalize_required_string,
    parse_date, validate_percentage, validate_positive_amount,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CreateExpenseRecordInput {
    pub user_id: String,
    pub occurred_on: String,
    pub category_code: String,
    pub amount_cents: i64,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: Option<String>,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

impl CreateExpenseRecordInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("user_id", &self.user_id)?;
        parse_date("occurred_on", &self.occurred_on)?;
        normalize_code("category_code", &self.category_code)?;
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
pub struct ExpenseRecord {
    pub id: String,
    pub user_id: String,
    pub occurred_on: String,
    pub category_code: String,
    pub amount_cents: i64,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub source: String,
    pub created_at: String,
    pub updated_at: String,
}
