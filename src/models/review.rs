use chrono::{Datelike, Duration, Local, NaiveDate};
use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::RecentRecordItem;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub enum ReviewWindowKind {
    Day,
    Week,
    Month,
    Year,
    Range,
}

impl ReviewWindowKind {
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::Day => "day",
            Self::Week => "week",
            Self::Month => "month",
            Self::Year => "year",
            Self::Range => "range",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct ReviewWindow {
    pub kind: ReviewWindowKind,
    pub period_name: String,
    pub start_date: String,
    pub end_date: String,
    pub previous_start_date: String,
    pub previous_end_date: String,
}

impl ReviewWindow {
    pub fn validate(&self) -> Result<()> {
        let start = NaiveDate::parse_from_str(&self.start_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid start_date: {error}")))?;
        let end = NaiveDate::parse_from_str(&self.end_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid end_date: {error}")))?;
        if end < start {
            return Err(LifeOsError::InvalidInput(
                "review end_date must be greater than or equal to start_date".to_string(),
            ));
        }
        let previous_start = NaiveDate::parse_from_str(&self.previous_start_date, "%Y-%m-%d")
            .map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid previous_start_date: {error}"))
            })?;
        let previous_end =
            NaiveDate::parse_from_str(&self.previous_end_date, "%Y-%m-%d").map_err(|error| {
                LifeOsError::InvalidInput(format!("invalid previous_end_date: {error}"))
            })?;
        if previous_end < previous_start {
            return Err(LifeOsError::InvalidInput(
                "review previous_end_date must be greater than or equal to previous_start_date"
                    .to_string(),
            ));
        }
        Ok(())
    }

    pub fn from_day(anchor: NaiveDate) -> Self {
        let previous = anchor - Duration::days(1);
        Self {
            kind: ReviewWindowKind::Day,
            period_name: format!("Daily Review ({anchor})"),
            start_date: anchor.to_string(),
            end_date: anchor.to_string(),
            previous_start_date: previous.to_string(),
            previous_end_date: previous.to_string(),
        }
    }

    pub fn from_week(anchor: NaiveDate) -> Self {
        let weekday_offset = anchor.weekday().num_days_from_monday() as i64;
        let start = anchor - Duration::days(weekday_offset);
        let end = start + Duration::days(6);
        let previous_start = start - Duration::days(7);
        let previous_end = end - Duration::days(7);
        Self {
            kind: ReviewWindowKind::Week,
            period_name: format!("Weekly Review ({start} to {end})"),
            start_date: start.to_string(),
            end_date: end.to_string(),
            previous_start_date: previous_start.to_string(),
            previous_end_date: previous_end.to_string(),
        }
    }

    pub fn from_month(anchor: NaiveDate) -> Self {
        let start = NaiveDate::from_ymd_opt(anchor.year(), anchor.month(), 1).expect("valid month");
        let (next_year, next_month) = if anchor.month() == 12 {
            (anchor.year() + 1, 1)
        } else {
            (anchor.year(), anchor.month() + 1)
        };
        let end = NaiveDate::from_ymd_opt(next_year, next_month, 1).expect("valid next month")
            - Duration::days(1);
        let previous_anchor = if anchor.month() == 1 {
            NaiveDate::from_ymd_opt(anchor.year() - 1, 12, 1).expect("valid previous month")
        } else {
            NaiveDate::from_ymd_opt(anchor.year(), anchor.month() - 1, 1)
                .expect("valid previous month")
        };
        let previous_start =
            NaiveDate::from_ymd_opt(previous_anchor.year(), previous_anchor.month(), 1)
                .expect("valid previous month start");
        let (previous_next_year, previous_next_month) = if previous_anchor.month() == 12 {
            (previous_anchor.year() + 1, 1)
        } else {
            (previous_anchor.year(), previous_anchor.month() + 1)
        };
        let previous_end = NaiveDate::from_ymd_opt(previous_next_year, previous_next_month, 1)
            .expect("valid previous next month")
            - Duration::days(1);
        Self {
            kind: ReviewWindowKind::Month,
            period_name: format!("Monthly Review ({start} to {end})"),
            start_date: start.to_string(),
            end_date: end.to_string(),
            previous_start_date: previous_start.to_string(),
            previous_end_date: previous_end.to_string(),
        }
    }

