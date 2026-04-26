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

abstract class RustApi {
  Future<dynamic> invokeRaw({
    required String method,
    required Map<String, Object?> payload,
  });

  Future<UserProfileModel> initDatabase();

  Future<TodayOverview?> getTodayOverview({
    required String userId,
    required String anchorDate,
    required String timezone,
  });

  Future<TodayGoalProgressModel> getTodayGoalProgress({
    required String userId,
    required String anchorDate,
    required String timezone,
  });

  Future<TodayAlertsModel> getTodayAlerts({
    required String userId,
    required String anchorDate,
    required String timezone,
  });

  Future<TodaySummaryModel> getTodaySummary({
    required String userId,
    required String anchorDate,
    required String timezone,
  });

  Future<List<RecentRecordItem>> getRecentRecords({
    required String userId,
    required String timezone,
    required int limit,
  });

  Future<List<RecentRecordItem>> getRecordsForDate({
    required String userId,
    required String date,
    required String timezone,
    required int limit,
  });

  Future<List<ProjectOverview>> getProjects({
    required String userId,
    String? statusCode,
  });

  Future<List<ProjectOption>> getProjectOptions({
    required String userId,
    required bool includeDone,
  });

  Future<ProjectDetail?> getProjectDetail({
    required String userId,
    required String projectId,
    required String timezone,
  });

  Future<ReviewReport?> getReviewReport({
    required String userId,
    required ReviewWindow window,
    required String timezone,
  });

  Future<List<TagModel>> getTags({
    required String userId,
  });

  Future<MetricSnapshotSummaryModel?> getSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  });

  Future<MetricSnapshotSummaryModel?> getLatestSnapshot({
    required String userId,
    required String windowType,
  });

  Future<MetricSnapshotSummaryModel> recomputeSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  });

  Future<List<ProjectMetricSnapshotSummaryModel>> listProjectSnapshots({
    required String userId,
    required String metricSnapshotId,
  });

  Future<List<RecentRecordItem>> getTagDetailRecords({
    required String userId,
    required String scope,
    required String tagName,
    required String startDate,
    required String endDate,
    required String timezone,
    required int limit,
  });

  Future<List<BackupRecordModel>> listBackupRecords({
    required String userId,
    required int limit,
  });

  Future<List<RestoreRecordModel>> listRestoreRecords({
    required String userId,
    required int limit,
  });

  Future<BackupResultModel?> getLatestBackup({
    required String userId,
    required String backupType,
  });

  Future<BackupResultModel> createBackup({
    required String userId,
    required String backupType,
  });

  Future<RestoreResultModel> restoreFromBackupRecord({
    required String userId,
    required String backupRecordId,
  });

  Future<RemoteUploadResultModel> uploadBackupToCloud({
    required String userId,
    required String backupRecordId,
  });

  Future<RemoteUploadResultModel> uploadLatestBackupToCloud({
    required String userId,
    required String backupType,
  });

  Future<List<RemoteBackupFileModel>> listRemoteBackups({
    required String userId,
    required int limit,
  });

  Future<BackupResultModel> downloadBackupFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  });

  Future<RestoreResultModel> downloadAndRestoreFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  });

  Future<void> deleteRemoteBackup({
    required String userId,
    required String filename,
  });

  Future<CloudSyncConfigModel?> getActiveCloudSyncConfig({
    required String userId,
  });

  Future<List<CloudSyncConfigModel>> listCloudSyncConfigs({
    required String userId,
  });

  Future<AiServiceConfigModel?> getActiveAiServiceConfig({
    required String userId,
  });

  Future<List<AiServiceConfigModel>> listAiServiceConfigs({
    required String userId,
  });

  Future<MonthlyCostBaselineModel> getMonthlyBaseline({
    required String userId,
    required String month,
  });

  Future<List<RecurringCostRuleModel>> listRecurringCostRules({
    required String userId,
  });

  Future<List<CapexCostModel>> listCapexCosts({
    required String userId,
  });

  Future<RateComparisonSummaryModel> getRateComparison({
    required String userId,
    required String anchorDate,
    required String windowType,
  });

  Future<void> createTimeRecord(Map<String, Object?> payload);

  Future<void> createIncomeRecord(Map<String, Object?> payload);

  Future<void> createExpenseRecord(Map<String, Object?> payload);

  Future<void> createLearningRecord(Map<String, Object?> payload);

  Future<void> createProject(Map<String, Object?> payload);

  Future<Map<String, Object?>?> parseAiCapture({
    required String userId,
    required String rawInput,
    required String parserMode,
  });

  Future<AiCommitResultModel> commitAiDrafts({
    required String userId,
    required String? requestId,
    required String? contextDate,
    required List<AiParseDraftModel> drafts,
  });
}

