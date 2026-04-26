import 'package:flutter/foundation.dart';

import '../../models/review_models.dart';
import '../../models/snapshot_models.dart';
import '../../services/app_service.dart';
import '../../shared/view_state.dart';

class ReviewPageData {
  const ReviewPageData({
    required this.report,
    required this.snapshot,
    required this.anchorDate,
    required this.selectedKind,
  });

  final ReviewReport report;
  final MetricSnapshotSummaryModel? snapshot;
  final DateTime anchorDate;
  final ReviewWindowKind selectedKind;
}

class ReviewController extends ChangeNotifier {
  ReviewController(this._service);

  final AppService _service;
  ReviewWindowKind selectedKind = ReviewWindowKind.day;
  DateTime anchorDate = DateTime.now();
  DateTime? customStartDate;
  DateTime? customEndDate;
  ViewState<ReviewPageData> state = ViewState.initial();

  Future<void> load({
    required String userId,
    required String timezone,
  }) async {
    state = ViewState.loading();
    notifyListeners();
    try {
      final window = _buildWindow(selectedKind);
      final report = await _service.getReviewReport(
        userId: userId,
        window: window,
        timezone: timezone,
      );
      MetricSnapshotSummaryModel? snapshot;
      final windowType = _snapshotWindowType(selectedKind);
      if (windowType != null) {
        snapshot = await _service.getSnapshot(
              userId: userId,
              snapshotDate: report?.window.startDate ?? window.startDate,
              windowType: windowType,
            ) ??
            await _service.recomputeSnapshot(
              userId: userId,
              snapshotDate: report?.window.startDate ?? window.startDate,
              windowType: windowType,
            );
      }
      if (report == null) {
        state = ViewState.empty('当前窗口没有返回复盘报告。');
      } else {
        state = ViewState.ready(
          ReviewPageData(
            report: report,
            snapshot: snapshot,
            anchorDate: anchorDate,
            selectedKind: selectedKind,
          ),
        );
      }
    } on UnimplementedError {
      state = ViewState.unavailable('复盘接口尚未接入 Rust。');
    } catch (error) {
      state = ViewState.error(error.toString());
    }
    notifyListeners();
  }

  Future<void> changeWindow(
    ReviewWindowKind next,
    String userId,
    String timezone,
  ) async {
    selectedKind = next;
    if (next != ReviewWindowKind.range) {
      customStartDate = null;
      customEndDate = null;
    }
    await load(userId: userId, timezone: timezone);
  }

  Future<void> shiftPeriod(
    int direction,
    String userId,
    String timezone,
  ) async {
    if (selectedKind == ReviewWindowKind.range &&
        customStartDate != null &&
        customEndDate != null) {
      final delta = customEndDate!.difference(customStartDate!).inDays + 1;
      customStartDate = customStartDate!.add(Duration(days: delta * direction));
      customEndDate = customEndDate!.add(Duration(days: delta * direction));
    } else {
      anchorDate = _shiftAnchor(anchorDate, selectedKind, direction);
    }
    await load(userId: userId, timezone: timezone);
  }

  Future<void> jumpToToday(String userId, String timezone) async {
    anchorDate = DateTime.now();
    if (selectedKind == ReviewWindowKind.range) {
      customStartDate = anchorDate;
      customEndDate = anchorDate;
    }
    await load(userId: userId, timezone: timezone);
  }

  Future<void> setCustomRange(
    DateTime start,
    DateTime end,
    String userId,
    String timezone,
  ) async {
    selectedKind = ReviewWindowKind.range;
    if (end.isBefore(start)) {
      final temp = start;
      start = end;
      end = temp;
    }
    customStartDate = DateTime(start.year, start.month, start.day);
    customEndDate = DateTime(end.year, end.month, end.day);
    anchorDate = customStartDate!;
    await load(userId: userId, timezone: timezone);
  }

  ReviewWindow _buildWindow(ReviewWindowKind kind) {
    final anchor = DateTime(anchorDate.year, anchorDate.month, anchorDate.day);
    switch (kind) {
      case ReviewWindowKind.day:
        final previous = anchor.subtract(const Duration(days: 1));
        return ReviewWindow(
          kind: kind,
          periodName: anchor.toIso8601String().split('T').first,
          startDate: _date(anchor),
          endDate: _date(anchor),
          previousStartDate: _date(previous),
          previousEndDate: _date(previous),
        );
      case ReviewWindowKind.week:
        final weekdayOffset = anchor.weekday - DateTime.monday;
        final start = anchor.subtract(Duration(days: weekdayOffset));
        final end = start.add(const Duration(days: 6));
        return ReviewWindow(
          kind: kind,
          periodName: '${_date(start)} - ${_date(end)}',
          startDate: _date(start),
          endDate: _date(end),
          previousStartDate: _date(start.subtract(const Duration(days: 7))),
          previousEndDate: _date(end.subtract(const Duration(days: 7))),
        );
      case ReviewWindowKind.month:
        final start = DateTime(anchor.year, anchor.month, 1);
        final end = DateTime(anchor.year, anchor.month + 1, 0);
        final previousStart = DateTime(anchor.year, anchor.month - 1, 1);
        final previousEnd = DateTime(anchor.year, anchor.month, 0);
        return ReviewWindow(
          kind: kind,
          periodName: '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}',
          startDate: _date(start),
          endDate: _date(end),
          previousStartDate: _date(previousStart),
          previousEndDate: _date(previousEnd),
        );
      case ReviewWindowKind.year:
        final start = DateTime(anchor.year, 1, 1);
        final end = DateTime(anchor.year, 12, 31);
        return ReviewWindow(
          kind: kind,
          periodName: '${anchor.year}',
          startDate: _date(start),
          endDate: _date(end),
          previousStartDate: _date(DateTime(anchor.year - 1, 1, 1)),
          previousEndDate: _date(DateTime(anchor.year - 1, 12, 31)),
        );
      case ReviewWindowKind.range:
        final start = customStartDate ?? anchor;
        final end = customEndDate ?? anchor;
        final dayCount = end.difference(start).inDays + 1;
        return ReviewWindow(
          kind: kind,
          periodName: '${_date(start)} - ${_date(end)}',
          startDate: _date(start),
          endDate: _date(end),
          previousStartDate: _date(start.subtract(Duration(days: dayCount))),
          previousEndDate: _date(end.subtract(Duration(days: dayCount))),
        );
    }
  }

  String? _snapshotWindowType(ReviewWindowKind kind) {
    switch (kind) {
      case ReviewWindowKind.day:
        return 'day';
      case ReviewWindowKind.week:
        return 'week';
      case ReviewWindowKind.month:
        return 'month';
      case ReviewWindowKind.year:
        return 'year';
      case ReviewWindowKind.range:
        return null;
    }
  }

  DateTime _shiftAnchor(DateTime current, ReviewWindowKind kind, int direction) {
    switch (kind) {
      case ReviewWindowKind.day:
        return current.add(Duration(days: direction));
      case ReviewWindowKind.week:
        return current.add(Duration(days: 7 * direction));
      case ReviewWindowKind.month:
        return DateTime(current.year, current.month + direction, current.day);
      case ReviewWindowKind.year:
        return DateTime(current.year + direction, current.month, current.day);
      case ReviewWindowKind.range:
        return current;
    }
  }

  String _date(DateTime value) => value.toIso8601String().split('T').first;
}
