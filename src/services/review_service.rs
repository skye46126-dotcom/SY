use std::path::Path;

use chrono::NaiveDate;

use crate::db::Database;
use crate::error::{LifeOsError, Result};
use crate::models::{RecentRecordItem, ReviewReport, ReviewWindow};
use crate::repositories::review_repository::ReviewRepository;

#[derive(Debug, Clone)]
pub struct ReviewService {
    database: Database,
}

impl ReviewService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn get_daily_review(
        &self,
        user_id: &str,
        date: &str,
        timezone: &str,
    ) -> Result<ReviewReport> {
        let date = NaiveDate::parse_from_str(date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid date: {error}")))?;
        self.get_review(user_id, &ReviewWindow::from_day(date), timezone)
    }

    pub fn get_weekly_review(
        &self,
        user_id: &str,
        date_in_week: &str,
        timezone: &str,
    ) -> Result<ReviewReport> {
        let date = NaiveDate::parse_from_str(date_in_week, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid date: {error}")))?;
        self.get_review(user_id, &ReviewWindow::from_week(date), timezone)
    }

    pub fn get_monthly_review(
        &self,
        user_id: &str,
        date_in_month: &str,
        timezone: &str,
    ) -> Result<ReviewReport> {
        let date = NaiveDate::parse_from_str(date_in_month, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid date: {error}")))?;
        self.get_review(user_id, &ReviewWindow::from_month(date), timezone)
    }

    pub fn get_yearly_review(
        &self,
        user_id: &str,
        date_in_year: &str,
        timezone: &str,
    ) -> Result<ReviewReport> {
        let date = NaiveDate::parse_from_str(date_in_year, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid date: {error}")))?;
        self.get_review(user_id, &ReviewWindow::from_year(date), timezone)
    }

    pub fn get_range_review(
        &self,
        user_id: &str,
        start_date: &str,
        end_date: &str,
        timezone: &str,
    ) -> Result<ReviewReport> {
        let start = NaiveDate::parse_from_str(start_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid start_date: {error}")))?;
        let end = NaiveDate::parse_from_str(end_date, "%Y-%m-%d")
            .map_err(|error| LifeOsError::InvalidInput(format!("invalid end_date: {error}")))?;
        self.get_review(user_id, &ReviewWindow::from_range(start, end), timezone)
    }

    pub fn get_review(
        &self,
        user_id: &str,
        window: &ReviewWindow,
        timezone: &str,
    ) -> Result<ReviewReport> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ReviewRepository::build_report(&connection, user_id, window, timezone)
    }

    pub fn get_tag_detail_records(
        &self,
        user_id: &str,
        scope: &str,
        tag_name: &str,
        start_date: &str,
        end_date: &str,
        timezone: &str,
        limit: usize,
    ) -> Result<Vec<RecentRecordItem>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        ReviewRepository::get_tag_detail_records(
            &connection,
            user_id,
            scope,
            tag_name,
            start_date,
            end_date,
            timezone,
            limit,
        )
    }
}
