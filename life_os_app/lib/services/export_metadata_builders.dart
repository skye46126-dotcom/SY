import '../models/cost_models.dart';
import '../models/overview_models.dart';
import '../models/project_models.dart';
import '../models/record_models.dart';
import '../models/review_models.dart';
import '../models/snapshot_models.dart';

Map<String, Object?> buildTodayExportMetadata({
  required TodayOverview overview,
  required TodaySummaryModel summary,
  required TodayAlertsModel alerts,
  required int recentRecordCount,
  required String anchorDate,
  required String timezone,
  MetricSnapshotSummaryModel? snapshot,
}) {
  return {
    'page': 'today',
    'anchor_date': anchorDate,
    'timezone': timezone,
    'summary': {
      'cash_income_cents': overview.totalIncomeCents,
      'cash_expense_cents': overview.totalExpenseCents,
      'cash_balance_cents': overview.netIncomeCents,
      'total_time_minutes': overview.totalTimeMinutes,
      'total_work_minutes': overview.totalWorkMinutes,
      'total_learning_minutes': overview.totalLearningMinutes,
      'actual_hourly_rate_cents': summary.actualHourlyRateCents,
      'ideal_hourly_rate_cents': summary.idealHourlyRateCents,
      'passive_cover_ratio_bps': summary.passiveCoverRatioBps,
      'freedom_cents': summary.freedomCents,
      'alert_count': alerts.items.length,
      'recent_record_count': recentRecordCount,
    },
    if (snapshot != null)
      'snapshot': {
        'snapshot_date': snapshot.snapshotDate,
        'window_type': snapshot.windowType,
        'hourly_rate_cents': snapshot.hourlyRateCents,
        'time_debt_cents': snapshot.timeDebtCents,
        'passive_cover_ratio': snapshot.passiveCoverRatio,
        'freedom_cents': snapshot.freedomCents,
        'total_income_cents': snapshot.totalIncomeCents,
        'total_expense_cents': snapshot.totalExpenseCents,
        'total_work_minutes': snapshot.totalWorkMinutes,
      },
  };
}

Map<String, Object?> buildReviewExportMetadata({
  required ReviewReport report,
  required ReviewWindowKind windowKind,
  required DateTime anchorDate,
  MetricSnapshotSummaryModel? snapshot,
}) {
  return {
    'page': 'review',
    'window_kind': windowKind.name,
    'anchor_date': anchorDate.toIso8601String(),
    'period_name': report.window.periodName,
    'start_date': report.window.startDate,
    'end_date': report.window.endDate,
    'summary': {
      'total_income_cents': report.totalIncomeCents,
      'operating_expense_cents': report.totalExpenseCents,
      'operating_balance_cents':
          report.totalIncomeCents - report.totalExpenseCents,
      'total_time_minutes': report.totalTimeMinutes,
      'total_work_minutes': report.totalWorkMinutes,
      'actual_hourly_rate_cents': report.actualHourlyRateCents,
      'ideal_hourly_rate_cents': report.idealHourlyRateCents,
      'passive_cover_ratio': report.passiveCoverRatio,
      'ai_assist_rate': report.aiAssistRate,
      'top_project_count': report.topProjects.length,
      'sinkhole_project_count': report.sinkholeProjects.length,
      'history_record_count': report.historyRecords.length,
    },
    if (snapshot != null)
      'snapshot': {
        'snapshot_date': snapshot.snapshotDate,
        'window_type': snapshot.windowType,
        'hourly_rate_cents': snapshot.hourlyRateCents,
        'time_debt_cents': snapshot.timeDebtCents,
        'passive_cover_ratio': snapshot.passiveCoverRatio,
        'freedom_cents': snapshot.freedomCents,
      },
  };
}

