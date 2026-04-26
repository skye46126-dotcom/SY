use serde::{Deserialize, Serialize};

use crate::models::ProjectAllocation;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum RecordKind {
    Time,
    Income,
    Expense,
    Learning,
}

impl RecordKind {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Time => "time",
            Self::Income => "income",
            Self::Expense => "expense",
            Self::Learning => "learning",
        }
    }

    pub fn table_name(self) -> &'static str {
        match self {
            Self::Time => "time_records",
            Self::Income => "income_records",
            Self::Expense => "expense_records",
            Self::Learning => "learning_records",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RecentRecordItem {
    pub record_id: String,
    pub kind: RecordKind,
    pub occurred_at: String,
    pub title: String,
    pub detail: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TimeRecordSnapshot {
    pub record_id: String,
    pub started_at: String,
    pub ended_at: String,
    pub category_code: String,
    pub efficiency_score: Option<i32>,
    pub value_score: Option<i32>,
    pub state_score: Option<i32>,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct IncomeRecordSnapshot {
    pub record_id: String,
    pub occurred_on: String,
    pub source_name: String,
    pub type_code: String,
    pub amount_cents: i64,
    pub is_passive: bool,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub is_public_pool: bool,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ExpenseRecordSnapshot {
    pub record_id: String,
    pub occurred_on: String,
    pub category_code: String,
    pub amount_cents: i64,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct LearningRecordSnapshot {
    pub record_id: String,
    pub occurred_on: String,
    pub started_at: Option<String>,
    pub ended_at: Option<String>,
    pub content: String,
    pub duration_minutes: i64,
    pub application_level_code: String,
    pub efficiency_score: Option<i32>,
    pub ai_assist_ratio: Option<i32>,
    pub note: Option<String>,
    pub is_public_pool: bool,
    pub project_allocations: Vec<ProjectAllocation>,
    pub tag_ids: Vec<String>,
}
