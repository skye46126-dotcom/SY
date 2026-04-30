mod ai;
mod capture_buffer;
mod capture_inbox;
mod common;
mod cost;
mod expense_record;
mod income_record;
mod overview;
mod preferences;
mod project;
mod project_query;
mod record_query;
mod review;
mod review_note;
mod snapshot;
mod sync;
mod tag;
mod time_record;
mod user;

pub use ai::{
    AiCaptureCommitInput, AiCaptureCommitResult, AiCommitFailure, AiCommitInput, AiCommitOptions,
    AiCommitResult, AiCommittedRecord, AiDraftKind, AiParseDraft, AiParseInput, AiParseResult,
    AiProvider, AiServiceConfig, CommitCaptureDraftEnvelopeInput, CommitReviewableDraftInput,
    CreateAiServiceConfigInput, DraftDimensionBinding, DraftField, DraftFieldSource, DraftIntent,
    DraftLinks, DraftProjectLink, DraftStatus, DraftTagLink, DraftValidation, ParseContext,
    ParsePipelineResult, ParserMode, ReviewableDraft, TypedDraftKind,
};
pub use capture_buffer::{
    AppendCaptureBufferItemInput, CaptureBufferAppendResult, CaptureBufferItem,
    CaptureBufferItemsResult, CaptureBufferProcessResult, CaptureBufferSession,
    CaptureBufferSessionStatus, CreateCaptureBufferSessionInput, ProcessCaptureBufferSessionInput,
};
pub use capture_inbox::{
    CaptureInboxAutoCommitResult, CaptureInboxEntry, CaptureInboxProcessResult, CaptureInboxStatus,
    CaptureSessionProfile, CreateCaptureInboxEntryInput, PrepareCaptureSessionInput,
    ProcessCaptureInboxAndCommitInput, ProcessCaptureInboxInput,
};
pub(crate) use common::{
    normalize_code, normalize_optional_string, normalize_required_string, parse_date,
    parse_optional_rfc3339_utc, validate_percentage, validate_positive_amount, validate_score,
};
pub(crate) use cost::parse_month;
pub use cost::{
    CapexCostInput, CapexCostSummary, MonthlyCostBaseline, MonthlyCostBaselineInput,
    RateComparisonSummary, RecurringCostRuleInput, RecurringCostRuleSummary,
};
pub use expense_record::{CreateExpenseRecordInput, ExpenseRecord};
pub use income_record::{CreateIncomeRecordInput, IncomeRecord};
pub use overview::{
    TodayAlert, TodayAlerts, TodayGoalProgress, TodayGoalProgressItem, TodayOverview, TodaySummary,
};
pub use preferences::{
    CaptureDefaults, CaptureMetadata, DimensionOption, DimensionOptionInput, OperatingSettings,
    UpdateOperatingSettingsInput,
};
pub use project::{CreateProjectInput, Project};
pub use project_query::{ProjectDetail, ProjectOption, ProjectOverview};
pub use record_query::{
    ExpenseRecordSnapshot, IncomeRecordSnapshot, RecentRecordItem, RecordKind, TimeRecordSnapshot,
};
pub use review::{
    ProjectProgressItem, ReviewReport, ReviewTagMetric, ReviewWindow, ReviewWindowKind,
    TimeCategoryAllocation,
};
pub use review_note::{
    CreateReviewNoteInput, IgnoredContext, ReviewNote, ReviewNoteDraft, UpdateReviewNoteInput,
};
pub use snapshot::{MetricSnapshotSummary, ProjectMetricSnapshotSummary, SnapshotWindow};
pub use sync::{
    BackupRecord, BackupResult, BackupType, CloudSyncConfig, CreateCloudSyncConfigInput,
    RemoteBackupFile, RemoteDownloadResult, RemoteUploadResult, RestoreRecord, RestoreResult,
};
pub use tag::{CreateTagInput, Tag};
pub use time_record::{
    CreateTimeRecordInput, ProjectAllocation, TimeRecord, parse_rfc3339_utc, to_utc_string,
};
pub use user::UserProfile;
