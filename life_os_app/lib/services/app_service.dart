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

class AppService {
  AppService({
    required this.api,
  });

  final RustApi api;

  Future<dynamic> invokeRaw({
    required String method,
    required Map<String, Object?> payload,
  }) {
    return api.invokeRaw(method: method, payload: payload);
  }

  Future<UserProfileModel> initDatabase() {
    return api.initDatabase();
  }

  Future<Map<String, Object?>?> parseAiCapture({
    required String userId,
    required String rawInput,
    required String parserMode,
  }) {
    return api.parseAiCapture(
      userId: userId,
      rawInput: rawInput,
      parserMode: parserMode,
    );
  }

  Future<Map<String, Object?>?> exportSeedData({
    required String userId,
  }) {
    return api.exportSeedData(userId: userId);
  }

  Future<Map<String, Object?>?> exportDataPackage({
    required String userId,
    required String format,
    required String outputDirectoryPath,
    required String title,
    required String module,
  }) {
    return api.exportDataPackage(
      userId: userId,
      format: format,
      outputDirectoryPath: outputDirectoryPath,
      title: title,
      module: module,
    );
  }

  Future<Map<String, Object?>?> previewDataPackageExport({
    required String userId,
  }) {
    return api.previewDataPackageExport(userId: userId);
  }

  Future<TodayOverview?> getTodayOverview({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) {
    return api.getTodayOverview(
      userId: userId,
      anchorDate: anchorDate,
      timezone: timezone,
    );
  }

  Future<TodayGoalProgressModel> getTodayGoalProgress({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) {
    return api.getTodayGoalProgress(
      userId: userId,
      anchorDate: anchorDate,
      timezone: timezone,
    );
  }

  Future<TodayAlertsModel> getTodayAlerts({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) {
    return api.getTodayAlerts(
      userId: userId,
      anchorDate: anchorDate,
      timezone: timezone,
    );
  }

  Future<TodaySummaryModel> getTodaySummary({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) {
    return api.getTodaySummary(
      userId: userId,
      anchorDate: anchorDate,
      timezone: timezone,
    );
  }

  Future<List<RecentRecordItem>> getRecentRecords({
    required String userId,
    required String timezone,
    int limit = 20,
  }) {
    return api.getRecentRecords(
      userId: userId,
      timezone: timezone,
      limit: limit,
    );
  }

  Future<List<RecentRecordItem>> getRecordsForDate({
    required String userId,
    required String date,
    required String timezone,
    int limit = 50,
  }) {
    return api.getRecordsForDate(
      userId: userId,
      date: date,
      timezone: timezone,
      limit: limit,
    );
  }

  Future<List<ProjectOverview>> getProjects({
    required String userId,
    String? statusCode,
  }) {
    return api.getProjects(userId: userId, statusCode: statusCode);
  }

  Future<List<ProjectOption>> getProjectOptions({
    required String userId,
    bool includeDone = false,
  }) {
    return api.getProjectOptions(userId: userId, includeDone: includeDone);
  }

  Future<ProjectDetail?> getProjectDetail({
    required String userId,
    required String projectId,
    required String timezone,
  }) {
    return api.getProjectDetail(
      userId: userId,
      projectId: projectId,
      timezone: timezone,
    );
  }

  Future<ReviewReport?> getReviewReport({
    required String userId,
    required ReviewWindow window,
    required String timezone,
  }) {
    return api.getReviewReport(
      userId: userId,
      window: window,
      timezone: timezone,
    );
  }

  Future<List<TagModel>> getTags({
    required String userId,
  }) {
    return api.getTags(userId: userId);
  }

  Future<MetricSnapshotSummaryModel?> getSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  }) {
    return api.getSnapshot(
      userId: userId,
      snapshotDate: snapshotDate,
      windowType: windowType,
    );
  }

  Future<MetricSnapshotSummaryModel?> getLatestSnapshot({
    required String userId,
    required String windowType,
  }) {
    return api.getLatestSnapshot(userId: userId, windowType: windowType);
  }

  Future<MetricSnapshotSummaryModel> recomputeSnapshot({
    required String userId,
    required String snapshotDate,
    required String windowType,
  }) {
    return api.recomputeSnapshot(
      userId: userId,
      snapshotDate: snapshotDate,
      windowType: windowType,
    );
  }

  Future<List<ProjectMetricSnapshotSummaryModel>> listProjectSnapshots({
    required String userId,
    required String metricSnapshotId,
  }) {
    return api.listProjectSnapshots(
      userId: userId,
      metricSnapshotId: metricSnapshotId,
    );
  }

  Future<List<RecentRecordItem>> getTagDetailRecords({
    required String userId,
    required String scope,
    required String tagName,
    required String startDate,
    required String endDate,
    required String timezone,
    int limit = 50,
  }) {
    return api.getTagDetailRecords(
      userId: userId,
      scope: scope,
      tagName: tagName,
      startDate: startDate,
      endDate: endDate,
      timezone: timezone,
      limit: limit,
    );
  }

  Future<List<BackupRecordModel>> listBackupRecords({
    required String userId,
    int limit = 20,
  }) {
    return api.listBackupRecords(userId: userId, limit: limit);
  }

  Future<List<RestoreRecordModel>> listRestoreRecords({
    required String userId,
    int limit = 20,
  }) {
    return api.listRestoreRecords(userId: userId, limit: limit);
  }

  Future<BackupResultModel?> getLatestBackup({
    required String userId,
    required String backupType,
  }) {
    return api.getLatestBackup(userId: userId, backupType: backupType);
  }

  Future<BackupResultModel> createBackup({
    required String userId,
    required String backupType,
  }) {
    return api.createBackup(userId: userId, backupType: backupType);
  }

  Future<RestoreResultModel> restoreFromBackupRecord({
    required String userId,
    required String backupRecordId,
  }) {
    return api.restoreFromBackupRecord(
      userId: userId,
      backupRecordId: backupRecordId,
    );
  }

  Future<RemoteUploadResultModel> uploadBackupToCloud({
    required String userId,
    required String backupRecordId,
  }) {
    return api.uploadBackupToCloud(
      userId: userId,
      backupRecordId: backupRecordId,
    );
  }

  Future<RemoteUploadResultModel> uploadLatestBackupToCloud({
    required String userId,
    required String backupType,
  }) {
    return api.uploadLatestBackupToCloud(
      userId: userId,
      backupType: backupType,
    );
  }

  Future<List<RemoteBackupFileModel>> listRemoteBackups({
    required String userId,
    int limit = 20,
  }) {
    return api.listRemoteBackups(userId: userId, limit: limit);
  }

  Future<BackupResultModel> downloadBackupFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  }) {
    return api.downloadBackupFromCloud(
      userId: userId,
      filename: filename,
      backupType: backupType,
    );
  }

