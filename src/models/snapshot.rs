use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
pub enum SnapshotWindow {
    Day,
    Week,
    Month,
    Year,
}

impl SnapshotWindow {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Day => "day",
            Self::Week => "week",
            Self::Month => "month",
            Self::Year => "year",
        }
    }

    pub fn parse(value: &str) -> Result<Self> {
        match value.trim().to_lowercase().as_str() {
            "day" => Ok(Self::Day),
            "week" => Ok(Self::Week),
            "month" => Ok(Self::Month),
            "year" => Ok(Self::Year),
            other => Err(LifeOsError::InvalidInput(format!(
                "unsupported snapshot window: {other}"
            ))),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MetricSnapshotSummary {
    pub id: String,
    pub snapshot_date: String,
    pub window_type: String,
    pub hourly_rate_cents: Option<i64>,
    pub time_debt_cents: Option<i64>,
    pub passive_cover_ratio: Option<f64>,
    pub freedom_cents: Option<i64>,
    pub total_income_cents: Option<i64>,
    pub total_expense_cents: Option<i64>,
    pub total_work_minutes: Option<i64>,
    pub generated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProjectMetricSnapshotSummary {
    pub metric_snapshot_id: String,
    pub project_id: String,
    pub income_cents: i64,
    pub direct_expense_cents: i64,
    pub structural_cost_cents: i64,
    pub operating_cost_cents: i64,
    pub total_cost_cents: i64,
    pub profit_cents: i64,
    pub invested_minutes: i64,
    pub roi_ratio: f64,
    pub break_even_cents: i64,
}
