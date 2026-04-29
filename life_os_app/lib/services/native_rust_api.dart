import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import '../models/ai_models.dart';
import '../models/cost_models.dart';
import '../models/overview_models.dart';
import '../models/project_models.dart';
import '../models/record_models.dart';
import '../models/review_models.dart';
import '../models/snapshot_models.dart';
import '../models/sync_models.dart';
import '../models/tag_models.dart';
import '../models/user_models.dart';
import 'rust_api.dart';

typedef _NativeInvoke = Pointer<Utf8> Function(
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);
typedef _DartInvoke = Pointer<Utf8> Function(
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Utf8>,
);

typedef _NativeStringFree = Void Function(Pointer<Utf8>);
typedef _DartStringFree = void Function(Pointer<Utf8>);

class NativeRustApi implements RustApi {
  NativeRustApi._({
    required this.databasePath,
    required DynamicLibrary library,
  }) {
    library.lookupFunction<_NativeInvoke, _DartInvoke>('life_os_invoke');
    library.lookupFunction<_NativeStringFree, _DartStringFree>(
        'life_os_string_free');
  }

  final String databasePath;

  static RustApi createOrFallback({
    required String databasePath,
  }) {
    try {
      return NativeRustApi._(
        databasePath: databasePath,
        library: _openLibrary(),
      );
    } catch (_) {
      return const UnimplementedRustApi();
    }
  }

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS) {
      return DynamicLibrary.process();
    }
    if (Platform.isMacOS) {
      return DynamicLibrary.open('liblife_os_core.dylib');
    }
    if (Platform.isAndroid || Platform.isLinux) {
      return DynamicLibrary.open('liblife_os_core.so');
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('life_os_core.dll');
    }
    throw UnsupportedError('Unsupported platform for native Rust bridge.');
  }

  static dynamic _callWithLibrary({
    required String databasePath,
    required String method,
    required Map<String, Object?> payload,
  }) {
    final library = _openLibrary();
    final invoke =
        library.lookupFunction<_NativeInvoke, _DartInvoke>('life_os_invoke');
    final stringFree =
        library.lookupFunction<_NativeStringFree, _DartStringFree>(
            'life_os_string_free');

    final databasePathPtr = databasePath.toNativeUtf8();
    final methodPtr = method.toNativeUtf8();
    final payloadPtr = jsonEncode(payload).toNativeUtf8();

    final resultPtr = invoke(databasePathPtr, methodPtr, payloadPtr);
    malloc.free(databasePathPtr);
    malloc.free(methodPtr);
    malloc.free(payloadPtr);

    final resultJson = resultPtr.toDartString();
    stringFree(resultPtr);

    final envelope = (jsonDecode(resultJson) as Map).cast<String, dynamic>();
    final ok = envelope['ok'] == true;
    if (!ok) {
      final error =
          ((envelope['error'] as Map?) ?? const {}).cast<String, dynamic>();
      throw StateError(
          error['message'] as String? ?? 'Rust bridge call failed.');
    }
    return envelope['data'];
  }

  dynamic _call(String method, Map<String, Object?> payload) {
    return _callWithLibrary(
      databasePath: databasePath,
      method: method,
      payload: payload,
    );
  }

  @override
  Future<dynamic> invokeRaw({
    required String method,
    required Map<String, Object?> payload,
  }) async {
    final data = await Isolate.run(
      () => _callWithLibrary(
        databasePath: databasePath,
        method: method,
        payload: payload,
      ),
    );
    if (data == null) {
      return null;
    }
    if (data is Map) {
      return data.cast<String, dynamic>();
    }
    return data;
  }

  List<T> _parseList<T>(
    dynamic data,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    final list = (data as List? ?? const []);
    return list
        .whereType<Map>()
        .map((item) => fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<UserProfileModel> initDatabase() async {
    final data = _call('init_database', const {});
    return UserProfileModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> createExpenseRecord(Map<String, Object?> payload) async {
    _call('create_expense_record', payload);
  }

  @override
  Future<void> createIncomeRecord(Map<String, Object?> payload) async {
    _call('create_income_record', payload);
  }

  @override
  Future<void> createLearningRecord(Map<String, Object?> payload) async {
    _call('create_learning_record', payload);
  }

  @override
  Future<void> createProject(Map<String, Object?> payload) async {
    _call('create_project', payload);
  }

  @override
  Future<void> createTimeRecord(Map<String, Object?> payload) async {
    _call('create_time_record', payload);
  }

  @override
  Future<ProjectDetail?> getProjectDetail({
    required String userId,
    required String projectId,
    required String timezone,
  }) async {
    final data = _call('get_project_detail', {
      'user_id': userId,
      'project_id': projectId,
      'timezone': timezone,
      'recent_limit': 20,
    });
    if (data == null) {
      return null;
    }
    return ProjectDetail.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<ProjectOverview>> getProjects({
    required String userId,
    String? statusCode,
  }) async {
    final data = _call('list_projects', {
      'user_id': userId,
      'status_filter': statusCode,
    });
    return _parseList(data, ProjectOverview.fromJson);
  }

  @override
  Future<List<ProjectOption>> getProjectOptions({
    required String userId,
    required bool includeDone,
  }) async {
    final data = _call('get_project_options', {
      'user_id': userId,
      'include_done': includeDone,
    });
    return _parseList(data, ProjectOption.fromJson);
  }

  @override
  Future<List<RecentRecordItem>> getRecentRecords({
    required String userId,
    required String timezone,
    required int limit,
  }) async {
    final data = _call('get_recent_records', {
      'user_id': userId,
      'timezone': timezone,
      'limit': limit,
    });
    return _parseList(data, RecentRecordItem.fromJson);
  }

  @override
  Future<List<RecentRecordItem>> getRecordsForDate({
    required String userId,
    required String date,
    required String timezone,
    required int limit,
  }) async {
    final data = _call('get_records_for_date', {
      'user_id': userId,
      'date': date,
      'timezone': timezone,
      'limit': limit,
    });
    return _parseList(data, RecentRecordItem.fromJson);
  }

  @override
  Future<List<TagModel>> getTags({
    required String userId,
  }) async {
    final data = _call('list_tags', {
      'user_id': userId,
    });
    return _parseList(data, TagModel.fromJson);
  }

  @override
  Future<MetricSnapshotSummaryModel?> getSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  }) async {
    final data = _call('get_snapshot', {
      'user_id': userId,
      'snapshot_date': snapshotDate,
      'window_type': windowType,
    });
    if (data == null) return null;
    return MetricSnapshotSummaryModel.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  @override
  Future<MetricSnapshotSummaryModel?> getLatestSnapshot({
    required String userId,
    required String windowType,
  }) async {
    final data = _call('get_latest_snapshot', {
      'user_id': userId,
      'window_type': windowType,
    });
    if (data == null) return null;
    return MetricSnapshotSummaryModel.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  @override
  Future<MetricSnapshotSummaryModel> recomputeSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  }) async {
    final data = _call('recompute_snapshot', {
      'user_id': userId,
      'snapshot_date': snapshotDate,
      'window_type': windowType,
    });
    return MetricSnapshotSummaryModel.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<ProjectMetricSnapshotSummaryModel>> listProjectSnapshots({
    required String userId,
    required String metricSnapshotId,
  }) async {
    final data = _call('list_project_snapshots', {
      'user_id': userId,
      'metric_snapshot_id': metricSnapshotId,
    });
    return _parseList(data, ProjectMetricSnapshotSummaryModel.fromJson);
  }

  @override
  Future<List<RecentRecordItem>> getTagDetailRecords({
    required String userId,
    required String scope,
    required String tagName,
    required String startDate,
    required String endDate,
    required String timezone,
    required int limit,
  }) async {
    final data = _call('get_tag_detail_records', {
      'user_id': userId,
      'scope': scope,
      'tag_name': tagName,
      'start_date': startDate,
      'end_date': endDate,
      'timezone': timezone,
      'limit': limit,
    });
    return _parseList(data, RecentRecordItem.fromJson);
  }

  @override
  Future<List<BackupRecordModel>> listBackupRecords({
    required String userId,
    required int limit,
  }) async {
    final data = _call('list_backup_records', {
      'user_id': userId,
      'limit': limit,
    });
    return _parseList(data, BackupRecordModel.fromJson);
  }

  @override
  Future<List<RestoreRecordModel>> listRestoreRecords({
    required String userId,
    required int limit,
  }) async {
    final data = _call('list_restore_records', {
      'user_id': userId,
      'limit': limit,
    });
    return _parseList(data, RestoreRecordModel.fromJson);
  }

  @override
  Future<BackupResultModel?> getLatestBackup({
    required String userId,
    required String backupType,
  }) async {
    final data = _call('get_latest_backup', {
      'user_id': userId,
      'backup_type': backupType,
    });
    if (data == null) return null;
    return BackupResultModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<BackupResultModel> createBackup({
    required String userId,
    required String backupType,
  }) async {
    final data = _call('create_backup', {
      'user_id': userId,
      'backup_type': backupType,
    });
    return BackupResultModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<RestoreResultModel> restoreFromBackupRecord({
    required String userId,
    required String backupRecordId,
  }) async {
    final data = _call('restore_from_backup_record', {
      'user_id': userId,
      'backup_record_id': backupRecordId,
    });
    return RestoreResultModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<RemoteUploadResultModel> uploadBackupToCloud({
    required String userId,
    required String backupRecordId,
  }) async {
    final data = _call('upload_backup_to_cloud', {
      'user_id': userId,
      'backup_record_id': backupRecordId,
    });
    return RemoteUploadResultModel.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  @override
  Future<RemoteUploadResultModel> uploadLatestBackupToCloud({
    required String userId,
    required String backupType,
  }) async {
    final data = _call('upload_latest_backup_to_cloud', {
      'user_id': userId,
      'backup_type': backupType,
    });
    return RemoteUploadResultModel.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<RemoteBackupFileModel>> listRemoteBackups({
    required String userId,
    required int limit,
  }) async {
    final data = _call('list_remote_backups', {
      'user_id': userId,
      'limit': limit,
    });
    return _parseList(data, RemoteBackupFileModel.fromJson);
  }

  @override
  Future<BackupResultModel> downloadBackupFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  }) async {
    final data = _call('download_backup_from_cloud', {
      'user_id': userId,
      'filename': filename,
      'backup_type': backupType,
    });
    return BackupResultModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<RestoreResultModel> downloadAndRestoreFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  }) async {
    final data = _call('download_and_restore_from_cloud', {
      'user_id': userId,
      'filename': filename,
      'backup_type': backupType,
    });
    return RestoreResultModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<void> deleteRemoteBackup({
    required String userId,
    required String filename,
  }) async {
    _call('delete_remote_backup', {
      'user_id': userId,
      'filename': filename,
    });
  }

  @override
  Future<CloudSyncConfigModel?> getActiveCloudSyncConfig({
    required String userId,
  }) async {
    final data = _call('get_active_cloud_sync_config', {
      'user_id': userId,
    });
    if (data == null) {
      return null;
    }
    return CloudSyncConfigModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<CloudSyncConfigModel>> listCloudSyncConfigs({
    required String userId,
  }) async {
    final data = _call('list_cloud_sync_configs', {
      'user_id': userId,
    });
    return _parseList(data, CloudSyncConfigModel.fromJson);
  }

  @override
  Future<AiServiceConfigModel?> getActiveAiServiceConfig({
    required String userId,
  }) async {
    final data = _call('get_active_ai_service_config', {
      'user_id': userId,
    });
    if (data == null) {
      return null;
    }
    return AiServiceConfigModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<List<AiServiceConfigModel>> listAiServiceConfigs({
    required String userId,
  }) async {
    final data = _call('list_ai_service_configs', {
      'user_id': userId,
    });
    return _parseList(data, AiServiceConfigModel.fromJson);
  }

  @override
  Future<MonthlyCostBaselineModel> getMonthlyBaseline({
    required String userId,
    required String month,
  }) async {
    final data = _call('get_monthly_baseline', {
      'user_id': userId,
      'month': month,
    });
    return MonthlyCostBaselineModel.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<List<RecurringCostRuleModel>> listRecurringCostRules({
    required String userId,
  }) async {
    final data = _call('list_recurring_cost_rules', {
      'user_id': userId,
    });
    return _parseList(data, RecurringCostRuleModel.fromJson);
  }

  @override
  Future<List<CapexCostModel>> listCapexCosts({
    required String userId,
  }) async {
    final data = _call('list_capex_costs', {
      'user_id': userId,
    });
    return _parseList(data, CapexCostModel.fromJson);
  }

  @override
  Future<RateComparisonSummaryModel> getRateComparison({
    required String userId,
    required String anchorDate,
    required String windowType,
  }) async {
    final data = _call('get_rate_comparison', {
      'user_id': userId,
      'anchor_date': anchorDate,
      'window_type': windowType,
    });
    return RateComparisonSummaryModel.fromJson(
      (data as Map).cast<String, dynamic>(),
    );
  }

  @override
  Future<TodayOverview?> getTodayOverview({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    final data = _call('get_today_overview', {
      'user_id': userId,
      'anchor_date': anchorDate,
      'timezone': timezone,
    });
    if (data == null) {
      return null;
    }
    return TodayOverview.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<TodayGoalProgressModel> getTodayGoalProgress({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    final data = _call('get_today_goal_progress', {
      'user_id': userId,
      'anchor_date': anchorDate,
      'timezone': timezone,
    });
    return TodayGoalProgressModel.fromJson(
        (data as Map).cast<String, dynamic>());
  }

  @override
  Future<TodayAlertsModel> getTodayAlerts({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    final data = _call('get_today_alerts', {
      'user_id': userId,
      'anchor_date': anchorDate,
      'timezone': timezone,
    });
    return TodayAlertsModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<TodaySummaryModel> getTodaySummary({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    final data = _call('get_today_summary', {
      'user_id': userId,
      'anchor_date': anchorDate,
      'timezone': timezone,
    });
    return TodaySummaryModel.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<ReviewReport?> getReviewReport({
    required String userId,
    required ReviewWindow window,
    required String timezone,
  }) async {
    final payload = <String, Object?>{
      'user_id': userId,
      'kind': window.kind.name,
      'anchor_date': window.startDate,
      'start_date': window.startDate,
      'end_date': window.endDate,
      'timezone': timezone,
    };
    final data = _call('get_review_report', payload);
    if (data == null) {
      return null;
    }
    return ReviewReport.fromJson((data as Map).cast<String, dynamic>());
  }

  @override
  Future<Map<String, Object?>?> parseAiCapture({
    required String userId,
    required String rawInput,
    required String parserMode,
  }) async {
    final data = _call('parse_ai_input_v2', {
      'user_id': userId,
      'raw_text': rawInput,
    });
    if (data == null) {
      return null;
    }
    return (data as Map).cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>?> exportSeedData({
    required String userId,
  }) async {
    final data = _call('export_seed_data', {
      'user_id': userId,
    });
    if (data == null) {
      return null;
    }
    return (data as Map).cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>?> exportDataPackage({
    required String userId,
    required String format,
    required String outputDirectoryPath,
    required String title,
    required String module,
  }) async {
    final data = _call('export_data_package', {
      'user_id': userId,
      'format': format,
      'output_dir': outputDirectoryPath,
      'title': title,
      'module': module,
    });
    if (data == null) {
      return null;
    }
    return (data as Map).cast<String, Object?>();
  }

  @override
  Future<Map<String, Object?>?> previewDataPackageExport({
    required String userId,
  }) async {
    final data = _call('preview_data_package_export', {
      'user_id': userId,
    });
    if (data == null) {
      return null;
    }
    return (data as Map).cast<String, Object?>();
  }

  @override
  Future<AiCommitResultModel> commitAiDrafts({
    required String userId,
    required String? requestId,
    required String? contextDate,
    required List<AiParseDraftModel> drafts,
  }) async {
    final data = _call('commit_ai_drafts', {
      'user_id': userId,
      'request_id': requestId,
      'context_date': contextDate,
      'drafts': drafts.map((item) => item.toJson()).toList(),
      'options': {
        'source': 'external',
        'auto_create_tags': false,
        'strict_reference_resolution': false,
      },
    });
    return AiCommitResultModel.fromJson((data as Map).cast<String, dynamic>());
  }
}