  Future<RestoreResultModel> downloadAndRestoreFromCloud({
    required String userId,
    required String filename,
    required String backupType,
  }) {
    return api.downloadAndRestoreFromCloud(
      userId: userId,
      filename: filename,
      backupType: backupType,
    );
  }

  Future<void> deleteRemoteBackup({
    required String userId,
    required String filename,
  }) {
    return api.deleteRemoteBackup(userId: userId, filename: filename);
  }

  Future<CloudSyncConfigModel?> getActiveCloudSyncConfig({
    required String userId,
  }) {
    return api.getActiveCloudSyncConfig(userId: userId);
  }

  Future<List<CloudSyncConfigModel>> listCloudSyncConfigs({
    required String userId,
  }) {
    return api.listCloudSyncConfigs(userId: userId);
  }

  Future<AiServiceConfigModel?> getActiveAiServiceConfig({
    required String userId,
  }) {
    return api.getActiveAiServiceConfig(userId: userId);
  }

  Future<List<AiServiceConfigModel>> listAiServiceConfigs({
    required String userId,
  }) {
    return api.listAiServiceConfigs(userId: userId);
  }

  Future<MonthlyCostBaselineModel> getMonthlyBaseline({
    required String userId,
    required String month,
  }) {
    return api.getMonthlyBaseline(userId: userId, month: month);
  }

  Future<List<RecurringCostRuleModel>> listRecurringCostRules({
    required String userId,
  }) {
    return api.listRecurringCostRules(userId: userId);
  }

  Future<List<CapexCostModel>> listCapexCosts({
    required String userId,
  }) {
    return api.listCapexCosts(userId: userId);
  }

  Future<RateComparisonSummaryModel> getRateComparison({
    required String userId,
    required String anchorDate,
    required String windowType,
  }) {
    return api.getRateComparison(
      userId: userId,
      anchorDate: anchorDate,
      windowType: windowType,
    );
  }

  Future<void> createTimeRecord(Map<String, Object?> payload) {
    return api.createTimeRecord(payload);
  }

  Future<void> createIncomeRecord(Map<String, Object?> payload) {
    return api.createIncomeRecord(payload);
  }

  Future<void> createExpenseRecord(Map<String, Object?> payload) {
    return api.createExpenseRecord(payload);
  }

  Future<void> createLearningRecord(Map<String, Object?> payload) {
    return api.createLearningRecord(payload);
  }

  Future<void> createProject(Map<String, Object?> payload) {
    return api.createProject(payload);
  }

  Future<AiCommitResultModel> commitAiDrafts({
    required String userId,
    required String? requestId,
    required String? contextDate,
    required List<AiParseDraftModel> drafts,
  }) {
    return api.commitAiDrafts(
      userId: userId,
      requestId: requestId,
      contextDate: contextDate,
      drafts: drafts,
    );
  }
}
