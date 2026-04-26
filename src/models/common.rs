use chrono::{DateTime, NaiveDate, Utc};

use crate::error::{LifeOsError, Result};

pub fn normalize_required_string(field_name: &str, value: &str) -> Result<String> {
    let normalized = value.trim();
    if normalized.is_empty() {
        return Err(LifeOsError::InvalidInput(format!(
            "{field_name} is required"
        )));
    }
    Ok(normalized.to_string())
}

pub fn normalize_optional_string(value: &Option<String>) -> Option<String> {
    value
        .as_deref()
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(ToString::to_string)
}

pub fn normalize_code(field_name: &str, value: &str) -> Result<String> {
    let normalized = normalize_required_string(field_name, value)?;
    Ok(normalized.to_lowercase())
}

pub fn validate_percentage(field_name: &str, value: Option<i32>) -> Result<()> {
    if let Some(value) = value
        && !(0..=100).contains(&value)
    {
        return Err(LifeOsError::InvalidInput(format!(
            "{field_name} must be between 0 and 100"
        )));
    }
    Ok(())
}

pub fn validate_score(field_name: &str, value: Option<i32>) -> Result<()> {
    if let Some(value) = value
        && !(1..=10).contains(&value)
    {
        return Err(LifeOsError::InvalidInput(format!(
            "{field_name} must be between 1 and 10"
        )));
    }
    Ok(())
}

pub fn validate_positive_amount(field_name: &str, value: i64) -> Result<()> {
    if value < 0 {
        return Err(LifeOsError::InvalidInput(format!(
            "{field_name} must be zero or positive"
        )));
    }
    Ok(())
}

pub fn parse_date(field_name: &str, value: &str) -> Result<NaiveDate> {
    NaiveDate::parse_from_str(value, "%Y-%m-%d").map_err(|error| {
        LifeOsError::InvalidInput(format!(
            "{field_name} must be in YYYY-MM-DD format: {error}"
        ))
    })
}

pub fn parse_optional_rfc3339_utc(
    field_name: &str,
    value: &Option<String>,
) -> Result<Option<DateTime<Utc>>> {
    match value {
        Some(value) if !value.trim().is_empty() => DateTime::parse_from_rfc3339(value)
            .map(|value| Some(value.with_timezone(&Utc)))
            .map_err(|error| {
                LifeOsError::InvalidInput(format!(
                    "{field_name} must be a valid RFC3339 timestamp: {error}"
                ))
            }),
        _ => Ok(None),
    }
}
