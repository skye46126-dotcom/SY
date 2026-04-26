use chrono_tz::Tz;
use serde::{Deserialize, Serialize};

use crate::error::{LifeOsError, Result};
use crate::models::{ProjectOption, Tag, normalize_required_string};

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DimensionOption {
    pub code: String,
    pub display_name: String,
    pub is_active: bool,
    pub is_system: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct DimensionOptionInput {
    pub code: String,
    pub display_name: String,
    pub is_active: bool,
}

impl DimensionOptionInput {
    pub fn validate(&self) -> Result<()> {
        crate::models::normalize_code("code", &self.code)?;
        normalize_required_string("display_name", &self.display_name)?;
        Ok(())
    }

    pub fn normalized_code(&self) -> String {
        self.code.trim().to_lowercase()
    }

    pub fn normalized_display_name(&self) -> String {
        self.display_name.trim().to_string()
    }
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct CaptureDefaults {
    pub time_category_code: Option<String>,
    pub income_type_code: Option<String>,
    pub expense_category_code: Option<String>,
    pub learning_level_code: Option<String>,
    pub project_status_code: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub struct CaptureMetadata {
    pub project_options: Vec<ProjectOption>,
    pub tags: Vec<Tag>,
    pub time_categories: Vec<DimensionOption>,
    pub income_types: Vec<DimensionOption>,
    pub expense_categories: Vec<DimensionOption>,
    pub learning_levels: Vec<DimensionOption>,
    pub project_statuses: Vec<DimensionOption>,
    pub income_source_suggestions: Vec<String>,
    pub defaults: CaptureDefaults,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct OperatingSettings {
    pub timezone: String,
    pub currency_code: String,
    pub ideal_hourly_rate_cents: i64,
    pub today_work_target_minutes: i64,
    pub today_learning_target_minutes: i64,
    pub current_month: String,
    pub current_month_basic_living_cents: i64,
    pub current_month_fixed_subscription_cents: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct UpdateOperatingSettingsInput {
    pub timezone: String,
    pub currency_code: String,
    pub ideal_hourly_rate_cents: i64,
    pub today_work_target_minutes: i64,
    pub today_learning_target_minutes: i64,
}

impl UpdateOperatingSettingsInput {
    pub fn validate(&self) -> Result<()> {
        normalize_required_string("timezone", &self.timezone)?;
        self.timezone.parse::<Tz>().map_err(|_| {
            LifeOsError::InvalidTimezone(self.timezone.trim().to_string())
        })?;

        let currency = self.currency_code.trim().to_uppercase();
        if currency.len() != 3 || !currency.chars().all(|char| char.is_ascii_alphabetic()) {
            return Err(LifeOsError::InvalidInput(
                "currency_code must be a 3-letter ISO code".to_string(),
            ));
        }
        if self.ideal_hourly_rate_cents < 0 {
            return Err(LifeOsError::InvalidInput(
                "ideal_hourly_rate_cents must be zero or positive".to_string(),
            ));
        }
        if self.today_work_target_minutes < 0 {
            return Err(LifeOsError::InvalidInput(
                "today_work_target_minutes must be zero or positive".to_string(),
            ));
        }
        if self.today_learning_target_minutes < 0 {
            return Err(LifeOsError::InvalidInput(
                "today_learning_target_minutes must be zero or positive".to_string(),
            ));
        }
        Ok(())
    }

    pub fn normalized_timezone(&self) -> String {
        self.timezone.trim().to_string()
    }

    pub fn normalized_currency_code(&self) -> String {
        self.currency_code.trim().to_uppercase()
    }
}
