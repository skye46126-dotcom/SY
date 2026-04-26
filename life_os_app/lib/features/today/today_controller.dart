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

  ViewState<TodayPageData> state = ViewState.initial();

  Future<void> load({
    required String userId,
    required String anchorDate,
    required String timezone,
  }) async {
    state = ViewState.loading();
    notifyListeners();

    try {
      final overview = await _service.getTodayOverview(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final recentRecords = await _service.getRecentRecords(
        userId: userId,
        timezone: timezone,
      );
      final summary = await _service.getTodaySummary(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final goalProgress = await _service.getTodayGoalProgress(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final alerts = await _service.getTodayAlerts(
        userId: userId,
        anchorDate: anchorDate,
        timezone: timezone,
      );
      final snapshot = await _service.getSnapshot(
            userId: userId,
            snapshotDate: anchorDate,
            windowType: 'day',
          ) ??
          await _service.recomputeSnapshot(
            userId: userId,
            snapshotDate: anchorDate,
            windowType: 'day',
          );

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
      state = ViewState.unavailable('Rust FFI 尚未接入，当前页面只保留真实结构和状态容器。');
    } catch (error) {
      state = ViewState.error(error.toString());
    }

    notifyListeners();
  }
}