    pub fn from_year(anchor: NaiveDate) -> Self {
        let start = NaiveDate::from_ymd_opt(anchor.year(), 1, 1).expect("valid year start");
        let end = NaiveDate::from_ymd_opt(anchor.year(), 12, 31).expect("valid year end");
        let previous_start =
            NaiveDate::from_ymd_opt(anchor.year() - 1, 1, 1).expect("valid previous year start");
        let previous_end =
            NaiveDate::from_ymd_opt(anchor.year() - 1, 12, 31).expect("valid previous year end");
        Self {
            kind: ReviewWindowKind::Year,
            period_name: format!("Yearly Review ({start} to {end})"),
            start_date: start.to_string(),
            end_date: end.to_string(),
            previous_start_date: previous_start.to_string(),
            previous_end_date: previous_end.to_string(),
        }
    }

    pub fn from_range(mut start: NaiveDate, mut end: NaiveDate) -> Self {
        if end < start {
            std::mem::swap(&mut start, &mut end);
        }
        let day_count = (end - start).num_days() + 1;
        let previous_start = start - Duration::days(day_count);
        let previous_end = end - Duration::days(day_count);
        Self {
            kind: ReviewWindowKind::Range,
            period_name: format!("Custom Review ({start} to {end})"),
            start_date: start.to_string(),
            end_date: end.to_string(),
            previous_start_date: previous_start.to_string(),
            previous_end_date: previous_end.to_string(),
        }
    }

    pub fn from_today() -> Self {
        Self::from_day(Local::now().date_naive())
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct TimeCategoryAllocation {
    pub category_name: String,
    pub minutes: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReviewTagMetric {
    pub tag_name: String,
    pub emoji: Option<String>,
    pub value: i64,
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ProjectProgressItem {
    pub project_id: String,
    pub project_name: String,
    pub time_spent_minutes: i64,
    pub income_earned_cents: i64,
    pub direct_expense_cents: i64,
    pub time_cost_cents: i64,
    pub allocated_structural_cost_cents: i64,
    pub operating_cost_cents: i64,
    pub fully_loaded_cost_cents: i64,
    pub hourly_rate_yuan: f64,
    pub operating_roi_perc: f64,
    pub fully_loaded_roi_perc: f64,
    pub evaluation_status: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct ReviewReport {
    pub window: ReviewWindow,
    pub ai_summary: String,
    pub total_time_minutes: i64,
    pub total_work_minutes: i64,
    pub total_income_cents: i64,
    pub total_expense_cents: i64,
    pub previous_income_cents: i64,
    pub previous_expense_cents: i64,
    pub previous_work_minutes: i64,
    pub income_change_ratio: Option<f64>,
    pub expense_change_ratio: Option<f64>,
    pub work_change_ratio: Option<f64>,
    pub actual_hourly_rate_cents: Option<i64>,
    pub ideal_hourly_rate_cents: i64,
    pub time_debt_cents: Option<i64>,
    pub passive_cover_ratio: Option<f64>,
    pub ai_assist_rate: Option<f64>,
    pub work_efficiency_avg: Option<f64>,
    pub learning_efficiency_avg: Option<f64>,
    pub time_allocations: Vec<TimeCategoryAllocation>,
    pub top_projects: Vec<ProjectProgressItem>,
    pub sinkhole_projects: Vec<ProjectProgressItem>,
    pub key_events: Vec<RecentRecordItem>,
    pub income_history: Vec<RecentRecordItem>,
    pub history_records: Vec<RecentRecordItem>,
    pub time_tag_metrics: Vec<ReviewTagMetric>,
    pub expense_tag_metrics: Vec<ReviewTagMetric>,
}