class UnimplementedRustApi implements RustApi {
  const UnimplementedRustApi();

  Never _notReady(String method) {
    throw UnimplementedError('$method is not wired to Rust FFI yet.');
  }

  @override
  Future<dynamic> invokeRaw({
    required String method,
    required Map<String, Object?> payload,
  }) async {
    _notReady(method);
  }

  @override
  Future<UserProfileModel> initDatabase() async {
    _notReady('initDatabase');
  }

  @override
  Future<void> createExpenseRecord(Map<String, Object?> payload) async {
    _notReady('createExpenseRecord');
  }

  @override
  Future<void> createIncomeRecord(Map<String, Object?> payload) async {
    _notReady('createIncomeRecord');
  }

  @override
  Future<void> createLearningRecord(Map<String, Object?> payload) async {
    _notReady('createLearningRecord');
  }

  @override
  Future<void> createProject(Map<String, Object?> payload) async {
    _notReady('createProject');
  }

  @override
  Future<void> createTimeRecord(Map<String, Object?> payload) async {
    _notReady('createTimeRecord');
  }

  @override
  Future<ProjectDetail?> getProjectDetail({
    required String userId,
    required String projectId,
    required String timezone,
  }) async {
    _notReady('getProjectDetail');
  }

  @override
  Future<List<ProjectOverview>> getProjects({
    required String userId,
    String? statusCode,
  }) async {
    _notReady('getProjects');
  }

  @override
  Future<List<ProjectOption>> getProjectOptions({
    required String userId,
    required bool includeDone,
  }) async {
    _notReady('getProjectOptions');
  }

  @override
  Future<List<RecentRecordItem>> getRecentRecords({
    required String userId,
    required String timezone,
    required int limit,
  }) async {
    _notReady('getRecentRecords');
  }

  @override
  Future<List<RecentRecordItem>> getRecordsForDate({
    required String userId,
    required String date,
    required String timezone,
    required int limit,
  }) async {
    _notReady('getRecordsForDate');
  }

  @override
  Future<List<TagModel>> getTags({
    required String userId,
  }) async {
    _notReady('getTags');
  }

