import 'package:flutter/foundation.dart';

import '../../models/overview_models.dart';
import '../../models/record_models.dart';
import '../../models/snapshot_models.dart';
import '../../services/app_service.dart';
import '../../shared/view_state.dart';

class TodayPageData {
  const TodayPageData({
    required this.overview,
    required this.recentRecords,
    required this.snapshot,
    required this.summary,
    required this.goalProgress,
    required this.alerts,
  });

  final TodayOverview overview;
  final List<RecentRecordItem> recentRecords;
  final MetricSnapshotSummaryModel snapshot;
  final TodaySummaryModel summary;
  final TodayGoalProgressModel goalProgress;
  final TodayAlertsModel alerts;
}

class TodayController extends ChangeNotifier {
  TodayController(this._service);

  final AppService _service;
  int _activeLoadId = 0;

  ViewState<TodayPageData> state = ViewState.initial();

  Future<void> load({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    final loadId = ++_activeLoadId;
    state = ViewState.loading();
    notifyListeners();

    try {
      final overviewFuture = _service.getTodayOverview(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final recentRecordsFuture = _service.getRecentRecords(
        userId: userId,
        timezone: timezone,
      );
      final summaryFuture = _service.getTodaySummary(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final goalProgressFuture = _service.getTodayGoalProgress(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final alertsFuture = _service.getTodayAlerts(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final snapshotFuture = _loadSnapshot(
        userId: userId,
        snapshotDate: anchorDate,
      );
      final overview = await overviewFuture;
      final recentRecords = await recentRecordsFuture;
      final summary = await summaryFuture;
      final goalProgress = await goalProgressFuture;
      final alerts = await alertsFuture;
      final snapshot = await snapshotFuture;
      if (loadId != _activeLoadId) {
        return;
      }

      if (overview == null) {
        state = ViewState.empty('TodayOverview 尚未返回任何数据。');
      } else {
        state = ViewState.ready(
          TodayPageData(
            overview: overview,
            recentRecords: recentRecords,
            snapshot: snapshot,
            summary: summary,
            goalProgress: goalProgress,
            alerts: alerts,
          ),
        );
      }
    } on UnimplementedError {
      if (loadId != _activeLoadId) {
        return;
      }
      state = ViewState.unavailable('Rust FFI 尚未接入，当前页面只保留真实结构和状态容器。');
    } catch (error) {
      if (loadId != _activeLoadId) {
        return;
      }
      state = ViewState.error(error.toString());
    }

    if (loadId == _activeLoadId) {
      notifyListeners();
    }
  }

  Future<MetricSnapshotSummaryModel> _loadSnapshot({
    required String userId,
    required String snapshotDate,
  }) async {
    return await _service.getSnapshot(
          userId: userId,
          snapshotDate: snapshotDate,
          windowType: 'day',
        ) ??
        await _service.recomputeSnapshot(
          userId: userId,
          snapshotDate: snapshotDate,
          windowType: 'day',
        );
  }
}
