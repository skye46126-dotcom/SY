pub mod ai;
pub mod cloud;
pub mod db;
pub mod error;
pub mod ffi;
pub mod models;
pub mod repositories;
pub mod services;

pub use crate::db::Database;
pub use crate::error::{LifeOsError, Result};
pub use crate::models::{
    AiCommitFailure, AiCommitInput, AiCommitOptions, AiCommitResult, AiCommittedRecord,
    AiDraftKind, AiParseDraft, AiParseInput, AiParseResult, AiProvider, AiServiceConfig,
    BackupRecord, BackupResult, BackupType, CapexCostInput, CapexCostSummary, CaptureDefaults,
    CaptureMetadata, CloudSyncConfig, CreateAiServiceConfigInput, CreateCloudSyncConfigInput,
    CreateExpenseRecordInput, CreateIncomeRecordInput, CreateLearningRecordInput,
    CreateProjectInput, CreateTagInput, CreateTimeRecordInput, DimensionOption,
    DimensionOptionInput, ExpenseRecord, ExpenseRecordSnapshot, IncomeRecord, IncomeRecordSnapshot,
    LearningRecord, LearningRecordSnapshot, MetricSnapshotSummary, MonthlyCostBaseline,
    MonthlyCostBaselineInput, OperatingSettings, ParseContext, ParserMode, Project,
    ProjectAllocation, ProjectDetail, ProjectMetricSnapshotSummary, ProjectOption, ProjectOverview,
    RateComparisonSummary, RecentRecordItem, RecordKind, RecurringCostRuleInput,
    RecurringCostRuleSummary, RemoteBackupFile, RemoteDownloadResult, RemoteUploadResult,
    RestoreRecord, RestoreResult, ReviewReport, ReviewTagMetric, ReviewWindow, ReviewWindowKind,
    SnapshotWindow, Tag, TimeCategoryAllocation, TimeRecord, TimeRecordSnapshot, TodayAlert,
    TodayAlerts, TodayGoalProgress, TodayGoalProgressItem, TodayOverview, TodaySummary,
    UpdateOperatingSettingsInput, UserProfile,
};
pub use crate::services::{
    AiService, BackupService, CostService, DemoDataResult, DemoDataService, ProjectService,
    RecordService, ReviewService, SnapshotService,
};
