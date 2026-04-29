import 'package:flutter_test/flutter_test.dart';
import 'package:life_os_app/models/cost_models.dart';
import 'package:life_os_app/models/overview_models.dart';
import 'package:life_os_app/models/project_models.dart';
import 'package:life_os_app/models/record_models.dart';
import 'package:life_os_app/models/review_models.dart';
import 'package:life_os_app/models/snapshot_models.dart';
import 'package:life_os_app/services/export_metadata_builders.dart';

void main() {
  test('buildTodayExportMetadata includes cashflow and snapshot fields', () {
    final metadata = buildTodayExportMetadata(
      overview: const TodayOverview(
        userId: 'u1',
        anchorDate: '2026-04-27',
        timezone: 'Asia/Shanghai',
        totalIncomeCents: 120000,
        totalExpenseCents: 45000,
        netIncomeCents: 75000,
        totalTimeMinutes: 420,
        totalWorkMinutes: 300,
        totalLearningMinutes: 90,
      ),
      summary: const TodaySummaryModel(
        userId: 'u1',
        anchorDate: '2026-04-27',
        headline: '稳定',
        financeStatus: 'positive',
        workStatus: 'done',
        learningStatus: 'in_progress',
        shouldReview: false,
        actualHourlyRateCents: 24000,
        idealHourlyRateCents: 20000,
        freedomCents: 16000,
        passiveCoverRatioBps: 9500,
        alerts: [],
      ),
      alerts: const TodayAlertsModel(
        userId: 'u1',
        anchorDate: '2026-04-27',
        items: [
          TodayAlertModel(
            code: 'missing',
            title: '提醒',
            message: 'message',
            severity: 'warning',
          ),
        ],
      ),
      recentRecordCount: 5,
      anchorDate: '2026-04-27',
      timezone: 'Asia/Shanghai',
      snapshot: const MetricSnapshotSummaryModel(
        id: 's1',
        snapshotDate: '2026-04-27',
        windowType: 'day',
        hourlyRateCents: 24000,
        timeDebtCents: -4000,
        passiveCoverRatio: 0.95,
        freedomCents: 16000,
        totalIncomeCents: 120000,
        totalExpenseCents: 60000,
        totalWorkMinutes: 300,
        generatedAt: '2026-04-27T10:00:00Z',
      ),
    );

    expect(metadata['page'], 'today');
    final summary = metadata['summary']! as Map<String, Object?>;
    expect(summary['cash_balance_cents'], 75000);
    expect(summary['alert_count'], 1);
    expect(summary['recent_record_count'], 5);
    final snapshot = metadata['snapshot']! as Map<String, Object?>;
    expect(snapshot['window_type'], 'day');
  });

  test('buildReviewExportMetadata includes operating balance and history', () {
    final metadata = buildReviewExportMetadata(
      report: ReviewReport(
        window: const ReviewWindow(
          kind: ReviewWindowKind.week,
          periodName: '2026-04-21 - 2026-04-27',
          startDate: '2026-04-21',
          endDate: '2026-04-27',
          previousStartDate: '2026-04-14',
          previousEndDate: '2026-04-20',
        ),
        aiSummary: 'summary',
        totalTimeMinutes: 600,
        totalWorkMinutes: 360,
        totalIncomeCents: 300000,
        totalExpenseCents: 120000,
        previousIncomeCents: 200000,
        previousExpenseCents: 100000,
        previousWorkMinutes: 320,
        incomeChangeRatio: 0.5,
        expenseChangeRatio: 0.2,
        workChangeRatio: 0.1,
        actualHourlyRateCents: 50000,
        idealHourlyRateCents: 30000,
        timeDebtCents: -20000,
        passiveCoverRatio: 1.2,
        aiAssistRate: 0.4,
        workEfficiencyAvg: 7.5,
        learningEfficiencyAvg: 8.2,
        timeAllocations: const [],
        topProjects: const [],
        sinkholeProjects: const [],
        keyEvents: const [],
        incomeHistory: const [],
        historyRecords: const [
          RecentRecordItem(
            recordId: 'r1',
            kind: RecordKind.time,
            occurredAt: '2026-04-21 10:00',
            title: 'deep work',
            detail: '2h',
          ),
        ],
        reviewNotes: const [],
        timeTagMetrics: const [],
        expenseTagMetrics: const [],
      ),
      windowKind: ReviewWindowKind.week,
      anchorDate: DateTime(2026, 4, 27),
    );

    expect(metadata['page'], 'review');
    final summary = metadata['summary']! as Map<String, Object?>;
    expect(summary['operating_balance_cents'], 180000);
    expect(summary['history_record_count'], 1);
  });

  test('buildProjectExportMetadata includes cost layers and snapshot', () {
    final metadata = buildProjectExportMetadata(
      detail: const ProjectDetail(
        id: 'p1',
        name: 'Skye',
        statusCode: 'active',
        startedOn: '2026-01-01',
        endedOn: null,
        aiEnableRatio: 60,
        score: 8,
        note: 'note',
        tagIds: ['t1', 't2'],
        analysisStartDate: '2026-01-01',
        analysisEndDate: '2026-04-27',
        totalTimeMinutes: 800,
        totalIncomeCents: 600000,
        totalExpenseCents: 70000,
        directExpenseCents: 70000,
        timeCostCents: 100000,
        totalCostCents: 220000,
        profitCents: 380000,
        breakEvenIncomeCents: 220000,
        allocatedStructuralCostCents: 50000,
        operatingCostCents: 170000,
        operatingProfitCents: 430000,
        operatingBreakEvenIncomeCents: 170000,
        fullyLoadedCostCents: 220000,
        fullyLoadedProfitCents: 380000,
        fullyLoadedBreakEvenIncomeCents: 220000,
        benchmarkHourlyRateCents: 30000,
        lastYearHourlyRateCents: 26000,
        idealHourlyRateCents: 24000,
        hourlyRateYuan: 450.0,
        roiPerc: 172.7,
        operatingRoiPerc: 252.9,
        fullyLoadedRoiPerc: 172.7,
        evaluationStatus: 'positive',
        totalLearningMinutes: 120,
        timeRecordCount: 10,
        incomeRecordCount: 3,
        expenseRecordCount: 2,
        learningRecordCount: 2,
        recentRecords: [
          RecentRecordItem(
            recordId: 'r1',
            kind: RecordKind.time,
            occurredAt: '2026-04-27 10:00',
            title: 'ship',
            detail: 'done',
          ),
        ],
      ),
      snapshot: const ProjectMetricSnapshotSummaryModel(
        metricSnapshotId: 'ms1',
        projectId: 'p1',
        incomeCents: 120000,
        directExpenseCents: 20000,
        structuralCostCents: 10000,
        operatingCostCents: 50000,
        totalCostCents: 60000,
        profitCents: 60000,
        investedMinutes: 240,
        roiRatio: 1,
        breakEvenCents: 60000,
      ),
    );

    final summary = metadata['summary']! as Map<String, Object?>;
    expect(summary['fully_loaded_cost_cents'], 220000);
    expect(summary['tag_count'], 2);
    final snapshot = metadata['snapshot']! as Map<String, Object?>;
    expect(snapshot['invested_minutes'], 240);
  });

  test('buildCostExportMetadata aggregates active rule counts', () {
    final metadata = buildCostExportMetadata(
      month: '2026-04',
      rateWindowType: 'month',
      baseline: const MonthlyCostBaselineModel(
        month: '2026-04',
        basicLivingCents: 200000,
        fixedSubscriptionCents: 30000,
      ),
      rate: const RateComparisonSummaryModel(
        anchorDate: '2026-04-27',
        windowType: 'month',
        idealHourlyRateCents: 25000,
        previousYearAverageHourlyRateCents: 22000,
        actualHourlyRateCents: 26000,
        previousYearIncomeCents: 500000,
        previousYearWorkMinutes: 1200,
        currentIncomeCents: 120000,
        currentWorkMinutes: 240,
      ),
      recurringRules: const [
        RecurringCostRuleModel(
          id: 'r1',
          name: 'Rent',
          categoryCode: 'necessary',
          monthlyAmountCents: 150000,
          isNecessary: true,
          startMonth: '2026-01',
          endMonth: null,
          isActive: true,
          note: null,
        ),
        RecurringCostRuleModel(
          id: 'r2',
          name: 'Tool',
          categoryCode: 'subscription',
          monthlyAmountCents: 20000,
          isNecessary: false,
          startMonth: '2026-01',
          endMonth: null,
          isActive: false,
          note: null,
        ),
      ],
      capexItems: const [
        CapexCostModel(
          id: 'c1',
          name: 'Laptop',
          purchaseDate: '2026-02-01',
          purchaseAmountCents: 1200000,
          usefulMonths: 24,
          residualRateBps: 2000,
          monthlyAmortizedCents: 40000,
          amortizationStartMonth: '2026-02',
          amortizationEndMonth: '2028-01',
          isActive: true,
          note: null,
        ),
      ],
    );

    expect(metadata['page'], 'cost_management');
    final recurring = metadata['recurring_rules']! as Map<String, Object?>;
    expect(recurring['active_count'], 1);
    expect(recurring['necessary_active_monthly_cents'], 150000);
    final capex = metadata['capex_items']! as Map<String, Object?>;
    expect(capex['active_monthly_amortized_cents'], 40000);
  });

  test('buildDayDetailExportMetadata summarizes per-kind counts', () {
    final metadata = buildDayDetailExportMetadata(
      anchorDate: '2026-04-27',
      timezone: 'Asia/Shanghai',
      records: const [
        RecentRecordItem(
          recordId: 'r1',
          kind: RecordKind.time,
          occurredAt: '2026-04-27 09:00',
          title: 'deep work',
          detail: '90m',
        ),
        RecentRecordItem(
          recordId: 'r2',
          kind: RecordKind.expense,
          occurredAt: '2026-04-27 12:00',
          title: 'meal',
          detail: '¥30',
        ),
        RecentRecordItem(
          recordId: 'r3',
          kind: RecordKind.learning,
          occurredAt: '2026-04-27 20:00',
          title: 'reading',
          detail: '45m',
        ),
      ],
    );

    expect(metadata['page'], 'day_detail');
    final summary = metadata['summary']! as Map<String, Object?>;
    expect(summary['total_record_count'], 3);
    expect(summary['time_count'], 1);
    expect(summary['expense_count'], 1);
    expect(summary['learning_count'], 1);
    expect(summary['first_occurred_at'], '2026-04-27 09:00');
    expect(summary['last_occurred_at'], '2026-04-27 20:00');
  });
}