Map<String, Object?> buildProjectExportMetadata({
  required ProjectDetail detail,
  ProjectMetricSnapshotSummaryModel? snapshot,
}) {
  return {
    'page': 'project_detail',
    'project_id': detail.id,
    'project_name': detail.name,
    'status_code': detail.statusCode,
    'analysis_start_date': detail.analysisStartDate,
    'analysis_end_date': detail.analysisEndDate,
    'summary': {
      'total_income_cents': detail.totalIncomeCents,
      'direct_expense_cents': detail.directExpenseCents,
      'time_cost_cents': detail.timeCostCents,
      'allocated_structural_cost_cents': detail.allocatedStructuralCostCents,
      'operating_cost_cents': detail.operatingCostCents,
      'fully_loaded_cost_cents': detail.fullyLoadedCostCents,
      'total_cost_cents': detail.totalCostCents,
      'profit_cents': detail.profitCents,
      'operating_profit_cents': detail.operatingProfitCents,
      'fully_loaded_profit_cents': detail.fullyLoadedProfitCents,
      'break_even_income_cents': detail.breakEvenIncomeCents,
      'operating_break_even_income_cents': detail.operatingBreakEvenIncomeCents,
      'fully_loaded_break_even_income_cents':
          detail.fullyLoadedBreakEvenIncomeCents,
      'total_time_minutes': detail.totalTimeMinutes,
      'total_learning_minutes': detail.totalLearningMinutes,
      'roi_perc': detail.roiPerc,
      'operating_roi_perc': detail.operatingRoiPerc,
      'fully_loaded_roi_perc': detail.fullyLoadedRoiPerc,
      'benchmark_hourly_rate_cents': detail.benchmarkHourlyRateCents,
      'ideal_hourly_rate_cents': detail.idealHourlyRateCents,
      'recent_record_count': detail.recentRecords.length,
      'tag_count': detail.tagIds.length,
    },
    if (snapshot != null)
      'snapshot': {
        'metric_snapshot_id': snapshot.metricSnapshotId,
        'income_cents': snapshot.incomeCents,
        'direct_expense_cents': snapshot.directExpenseCents,
        'structural_cost_cents': snapshot.structuralCostCents,
        'operating_cost_cents': snapshot.operatingCostCents,
        'total_cost_cents': snapshot.totalCostCents,
        'profit_cents': snapshot.profitCents,
        'invested_minutes': snapshot.investedMinutes,
        'roi_ratio': snapshot.roiRatio,
        'break_even_cents': snapshot.breakEvenCents,
      },
  };
}

Map<String, Object?> buildCostExportMetadata({
  required String month,
  required String rateWindowType,
  MonthlyCostBaselineModel? baseline,
  RateComparisonSummaryModel? rate,
  required List<RecurringCostRuleModel> recurringRules,
  required List<CapexCostModel> capexItems,
}) {
  final activeRecurringCount =
      recurringRules.where((item) => item.isActive).length;
  final activeCapexCount = capexItems.where((item) => item.isActive).length;
  final necessaryRecurringCents = recurringRules
      .where((item) => item.isActive && item.isNecessary)
      .fold<int>(0, (sum, item) => sum + item.monthlyAmountCents);
  final activeCapexMonthlyAmortizedCents = capexItems
      .where((item) => item.isActive)
      .fold<int>(0, (sum, item) => sum + item.monthlyAmortizedCents);

  return {
    'page': 'cost_management',
    'month': month,
    'rate_window_type': rateWindowType,
    'baseline': baseline == null
        ? null
        : {
            'basic_living_cents': baseline.basicLivingCents,
            'fixed_subscription_cents': baseline.fixedSubscriptionCents,
            'total_baseline_cents':
                baseline.basicLivingCents + baseline.fixedSubscriptionCents,
          },
    'rate': rate == null
        ? null
        : {
            'anchor_date': rate.anchorDate,
            'window_type': rate.windowType,
            'ideal_hourly_rate_cents': rate.idealHourlyRateCents,
            'previous_year_average_hourly_rate_cents':
                rate.previousYearAverageHourlyRateCents,
            'actual_hourly_rate_cents': rate.actualHourlyRateCents,
            'current_income_cents': rate.currentIncomeCents,
            'current_work_minutes': rate.currentWorkMinutes,
            'previous_year_income_cents': rate.previousYearIncomeCents,
            'previous_year_work_minutes': rate.previousYearWorkMinutes,
          },
    'recurring_rules': {
      'total_count': recurringRules.length,
      'active_count': activeRecurringCount,
      'inactive_count': recurringRules.length - activeRecurringCount,
      'necessary_active_monthly_cents': necessaryRecurringCents,
    },
    'capex_items': {
      'total_count': capexItems.length,
      'active_count': activeCapexCount,
      'inactive_count': capexItems.length - activeCapexCount,
      'active_monthly_amortized_cents': activeCapexMonthlyAmortizedCents,
    },
  };
}

Map<String, Object?> buildDayDetailExportMetadata({
  required String anchorDate,
  required String timezone,
  required List<RecentRecordItem> records,
  List<ReviewNoteModel> reviewNotes = const [],
}) {
  int countFor(RecordKind kind) =>
      records.where((item) => item.kind == kind).length;
  return {
    'page': 'day_detail',
    'anchor_date': anchorDate,
    'timezone': timezone,
    'summary': {
      'total_record_count': records.length,
      'time_count': countFor(RecordKind.time),
      'income_count': countFor(RecordKind.income),
      'expense_count': countFor(RecordKind.expense),
      'review_note_count': reviewNotes.length,
      'first_occurred_at': records.isEmpty ? null : records.first.occurredAt,
      'last_occurred_at': records.isEmpty ? null : records.last.occurredAt,
    },
    'review_notes': reviewNotes
        .map(
          (note) => {
            'id': note.id,
            'occurred_on': note.occurredOn,
            'note_type': note.noteType,
            'title': note.title,
            'content': note.content,
            'source': note.source,
            'visibility': note.visibility,
          },
        )
        .toList(),
  };
}
