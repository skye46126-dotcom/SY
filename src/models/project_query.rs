use serde::{Deserialize, Serialize};

use crate::models::RecentRecordItem;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProjectOption {
    pub id: String,
    pub name: String,
    pub status_code: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ProjectOverview {
    pub id: String,
    pub name: String,
    pub status_code: String,
    pub score: Option<i32>,
    pub total_time_minutes: i64,
    pub total_income_cents: i64,
    pub total_expense_cents: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProjectDetail {
    pub id: String,
    pub name: String,
    pub status_code: String,
    pub started_on: String,
    pub ended_on: Option<String>,
    pub ai_enable_ratio: Option<i32>,
    pub score: Option<i32>,
    pub note: Option<String>,
    pub tag_ids: Vec<String>,
    pub analysis_start_date: String,
    pub analysis_end_date: String,
    pub total_time_minutes: i64,
    pub total_income_cents: i64,
    pub total_expense_cents: i64,
    pub direct_expense_cents: i64,
    pub time_cost_cents: i64,
    pub total_cost_cents: i64,
    pub profit_cents: i64,
    pub break_even_income_cents: i64,
    pub allocated_structural_cost_cents: i64,
    pub operating_cost_cents: i64,
    pub operating_profit_cents: i64,
    pub operating_break_even_income_cents: i64,
    pub fully_loaded_cost_cents: i64,
    pub fully_loaded_profit_cents: i64,
    pub fully_loaded_break_even_income_cents: i64,
    pub benchmark_hourly_rate_cents: i64,
    pub last_year_hourly_rate_cents: i64,
    pub ideal_hourly_rate_cents: i64,
    pub hourly_rate_yuan: f64,
    pub roi_perc: f64,
    pub operating_roi_perc: f64,
    pub fully_loaded_roi_perc: f64,
    pub evaluation_status: String,
    pub total_learning_minutes: i64,
    pub time_record_count: i64,
    pub income_record_count: i64,
    pub expense_record_count: i64,
    pub learning_record_count: i64,
    pub recent_records: Vec<RecentRecordItem>,
}