  @override
  Future<MetricSnapshotSummaryModel?> getSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  }) async {
    _notReady('getSnapshot');
  }

  @override
  Future<MetricSnapshotSummaryModel?> getLatestSnapshot({
    required String userId,
    required String windowType,
  }) async {
    _notReady('getLatestSnapshot');
  }

  @override
  Future<MetricSnapshotSummaryModel> recomputeSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  }) async {
    _notReady('recomputeSnapshot');
  }

  @override
  Future<List<ProjectMetricSnapshotSummaryModel>> listProjectSnapshots({
    required String userId,
    required String metricSnapshotId,
  }) async {
    _notReady('listProjectSnapshots');
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
    _notReady('getTagDetailRecords');
  }

  @override
  Future<List<BackupRecordModel>> listBackupRecords({
    required String userId,
    required int limit,
  }) async {
    _notReady('listBackupRecords');
  }

  @override
  Future<List<RestoreRecordModel>> listRestoreRecords({
    required String userId,
    required int limit,
  }) async {
    _notReady('listRestoreRecords');
  }

  @override
  Future<BackupResultModel?> getLatestBackup({
    required String userId,
    required String backupType,
  }) async {
    _notReady('getLatestBackup');
  }

  @override
  Future<BackupResultModel> createBackup({
    required String userId,
    required String backupType,
  }) async {
    _notReady('createBackup');
  }

  @override
  Future<RestoreResultModel> restoreFromBackupRecord({
    required String userId,
    required String backupRecordId,
  }) async {
    _notReady('restoreFromBackupRecord');
  }

  @override
  Future<RemoteUploadResultModel> uploadBackupToCloud({
    required String userId,
    required String backupRecordId,
  }) async {
    _notReady('uploadBackupToCloud');
  }

  @override
  Future<RemoteUploadResultModel> uploadLatestBackupToCloud({
    required String userId,
    required String backupType,
  }) async {
    _notReady('uploadLatestBackupToCloud');
  }

  @override
  Future<List<RemoteBackupFileModel>> listRemoteBackups({
    required String userId,
    required int limit,
  }) async {
    _notReady('listRemoteBackups');
  }

  @override
  Future<BackupResultModel> downloadBackupFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  }) async {
    _notReady('downloadBackupFromCloud');
  }

  @override
  Future<RestoreResultModel> downloadAndRestoreFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  }) async {
    _notReady('downloadAndRestoreFromCloud');
  }

  @override
  Future<void> deleteRemoteBackup({
    required String userId,
    required String filename,
  }) async {
    _notReady('deleteRemoteBackup');
  }

  @override
  Future<CloudSyncConfigModel?> getActiveCloudSyncConfig({
    required String userId,
  }) async {
    _notReady('getActiveCloudSyncConfig');
  }

  @override
  Future<List<CloudSyncConfigModel>> listCloudSyncConfigs({
    required String userId,
  }) async {
    _notReady('listCloudSyncConfigs');
  }

  @override
  Future<AiServiceConfigModel?> getActiveAiServiceConfig({
    required String userId,
  }) async {
    _notReady('getActiveAiServiceConfig');
  }

  @override
  Future<List<AiServiceConfigModel>> listAiServiceConfigs({
    required String userId,
  }) async {
    _notReady('listAiServiceConfigs');
  }

  @override
  Future<MonthlyCostBaselineModel> getMonthlyBaseline({
    required String userId,
    required String month,
  }) async {
    _notReady('getMonthlyBaseline');
  }

  @override
  Future<List<RecurringCostRuleModel>> listRecurringCostRules({
    required String userId,
  }) async {
    _notReady('listRecurringCostRules');
  }

  @override
  Future<List<CapexCostModel>> listCapexCosts({
    required String userId,
  }) async {
    _notReady('listCapexCosts');
  }

  @override
  Future<RateComparisonSummaryModel> getRateComparison({
    required String userId,
    required String anchorDate,
    required String windowType,
  }) async {
    _notReady('getRateComparison');
  }

  @override
  Future<TodayOverview?> getTodayOverview({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    _notReady('getTodayOverview');
  }

  @override
  Future<TodayGoalProgressModel> getTodayGoalProgress({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    _notReady('getTodayGoalProgress');
  }

  @override
  Future<TodayAlertsModel> getTodayAlerts({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    _notReady('getTodayAlerts');
  }

  @override
  Future<TodaySummaryModel> getTodaySummary({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    _notReady('getTodaySummary');
  }

  @override
  Future<ReviewReport?> getReviewReport({
    required String userId,
    required ReviewWindow window,
    required String timezone,
  }) async {
    _notReady('getReviewReport');
  }

  @override
  Future<Map<String, Object?>?> parseAiCapture({
    required String userId,
    required String rawInput,
    required String parserMode,
  }) async {
    _notReady('parseAiCapture');
  }

  @override
  Future<AiCommitResultModel> commitAiDrafts({
    required String userId,
    required String? requestId,
    required String? contextDate,
    required List<AiParseDraftModel> drafts,
  }) async {
    _notReady('commitAiDrafts');
  }
}
