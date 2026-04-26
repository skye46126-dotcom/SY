use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodayOverview {
    pub user_id: String,
    pub anchor_date: String,
    pub timezone: String,
    pub total_income_cents: i64,
    pub total_expense_cents: i64,
    pub net_income_cents: i64,
    pub total_time_minutes: i64,
    pub total_work_minutes: i64,
    pub total_learning_minutes: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodayGoalProgressItem {
    pub key: String,
    pub title: String,
    pub unit: String,
    pub target_value: i64,
    pub completed_value: i64,
    pub progress_ratio_bps: i64,
    pub status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodayGoalProgress {
    pub user_id: String,
    pub anchor_date: String,
    pub items: Vec<TodayGoalProgressItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodayAlert {
    pub code: String,
    pub title: String,
    pub message: String,
    pub severity: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodayAlerts {
    pub user_id: String,
    pub anchor_date: String,
    pub items: Vec<TodayAlert>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct TodaySummary {
    pub user_id: String,
    pub anchor_date: String,
    pub headline: String,
    pub finance_status: String,
    pub work_status: String,
    pub learning_status: String,
    pub should_review: bool,
    pub actual_hourly_rate_cents: Option<i64>,
    pub ideal_hourly_rate_cents: i64,
    pub freedom_cents: Option<i64>,
    pub passive_cover_ratio_bps: Option<i64>,
    pub alerts: Vec<TodayAlert>,
}
