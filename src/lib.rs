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
    AiCaptureCommitInput, AiCaptureCommitResult, AiCommitFailure, AiCommitInput, AiCommitOptions,
    AiCommitResult, AiCommittedRecord, AiDraftKind, AiParseDraft, AiParseInput, AiParseResult,
    AiProvider, AiServiceConfig, AppendCaptureBufferItemInput, BackupRecord, BackupResult,
    BackupType, CapexCostInput, CapexCostSummary, CaptureBufferAppendResult, CaptureBufferItem,
    CaptureBufferItemsResult, CaptureBufferProcessResult, CaptureBufferSession,
    CaptureBufferSessionStatus, CaptureDefaults, CaptureInboxAutoCommitResult, CaptureInboxEntry,
    CaptureInboxProcessResult, CaptureInboxStatus, CaptureMetadata, CaptureSessionProfile,
    CloudSyncConfig, CommitCaptureDraftEnvelopeInput, CommitReviewableDraftInput,
    CreateAiServiceConfigInput, CreateCaptureBufferSessionInput, CreateCaptureInboxEntryInput,
    CreateCloudSyncConfigInput, CreateExpenseRecordInput, CreateIncomeRecordInput,
    CreateProjectInput, CreateReviewNoteInput, CreateTagInput, CreateTimeRecordInput,
    DimensionOption, DimensionOptionInput, DraftDimensionBinding, DraftField, DraftFieldSource,
    DraftIntent, DraftLinks, DraftProjectLink, DraftStatus, DraftTagLink, DraftValidation,
    ExpenseRecord, ExpenseRecordSnapshot, IncomeRecord, IncomeRecordSnapshot,
    MetricSnapshotSummary, MonthlyCostBaseline, MonthlyCostBaselineInput, OperatingSettings,
    ParseContext, ParsePipelineResult, ParserMode, PrepareCaptureSessionInput,
    ProcessCaptureBufferSessionInput, ProcessCaptureInboxAndCommitInput, ProcessCaptureInboxInput,
    Project, ProjectAllocation, ProjectDetail, ProjectMetricSnapshotSummary, ProjectOption,
    ProjectOverview, RateComparisonSummary, RecentRecordItem, RecordKind, RecurringCostRuleInput,
    RecurringCostRuleSummary, RemoteBackupFile, RemoteDownloadResult, RemoteUploadResult,
    RestoreRecord, RestoreResult, ReviewNote, ReviewNoteDraft, ReviewReport, ReviewTagMetric,
    ReviewWindow, ReviewWindowKind, ReviewableDraft, SnapshotWindow, Tag, TimeCategoryAllocation,
    TimeRecord, TimeRecordSnapshot, TodayAlert, TodayAlerts, TodayGoalProgress,
    TodayGoalProgressItem, TodayOverview, TodaySummary, TypedDraftKind,
    UpdateOperatingSettingsInput, UserProfile,
};
pub use crate::services::{
    AiService, BackupService, CaptureService, CostService, DemoDataResult, DemoDataService,
    ProjectService, RecordService, ReviewNoteService, ReviewService, SnapshotService,
};
