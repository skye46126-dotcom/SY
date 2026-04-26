use chrono::{Datelike, NaiveDate};
use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{
    normalize_code, normalize_optional_string, normalize_required_string, parse_date,
};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct MonthlyCostBaseline {
    pub month: String,
    pub basic_living_cents: i64,
    pub fixed_subscription_cents: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct MonthlyCostBaselineInput {
    pub month: String,
    pub basic_living_cents: i64,
    pub fixed_subscription_cents: i64,
    pub note: Option<String>,
}

impl MonthlyCostBaselineInput {
    pub fn validate(&self) -> Result<()> {
        parse_month(&self.month)?;
        if self.basic_living_cents < 0 {
            return Err(LifeOsError::InvalidInput(
                "basic_living_cents must be zero or positive".to_string(),
            ));
        }
        if self.fixed_subscription_cents < 0 {
            return Err(LifeOsError::InvalidInput(
                "fixed_subscription_cents must be zero or positive".to_string(),
            ));
        }
        Ok(())
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RecurringCostRuleSummary {
    pub id: String,
    pub name: String,
    pub category_code: String,
    pub monthly_amount_cents: i64,
    pub is_necessary: bool,
    pub start_month: String,
    pub end_month: Option<String>,
    pub is_active: bool,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct RecurringCostRuleInput {
    pub name: String,
    pub category_code: String,
    pub monthly_amount_cents: i64,
    pub is_necessary: bool,
    pub start_month: String,
    pub end_month: Option<String>,
    pub note: Option<String>,
}

impl RecurringCostRuleInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("name", &self.name)?;
        normalize_code("category_code", &self.category_code)?;
        if self.monthly_amount_cents < 0 {
            return Err(LifeOsError::InvalidInput(
                "monthly_amount_cents must be zero or positive".to_string(),
            ));
        }
        let start_month = parse_month(&self.start_month)?;
        if let Some(end_month) = &self.end_month {
            let end_month = parse_month(end_month)?;
            if end_month < start_month {
                return Err(LifeOsError::InvalidInput(
                    "end_month must be greater than or equal to start_month".to_string(),
                ));
            }
        }
        Ok(())
    }

    pub fn normalized_category_code(&self) -> String {
        self.category_code.trim().to_lowercase()
    }

    pub fn normalized_name(&self) -> String {
        self.name.trim().to_string()
    }

    pub fn normalized_end_month(&self) -> Option<String> {
        self.end_month
            .as_deref()
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(ToString::to_string)
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CapexCostSummary {
    pub id: String,
    pub name: String,
    pub purchase_date: String,
    pub purchase_amount_cents: i64,
    pub useful_months: i32,
    pub residual_rate_bps: i32,
    pub monthly_amortized_cents: i64,
    pub amortization_start_month: String,
    pub amortization_end_month: String,
    pub is_active: bool,
    pub note: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CapexCostInput {
    pub name: String,
    pub purchase_date: String,
    pub purchase_amount_cents: i64,
    pub useful_months: i32,
    pub residual_rate_bps: i32,
    pub note: Option<String>,
}

impl CapexCostInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("name", &self.name)?;
        parse_date("purchase_date", &self.purchase_date)?;
        if self.purchase_amount_cents < 0 {
            return Err(LifeOsError::InvalidInput(
                "purchase_amount_cents must be zero or positive".to_string(),
            ));
        }
        if self.useful_months <= 0 {
            return Err(LifeOsError::InvalidInput(
                "useful_months must be greater than 0".to_string(),
            ));
        }
        if !(0..=10000).contains(&self.residual_rate_bps) {
            return Err(LifeOsError::InvalidInput(
                "residual_rate_bps must be between 0 and 10000".to_string(),
            ));
        }
        Ok(())
    }

    pub fn normalized_name(&self) -> String {
        self.name.trim().to_string()
    }

    pub fn normalized_note(&self) -> Option<String> {
        normalize_optional_string(&self.note)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct RateComparisonSummary {
    pub anchor_date: String,
    pub window_type: String,
    pub ideal_hourly_rate_cents: i64,
    pub previous_year_average_hourly_rate_cents: Option<i64>,
    pub actual_hourly_rate_cents: Option<i64>,
    pub previous_year_income_cents: i64,
    pub previous_year_work_minutes: i64,
    pub current_income_cents: i64,
    pub current_work_minutes: i64,
}

pub fn parse_month(value: &str) -> Result<(i32, u32)> {
    let normalized = value.trim();
    let composed = format!("{normalized}-01");
    let parsed = NaiveDate::parse_from_str(&composed, "%Y-%m-%d").map_err(|error| {
        LifeOsError::InvalidInput(format!("month must be in YYYY-MM format: {error}"))
    })?;
    Ok((parsed.year(), parsed.month()))
}
