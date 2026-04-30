use std::path::Path;

use crate::db::Database;
use crate::error::Result;
use crate::models::{
    CaptureMetadata, CreateExpenseRecordInput, CreateIncomeRecordInput, CreateProjectInput,
    CreateTagInput, CreateTimeRecordInput, DimensionOption, DimensionOptionInput, ExpenseRecord,
    ExpenseRecordSnapshot, IncomeRecord, IncomeRecordSnapshot, OperatingSettings, Project,
    RecentRecordItem, RecordKind, Tag, TimeRecord, TimeRecordSnapshot, TodayAlerts,
    TodayGoalProgress, TodayOverview, TodaySummary, UpdateOperatingSettingsInput, UserProfile,
};
use crate::repositories::record_repository::RecordRepository;

#[derive(Debug, Clone)]
pub struct RecordService {
    database: Database,
}

impl RecordService {
    pub fn new(database_path: impl Into<std::path::PathBuf>) -> Self {
        Self {
            database: Database::new(database_path),
        }
    }

    pub fn database_path(&self) -> &Path {
        self.database.path()
    }

    pub fn init_database(&self) -> Result<UserProfile> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        self.database.ensure_default_user(&mut connection)
    }

    pub fn create_time_record(&self, input: &CreateTimeRecordInput) -> Result<TimeRecord> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::create_time_record(&mut connection, input)
    }

    pub fn create_income_record(&self, input: &CreateIncomeRecordInput) -> Result<IncomeRecord> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::create_income_record(&mut connection, input)
    }

    pub fn create_expense_record(&self, input: &CreateExpenseRecordInput) -> Result<ExpenseRecord> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::create_expense_record(&mut connection, input)
    }

    pub fn create_project(&self, input: &CreateProjectInput) -> Result<Project> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::create_project(&mut connection, input)
    }

    pub fn create_tag(&self, input: &CreateTagInput) -> Result<Tag> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::create_tag(&mut connection, input)
    }

    pub fn list_tags(&self, user_id: &str) -> Result<Vec<Tag>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::list_tags(&connection, user_id)
    }

    pub fn update_tag(&self, tag_id: &str, input: &CreateTagInput) -> Result<Tag> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::update_tag(&mut connection, tag_id, input)
    }

    pub fn delete_tag(&self, user_id: &str, tag_id: &str) -> Result<()> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::delete_tag(&mut connection, user_id, tag_id)
    }

    pub fn get_capture_metadata(&self, user_id: &str) -> Result<CaptureMetadata> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_capture_metadata(&connection, user_id)
    }

    pub fn list_dimension_options(
        &self,
        user_id: &str,
        kind: &str,
        include_inactive: bool,
    ) -> Result<Vec<DimensionOption>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::list_dimension_options_for_kind(
            &connection,
            user_id,
            kind,
            include_inactive,
        )
    }

    pub fn save_dimension_option(
        &self,
        user_id: &str,
        kind: &str,
        input: &DimensionOptionInput,
    ) -> Result<DimensionOption> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::save_dimension_option(&mut connection, user_id, kind, input)
    }

    pub fn get_operating_settings(&self, user_id: &str) -> Result<OperatingSettings> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_operating_settings(&connection, user_id)
    }

    pub fn update_operating_settings(
        &self,
        user_id: &str,
        input: &UpdateOperatingSettingsInput,
    ) -> Result<OperatingSettings> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::update_operating_settings(&mut connection, user_id, input)
    }

    pub fn get_today_overview(
        &self,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodayOverview> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_today_overview(&connection, user_id, anchor_date, timezone)
    }

    pub fn get_today_goal_progress(
        &self,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodayGoalProgress> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_today_goal_progress(&connection, user_id, anchor_date, timezone)
    }

    pub fn get_today_alerts(
        &self,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodayAlerts> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_today_alerts(&connection, user_id, anchor_date, timezone)
    }

    pub fn get_today_summary(
        &self,
        user_id: &str,
        anchor_date: &str,
        timezone: &str,
    ) -> Result<TodaySummary> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_today_summary(&connection, user_id, anchor_date, timezone)
    }

    pub fn update_time_record(
        &self,
        record_id: &str,
        input: &CreateTimeRecordInput,
    ) -> Result<TimeRecord> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::update_time_record(&mut connection, record_id, input)
    }

    pub fn update_income_record(
        &self,
        record_id: &str,
        input: &CreateIncomeRecordInput,
    ) -> Result<IncomeRecord> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::update_income_record(&mut connection, record_id, input)
    }

    pub fn update_expense_record(
        &self,
        record_id: &str,
        input: &CreateExpenseRecordInput,
    ) -> Result<ExpenseRecord> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::update_expense_record(&mut connection, record_id, input)
    }

    pub fn delete_record(&self, kind: RecordKind, user_id: &str, record_id: &str) -> Result<()> {
        self.database.initialize()?;
        let mut connection = self.database.connect()?;
        RecordRepository::soft_delete_record(&mut connection, kind, user_id, record_id)
    }

    pub fn get_recent_records(
        &self,
        user_id: &str,
        timezone: &str,
        limit: usize,
    ) -> Result<Vec<RecentRecordItem>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_recent_records(&connection, user_id, timezone, limit)
    }

    pub fn get_records_for_date(
        &self,
        user_id: &str,
        date: &str,
        timezone: &str,
        limit: usize,
    ) -> Result<Vec<RecentRecordItem>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_records_for_date(&connection, user_id, date, timezone, limit)
    }

    pub fn get_time_record_snapshot(
        &self,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<TimeRecordSnapshot>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_time_record_snapshot(&connection, user_id, record_id)
    }

    pub fn get_income_record_snapshot(
        &self,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<IncomeRecordSnapshot>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_income_record_snapshot(&connection, user_id, record_id)
    }

    pub fn get_expense_record_snapshot(
        &self,
        user_id: &str,
        record_id: &str,
    ) -> Result<Option<ExpenseRecordSnapshot>> {
        self.database.initialize()?;
        let connection = self.database.connect()?;
        RecordRepository::get_expense_record_snapshot(&connection, user_id, record_id)
    }
}
