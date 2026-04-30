use std::ffi::{CStr, CString, c_char};

use serde::Serialize;
use serde::de::DeserializeOwned;
use serde_json::Value;

use crate::error::LifeOsError;
use crate::models::{
    AiCaptureCommitInput, AiCommitInput, AiParseInput, AppendCaptureBufferItemInput,
    CapexCostInput, CaptureInboxStatus, CommitCaptureDraftEnvelopeInput,
    CreateAiServiceConfigInput, CreateCaptureBufferSessionInput, CreateCaptureInboxEntryInput,
    CreateCloudSyncConfigInput, CreateExpenseRecordInput, CreateIncomeRecordInput,
    CreateProjectInput, CreateReviewNoteInput, CreateTagInput, CreateTimeRecordInput,
    DimensionOptionInput, MonthlyCostBaselineInput, PrepareCaptureSessionInput,
    ProcessCaptureBufferSessionInput, ProcessCaptureInboxAndCommitInput, ProcessCaptureInboxInput,
    RecordKind, RecurringCostRuleInput, UpdateOperatingSettingsInput,
};
use crate::services::{
    AiService, BackupService, CaptureService, CostService, DataPackageExportInput, DemoDataService,
    ExportService, ProjectService, RecordService, ReviewNoteService, ReviewService, ShareService,
    ShareTargetInput, SnapshotService,
};

#[derive(Debug, Serialize)]
struct BridgeError {
    code: String,
    message: String,
}

#[derive(Debug, Serialize)]
struct BridgeResponse<T> {
    ok: bool,
    data: Option<T>,
    error: Option<BridgeError>,
}

#[derive(Debug)]
struct BridgeInvokeError {
    code: &'static str,
    message: String,
}

impl BridgeInvokeError {
    fn invalid_json(message: impl Into<String>) -> Self {
        Self {
            code: "invalid_json",
            message: message.into(),
        }
    }

    fn invalid_argument(message: impl Into<String>) -> Self {
        Self {
            code: "invalid_argument",
            message: message.into(),
        }
    }

    fn unsupported_method(method: &str) -> Self {
        Self {
            code: "unsupported_method",
            message: format!("unsupported bridge method: {method}"),
        }
    }

    fn from_core(error: LifeOsError) -> Self {
        let code = match error {
            LifeOsError::Sqlite(_) => "sqlite_error",
            LifeOsError::Io(_) => "io_error",
            LifeOsError::InvalidInput(_) => "invalid_input",
            LifeOsError::InvalidTimezone(_) => "invalid_timezone",
            LifeOsError::Timestamp(_) => "timestamp_error",
        };
        Self {
            code,
            message: error.to_string(),
        }
    }
}

#[derive(Debug, serde::Deserialize)]
struct EmptyPayload {}

#[derive(Debug, serde::Deserialize)]
struct UserScopedRequest {
    user_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct ExportSeedRequest {
    user_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct ExportDataPackageRequest {
    user_id: String,
    format: String,
    output_dir: String,
    title: String,
    module: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct PrepareShareTargetRequest {
    file_path: String,
    title: Option<String>,
    mime_type: Option<String>,
    text: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct BackupCreateRequest {
    user_id: String,
    backup_type: String,
}

#[derive(Debug, serde::Deserialize)]
struct BackupListRequest {
    user_id: String,
    limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct RestoreBackupRequest {
    user_id: String,
    backup_record_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct UploadBackupRequest {
    user_id: String,
    backup_record_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct UploadLatestBackupRequest {
    user_id: String,
    backup_type: String,
}

#[derive(Debug, serde::Deserialize)]
struct RemoteBackupsRequest {
    user_id: String,
    limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct RemoteBackupActionRequest {
    user_id: String,
    filename: String,
}

#[derive(Debug, serde::Deserialize)]
struct DownloadRemoteBackupRequest {
    user_id: String,
    filename: String,
    backup_type: String,
}

#[derive(Debug, serde::Deserialize)]
struct MonthlyBaselineRequest {
    user_id: String,
    month: String,
}

#[derive(Debug, serde::Deserialize)]
struct UpsertMonthlyBaselineRequest {
    user_id: String,
    input: MonthlyCostBaselineInput,
}

#[derive(Debug, serde::Deserialize)]
struct RecurringRuleRequest {
    user_id: String,
    input: RecurringCostRuleInput,
}

#[derive(Debug, serde::Deserialize)]
struct RecurringRuleMutationRequest {
    user_id: String,
    rule_id: String,
    input: RecurringCostRuleInput,
}

#[derive(Debug, serde::Deserialize)]
struct RecurringRuleDeleteRequest {
    user_id: String,
    rule_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct CapexRequest {
    user_id: String,
    input: CapexCostInput,
}

#[derive(Debug, serde::Deserialize)]
struct CapexMutationRequest {
    user_id: String,
    capex_id: String,
    input: CapexCostInput,
}

#[derive(Debug, serde::Deserialize)]
struct CapexDeleteRequest {
    user_id: String,
    capex_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct RateComparisonRequest {
    user_id: String,
    anchor_date: String,
    window_type: String,
}

#[derive(Debug, serde::Deserialize)]
struct GetTodayOverviewRequest {
    user_id: String,
    anchor_date: String,
    timezone: String,
}

#[derive(Debug, serde::Deserialize)]
struct RecentRecordsRequest {
    user_id: String,
    timezone: String,
    limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct RecordsForDateRequest {
    user_id: String,
    date: String,
    timezone: String,
    limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct ListProjectsRequest {
    user_id: String,
    status_filter: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct ProjectOptionsRequest {
    user_id: String,
    include_done: bool,
}

#[derive(Debug, serde::Deserialize)]
struct ProjectDetailRequest {
    user_id: String,
    project_id: String,
    timezone: String,
    recent_limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct SnapshotRequest {
    user_id: String,
    snapshot_date: String,
    window_type: String,
}

#[derive(Debug, serde::Deserialize)]
struct LatestSnapshotRequest {
    user_id: String,
    window_type: String,
}

#[derive(Debug, serde::Deserialize)]
struct ProjectSnapshotListRequest {
    user_id: String,
    metric_snapshot_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct ReviewReportRequest {
    user_id: String,
    kind: String,
    anchor_date: Option<String>,
    start_date: Option<String>,
    end_date: Option<String>,
    timezone: String,
}

#[derive(Debug, serde::Deserialize)]
struct TagDetailRecordsRequest {
    user_id: String,
    scope: String,
    tag_name: String,
    start_date: String,
    end_date: String,
    timezone: String,
    limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct ReviewNotesForDateRequest {
    user_id: String,
    occurred_on: String,
}

#[derive(Debug, serde::Deserialize)]
struct ReviewNotesForRangeRequest {
    user_id: String,
    start_date: String,
    end_date: String,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateTagRequest {
    tag_id: String,
    input: CreateTagInput,
}

#[derive(Debug, serde::Deserialize)]
struct DeleteTagRequest {
    user_id: String,
    tag_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct DimensionOptionsRequest {
    user_id: String,
    kind: String,
    include_inactive: Option<bool>,
}

#[derive(Debug, serde::Deserialize)]
struct SaveDimensionOptionRequest {
    user_id: String,
    kind: String,
    input: DimensionOptionInput,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateOperatingSettingsRequest {
    user_id: String,
    input: UpdateOperatingSettingsInput,
}

#[derive(Debug, serde::Deserialize)]
struct AiConfigMutationRequest {
    config_id: Option<String>,
    input: CreateAiServiceConfigInput,
}

#[derive(Debug, serde::Deserialize)]
struct DeleteAiConfigRequest {
    user_id: String,
    config_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct AiReviewChatRequest {
    user_id: String,
    question: String,
    kind: String,
    anchor_date: Option<String>,
    start_date: Option<String>,
    end_date: Option<String>,
    timezone: String,
}

#[derive(Debug, serde::Deserialize)]
struct CloudConfigMutationRequest {
    config_id: Option<String>,
    input: CreateCloudSyncConfigInput,
}

#[derive(Debug, serde::Deserialize)]
struct DeleteCloudConfigRequest {
    user_id: String,
    config_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct TimeSnapshotRequest {
    user_id: String,
    record_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateTimeRecordRequest {
    record_id: String,
    input: CreateTimeRecordInput,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateIncomeRecordRequest {
    record_id: String,
    input: CreateIncomeRecordInput,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateExpenseRecordRequest {
    record_id: String,
    input: CreateExpenseRecordInput,
}

#[derive(Debug, serde::Deserialize)]
struct DeleteRecordRequest {
    user_id: String,
    record_id: String,
    kind: String,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateProjectRecordRequest {
    project_id: String,
    input: CreateProjectInput,
}

#[derive(Debug, serde::Deserialize)]
struct UpdateProjectStateRequest {
    project_id: String,
    user_id: String,
    status_code: String,
    score: Option<i32>,
    note: Option<String>,
    ended_on: Option<String>,
}

#[derive(Debug, serde::Deserialize)]
struct DeleteProjectRequest {
    user_id: String,
    project_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct ListCaptureInboxRequest {
    user_id: String,
    status_filter: Option<String>,
    limit: Option<usize>,
}

#[derive(Debug, serde::Deserialize)]
struct GetCaptureInboxRequest {
    user_id: String,
    inbox_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct CaptureBufferSessionRequest {
    user_id: String,
    session_id: String,
}

#[derive(Debug, serde::Deserialize)]
struct DeleteCaptureBufferItemRequest {
    user_id: String,
    session_id: String,
    item_id: String,
}

fn success_response<T: Serialize>(data: T) -> String {
    serde_json::to_string(&BridgeResponse {
        ok: true,
        data: Some(data),
        error: None::<BridgeError>,
    })
    .unwrap_or_else(|error| {
        fallback_error_json(
            "serialize_error",
            format!("failed to serialize response: {error}"),
        )
    })
}

fn error_response(error: BridgeInvokeError) -> String {
    serde_json::to_string(&BridgeResponse::<Value> {
        ok: false,
        data: None,
        error: Some(BridgeError {
            code: error.code.to_string(),
            message: error.message,
        }),
    })
    .unwrap_or_else(|serialize_error| {
        fallback_error_json(
            "serialize_error",
            format!("failed to serialize error response: {serialize_error}"),
        )
    })
}

fn fallback_error_json(code: &str, message: String) -> String {
    format!(
        "{{\"ok\":false,\"data\":null,\"error\":{{\"code\":\"{code}\",\"message\":{message:?}}}}}"
    )
}

fn parse_payload<T: DeserializeOwned>(payload_json: &str) -> Result<T, BridgeInvokeError> {
    serde_json::from_str(payload_json).map_err(|error| {
        BridgeInvokeError::invalid_json(format!("failed to parse payload JSON: {error}"))
    })
}

fn invoke_inner(
    database_path: &str,
    method: &str,
    payload_json: &str,
) -> Result<String, BridgeInvokeError> {
    match method {
        "init_database" => {
            let _: EmptyPayload = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .init_database()
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "seed_demo_data" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = DemoDataService::new(database_path)
                .seed_demo_data(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "clear_demo_data" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = DemoDataService::new(database_path)
                .clear_demo_data(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_or_create_active_capture_buffer_session" => {
            let request: CreateCaptureBufferSessionInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .get_or_create_active_capture_buffer_session(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "append_capture_buffer_item" => {
            let request: AppendCaptureBufferItemInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .append_capture_buffer_item(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_capture_buffer_items" => {
            let request: CaptureBufferSessionRequest = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .list_capture_buffer_items(&request.user_id, &request.session_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_capture_buffer_item" => {
            let request: DeleteCaptureBufferItemRequest = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .delete_capture_buffer_item(&request.user_id, &request.session_id, &request.item_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "process_capture_buffer_session" => {
            let request: ProcessCaptureBufferSessionInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .process_capture_buffer_session(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "enqueue_capture_inbox" => {
            let request: CreateCaptureInboxEntryInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .enqueue_capture_inbox(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_capture_inbox" => {
            let request: ListCaptureInboxRequest = parse_payload(payload_json)?;
            let status_filter = request
                .status_filter
                .as_deref()
                .map(CaptureInboxStatus::from_str)
                .transpose()
                .map_err(BridgeInvokeError::from_core)?;
            let data = CaptureService::new(database_path)
                .list_capture_inbox(&request.user_id, status_filter, request.limit.unwrap_or(20))
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_capture_inbox" => {
            let request: GetCaptureInboxRequest = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .get_capture_inbox(&request.user_id, &request.inbox_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "process_capture_inbox" => {
            let request: ProcessCaptureInboxInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .process_capture_inbox(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "process_capture_inbox_and_commit" => {
            let request: ProcessCaptureInboxAndCommitInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .process_capture_inbox_and_commit(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "prepare_capture_session" => {
            let request: PrepareCaptureSessionInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .prepare_capture_session(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "commit_capture_draft_envelope" => {
            let request: CommitCaptureDraftEnvelopeInput = parse_payload(payload_json)?;
            let data = CaptureService::new(database_path)
                .commit_capture_draft_envelope(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_today_overview" => {
            let request: GetTodayOverviewRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_today_overview(&request.user_id, &request.anchor_date, &request.timezone)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_today_goal_progress" => {
            let request: GetTodayOverviewRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_today_goal_progress(&request.user_id, &request.anchor_date, &request.timezone)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_today_alerts" => {
            let request: GetTodayOverviewRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_today_alerts(&request.user_id, &request.anchor_date, &request.timezone)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_today_summary" => {
            let request: GetTodayOverviewRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_today_summary(&request.user_id, &request.anchor_date, &request.timezone)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_recent_records" => {
            let request: RecentRecordsRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_recent_records(
                    &request.user_id,
                    &request.timezone,
                    request.limit.unwrap_or(20),
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_records_for_date" => {
            let request: RecordsForDateRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_records_for_date(
                    &request.user_id,
                    &request.date,
                    &request.timezone,
                    request.limit.unwrap_or(50),
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_time_record" => {
            let request: CreateTimeRecordInput = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .create_time_record(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_income_record" => {
            let request: CreateIncomeRecordInput = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .create_income_record(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_expense_record" => {
            let request: CreateExpenseRecordInput = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .create_expense_record(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_project" => {
            let request: CreateProjectInput = parse_payload(payload_json)?;
            let data = ProjectService::new(database_path)
                .create_project(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_tag" => {
            let request: CreateTagInput = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .create_tag(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_tag" => {
            let request: UpdateTagRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .update_tag(&request.tag_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_tag" => {
            let request: DeleteTagRequest = parse_payload(payload_json)?;
            RecordService::new(database_path)
                .delete_tag(&request.user_id, &request.tag_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "list_tags" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .list_tags(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_capture_metadata" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_capture_metadata(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_dimension_options" => {
            let request: DimensionOptionsRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .list_dimension_options(
                    &request.user_id,
                    &request.kind,
                    request.include_inactive.unwrap_or(false),
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "save_dimension_option" => {
            let request: SaveDimensionOptionRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .save_dimension_option(&request.user_id, &request.kind, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_operating_settings" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_operating_settings(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "export_seed_data" => {
            let request: ExportSeedRequest = parse_payload(payload_json)?;
            let data = ExportService::new(database_path)
                .export_seed_data(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "export_data_package" => {
            let request: ExportDataPackageRequest = parse_payload(payload_json)?;
            let data = ExportService::new(database_path)
                .export_data_package(&DataPackageExportInput {
                    user_id: request.user_id,
                    format: request.format,
                    output_dir: request.output_dir,
                    title: request.title,
                    module: request.module,
                })
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "preview_data_package_export" => {
            let request: ExportSeedRequest = parse_payload(payload_json)?;
            let data = ExportService::new(database_path)
                .preview_data_package(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "prepare_share_target" => {
            let request: PrepareShareTargetRequest = parse_payload(payload_json)?;
            let data = ShareService::prepare_target(ShareTargetInput {
                file_path: request.file_path,
                title: request.title,
                mime_type: request.mime_type,
                text: request.text,
            })
            .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_operating_settings" => {
            let request: UpdateOperatingSettingsRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .update_operating_settings(&request.user_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_backup_records" => {
            let request: BackupListRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .list_backup_records(&request.user_id, request.limit.unwrap_or(20))
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_restore_records" => {
            let request: BackupListRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .list_restore_records(&request.user_id, request.limit.unwrap_or(20))
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_backup" => {
            let request: BackupCreateRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .create_backup(&request.user_id, &request.backup_type)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_latest_backup" => {
            let request: UploadLatestBackupRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .get_latest_backup(&request.user_id, &request.backup_type)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "restore_from_backup_record" => {
            let request: RestoreBackupRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .restore_from_backup_record(&request.user_id, &request.backup_record_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "upload_backup_to_cloud" => {
            let request: UploadBackupRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .upload_backup_to_cloud(&request.user_id, &request.backup_record_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "upload_latest_backup_to_cloud" => {
            let request: UploadLatestBackupRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .upload_latest_backup_to_cloud(&request.user_id, &request.backup_type)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_remote_backups" => {
            let request: RemoteBackupsRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .list_remote_backups(&request.user_id, request.limit.unwrap_or(20))
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "download_backup_from_cloud" => {
            let request: DownloadRemoteBackupRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .download_backup_from_cloud(
                    &request.user_id,
                    &request.filename,
                    &request.backup_type,
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "download_and_restore_from_cloud" => {
            let request: DownloadRemoteBackupRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .download_and_restore_from_cloud(
                    &request.user_id,
                    &request.filename,
                    &request.backup_type,
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_remote_backup" => {
            let request: RemoteBackupActionRequest = parse_payload(payload_json)?;
            BackupService::new(database_path)
                .delete_remote_backup(&request.user_id, &request.filename)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "list_ai_service_configs" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .list_service_configs(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_active_cloud_sync_config" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .get_active_cloud_sync_config(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_cloud_sync_configs" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .list_cloud_sync_configs(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_cloud_sync_config" => {
            let request: CloudConfigMutationRequest = parse_payload(payload_json)?;
            let data = BackupService::new(database_path)
                .create_cloud_sync_config(&request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_cloud_sync_config" => {
            let request: CloudConfigMutationRequest = parse_payload(payload_json)?;
            let config_id = request.config_id.ok_or_else(|| {
                BridgeInvokeError::invalid_argument(
                    "config_id is required for update_cloud_sync_config",
                )
            })?;
            let data = BackupService::new(database_path)
                .update_cloud_sync_config(&config_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_cloud_sync_config" => {
            let request: DeleteCloudConfigRequest = parse_payload(payload_json)?;
            BackupService::new(database_path)
                .delete_cloud_sync_config(&request.user_id, &request.config_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "get_active_ai_service_config" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .get_active_service_config(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_ai_service_config" => {
            let request: AiConfigMutationRequest = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .create_service_config(&request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_ai_service_config" => {
            let request: AiConfigMutationRequest = parse_payload(payload_json)?;
            let config_id = request.config_id.ok_or_else(|| {
                BridgeInvokeError::invalid_argument(
                    "config_id is required for update_ai_service_config",
                )
            })?;
            let data = AiService::new(database_path)
                .update_service_config(&config_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_ai_service_config" => {
            let request: DeleteAiConfigRequest = parse_payload(payload_json)?;
            AiService::new(database_path)
                .delete_service_config(&request.user_id, &request.config_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "test_ai_service_config" => {
            let request: AiConfigMutationRequest = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .test_service_config(&request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_monthly_baseline" => {
            let request: MonthlyBaselineRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .get_monthly_baseline(&request.user_id, &request.month)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "upsert_monthly_baseline" => {
            let request: UpsertMonthlyBaselineRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .upsert_monthly_baseline(&request.user_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_recurring_cost_rules" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .list_recurring_cost_rules(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_recurring_cost_rule" => {
            let request: RecurringRuleRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .create_recurring_cost_rule(&request.user_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_recurring_cost_rule" => {
            let request: RecurringRuleMutationRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .update_recurring_cost_rule(&request.user_id, &request.rule_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_recurring_cost_rule" => {
            let request: RecurringRuleDeleteRequest = parse_payload(payload_json)?;
            CostService::new(database_path)
                .delete_recurring_cost_rule(&request.user_id, &request.rule_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "list_capex_costs" => {
            let request: UserScopedRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .list_capex_costs(&request.user_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_capex_cost" => {
            let request: CapexRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .create_capex_cost(&request.user_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_capex_cost" => {
            let request: CapexMutationRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .update_capex_cost(&request.user_id, &request.capex_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_capex_cost" => {
            let request: CapexDeleteRequest = parse_payload(payload_json)?;
            CostService::new(database_path)
                .delete_capex_cost(&request.user_id, &request.capex_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "get_rate_comparison" => {
            let request: RateComparisonRequest = parse_payload(payload_json)?;
            let data = CostService::new(database_path)
                .get_rate_comparison(&request.user_id, &request.anchor_date, &request.window_type)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_projects" => {
            let request: ListProjectsRequest = parse_payload(payload_json)?;
            let data = ProjectService::new(database_path)
                .list_projects(&request.user_id, request.status_filter.as_deref())
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_project_options" => {
            let request: ProjectOptionsRequest = parse_payload(payload_json)?;
            let data = ProjectService::new(database_path)
                .get_project_options(&request.user_id, request.include_done)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "recompute_snapshot" => {
            let request: SnapshotRequest = parse_payload(payload_json)?;
            let window = crate::models::SnapshotWindow::parse(&request.window_type)
                .map_err(BridgeInvokeError::from_core)?;
            let data = SnapshotService::new(database_path)
                .recompute_snapshot(&request.user_id, &request.snapshot_date, window)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_snapshot" => {
            let request: SnapshotRequest = parse_payload(payload_json)?;
            let window = crate::models::SnapshotWindow::parse(&request.window_type)
                .map_err(BridgeInvokeError::from_core)?;
            let data = SnapshotService::new(database_path)
                .get_snapshot(&request.user_id, &request.snapshot_date, window)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_latest_snapshot" => {
            let request: LatestSnapshotRequest = parse_payload(payload_json)?;
            let window = crate::models::SnapshotWindow::parse(&request.window_type)
                .map_err(BridgeInvokeError::from_core)?;
            let data = SnapshotService::new(database_path)
                .get_latest_snapshot(&request.user_id, window)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_project_snapshots" => {
            let request: ProjectSnapshotListRequest = parse_payload(payload_json)?;
            let data = SnapshotService::new(database_path)
                .list_project_snapshots(&request.user_id, &request.metric_snapshot_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_project_record" => {
            let request: UpdateProjectRecordRequest = parse_payload(payload_json)?;
            let data = ProjectService::new(database_path)
                .update_project_record(&request.project_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_project_state" => {
            let request: UpdateProjectStateRequest = parse_payload(payload_json)?;
            let data = ProjectService::new(database_path)
                .update_project_state(
                    &request.project_id,
                    &request.user_id,
                    &request.status_code,
                    request.score,
                    request.note,
                    request.ended_on,
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_project" => {
            let request: DeleteProjectRequest = parse_payload(payload_json)?;
            ProjectService::new(database_path)
                .delete_project(&request.user_id, &request.project_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        "get_project_detail" => {
            let request: ProjectDetailRequest = parse_payload(payload_json)?;
            let data = ProjectService::new(database_path)
                .get_project_detail(
                    &request.user_id,
                    &request.project_id,
                    &request.timezone,
                    request.recent_limit.unwrap_or(20),
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_review_report" => {
            let request: ReviewReportRequest = parse_payload(payload_json)?;
            let service = ReviewService::new(database_path);
            let data = match request.kind.trim().to_lowercase().as_str() {
                "day" => service.get_daily_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for day review",
                        )
                    })?,
                    &request.timezone,
                ),
                "week" => service.get_weekly_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for week review",
                        )
                    })?,
                    &request.timezone,
                ),
                "month" => service.get_monthly_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for month review",
                        )
                    })?,
                    &request.timezone,
                ),
                "year" => service.get_yearly_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for year review",
                        )
                    })?,
                    &request.timezone,
                ),
                "range" => service.get_range_review(
                    &request.user_id,
                    request.start_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "start_date is required for range review",
                        )
                    })?,
                    request.end_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument("end_date is required for range review")
                    })?,
                    &request.timezone,
                ),
                other => return Err(BridgeInvokeError::unsupported_method(other)),
            }
            .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "chat_review" => {
            let request: AiReviewChatRequest = parse_payload(payload_json)?;
            let service = ReviewService::new(database_path);
            let report = match request.kind.trim().to_lowercase().as_str() {
                "day" => service.get_daily_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for day review",
                        )
                    })?,
                    &request.timezone,
                ),
                "week" => service.get_weekly_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for week review",
                        )
                    })?,
                    &request.timezone,
                ),
                "month" => service.get_monthly_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for month review",
                        )
                    })?,
                    &request.timezone,
                ),
                "year" => service.get_yearly_review(
                    &request.user_id,
                    request.anchor_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "anchor_date is required for year review",
                        )
                    })?,
                    &request.timezone,
                ),
                "range" => service.get_range_review(
                    &request.user_id,
                    request.start_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument(
                            "start_date is required for range review",
                        )
                    })?,
                    request.end_date.as_deref().ok_or_else(|| {
                        BridgeInvokeError::invalid_argument("end_date is required for range review")
                    })?,
                    &request.timezone,
                ),
                other => return Err(BridgeInvokeError::unsupported_method(other)),
            }
            .map_err(BridgeInvokeError::from_core)?;
            let context_json = serde_json::to_string(&report).map_err(|error| {
                BridgeInvokeError::invalid_argument(format!(
                    "failed to serialize review context: {error}"
                ))
            })?;
            let data = AiService::new(database_path)
                .chat_review(&request.user_id, &request.question, &context_json)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_tag_detail_records" => {
            let request: TagDetailRecordsRequest = parse_payload(payload_json)?;
            let data = ReviewService::new(database_path)
                .get_tag_detail_records(
                    &request.user_id,
                    &request.scope,
                    &request.tag_name,
                    &request.start_date,
                    &request.end_date,
                    &request.timezone,
                    request.limit.unwrap_or(50),
                )
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "create_review_note" => {
            let request: CreateReviewNoteInput = parse_payload(payload_json)?;
            let data = ReviewNoteService::new(database_path)
                .create_note(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_review_notes_for_date" => {
            let request: ReviewNotesForDateRequest = parse_payload(payload_json)?;
            let data = ReviewNoteService::new(database_path)
                .list_notes_for_date(&request.user_id, &request.occurred_on)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "list_review_notes_for_range" => {
            let request: ReviewNotesForRangeRequest = parse_payload(payload_json)?;
            let data = ReviewNoteService::new(database_path)
                .list_notes_for_range(&request.user_id, &request.start_date, &request.end_date)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "parse_ai_input" => {
            let request: AiParseInput = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .parse_input(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "parse_ai_input_v2" => {
            let request: AiParseInput = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .parse_input_v2(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "commit_ai_drafts" => {
            let request: AiCommitInput = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .commit_drafts(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "commit_ai_capture" => {
            let request: AiCaptureCommitInput = parse_payload(payload_json)?;
            let data = AiService::new(database_path)
                .commit_capture(&request)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_time_record_snapshot" => {
            let request: TimeSnapshotRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_time_record_snapshot(&request.user_id, &request.record_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_income_record_snapshot" => {
            let request: TimeSnapshotRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_income_record_snapshot(&request.user_id, &request.record_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "get_expense_record_snapshot" => {
            let request: TimeSnapshotRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .get_expense_record_snapshot(&request.user_id, &request.record_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_time_record" => {
            let request: UpdateTimeRecordRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .update_time_record(&request.record_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_income_record" => {
            let request: UpdateIncomeRecordRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .update_income_record(&request.record_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "update_expense_record" => {
            let request: UpdateExpenseRecordRequest = parse_payload(payload_json)?;
            let data = RecordService::new(database_path)
                .update_expense_record(&request.record_id, &request.input)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(data))
        }
        "delete_record" => {
            let request: DeleteRecordRequest = parse_payload(payload_json)?;
            let kind = match request.kind.trim().to_lowercase().as_str() {
                "time" => RecordKind::Time,
                "income" => RecordKind::Income,
                "expense" => RecordKind::Expense,
                other => {
                    return Err(BridgeInvokeError::invalid_argument(format!(
                        "unsupported record kind: {other}"
                    )));
                }
            };
            RecordService::new(database_path)
                .delete_record(kind, &request.user_id, &request.record_id)
                .map_err(BridgeInvokeError::from_core)?;
            Ok(success_response(true))
        }
        other => Err(BridgeInvokeError::unsupported_method(other)),
    }
}

pub fn invoke_json(database_path: &str, method: &str, payload_json: &str) -> String {
    match invoke_inner(database_path, method, payload_json) {
        Ok(response) => response,
        Err(error) => error_response(error),
    }
}

fn into_raw_string(value: String) -> *mut c_char {
    match CString::new(value) {
        Ok(string) => string.into_raw(),
        Err(error) => CString::new(fallback_error_json(
            "string_encode_error",
            format!("failed to encode bridge response: {error}"),
        ))
        .expect("fallback error json should not contain interior null bytes")
        .into_raw(),
    }
}

unsafe fn required_ptr_to_str(
    ptr: *const c_char,
    field_name: &str,
) -> Result<String, BridgeInvokeError> {
    if ptr.is_null() {
        return Err(BridgeInvokeError::invalid_argument(format!(
            "{field_name} pointer is null"
        )));
    }

    let value = unsafe { CStr::from_ptr(ptr) }.to_str().map_err(|error| {
        BridgeInvokeError::invalid_argument(format!("{field_name} is not valid UTF-8: {error}"))
    })?;

    Ok(value.to_string())
}

unsafe fn optional_ptr_to_str(
    ptr: *const c_char,
    default: &str,
) -> Result<String, BridgeInvokeError> {
    if ptr.is_null() {
        return Ok(default.to_string());
    }

    let value = unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map_err(|error| {
            BridgeInvokeError::invalid_argument(format!("payload is not valid UTF-8: {error}"))
        })?
        .to_string();

    Ok(value)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn life_os_invoke(
    database_path: *const c_char,
    method: *const c_char,
    payload_json: *const c_char,
) -> *mut c_char {
    let response = (|| -> Result<String, BridgeInvokeError> {
        let database_path = unsafe { required_ptr_to_str(database_path, "database_path") }?;
        let method = unsafe { required_ptr_to_str(method, "method") }?;
        let payload_json = unsafe { optional_ptr_to_str(payload_json, "{}") }?;
        Ok(invoke_json(&database_path, &method, &payload_json))
    })()
    .unwrap_or_else(error_response);

    into_raw_string(response)
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn life_os_string_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }
    unsafe {
        drop(CString::from_raw(ptr));
    }
}
