import 'record_models.dart';

class ProjectOption {
  const ProjectOption({
    required this.id,
    required this.name,
    required this.statusCode,
  });

  final String id;
  final String name;
  final String statusCode;

  factory ProjectOption.fromJson(Map<String, dynamic> json) {
    return ProjectOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      statusCode: json['status_code'] as String? ?? '',
    );
  }
}

class ProjectOverview {
  const ProjectOverview({
    required this.id,
    required this.name,
    required this.statusCode,
    required this.score,
    required this.totalTimeMinutes,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
  });

  final String id;
  final String name;
  final String statusCode;
  final int? score;
  final int totalTimeMinutes;
  final int totalIncomeCents;
  final int totalExpenseCents;

  factory ProjectOverview.fromJson(Map<String, dynamic> json) {
    return ProjectOverview(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      statusCode: json['status_code'] as String? ?? '',
      score: (json['score'] as num?)?.toInt(),
      totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt() ?? 0,
      totalIncomeCents: (json['total_income_cents'] as num?)?.toInt() ?? 0,
      totalExpenseCents: (json['total_expense_cents'] as num?)?.toInt() ?? 0,
    );
  }
}

class ProjectDetail {
  const ProjectDetail({
    required this.id,
    required this.name,
    required this.statusCode,
    required this.startedOn,
    required this.endedOn,
    required this.aiEnableRatio,
    required this.score,
    required this.note,
    required this.tagIds,
    required this.analysisStartDate,
    required this.analysisEndDate,
    required this.totalTimeMinutes,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.directExpenseCents,
    required this.timeCostCents,
    required this.totalCostCents,
    required this.profitCents,
    required this.breakEvenIncomeCents,
    required this.allocatedStructuralCostCents,
    required this.operatingCostCents,
    required this.operatingProfitCents,
    required this.operatingBreakEvenIncomeCents,
    required this.fullyLoadedCostCents,
    required this.fullyLoadedProfitCents,
    required this.fullyLoadedBreakEvenIncomeCents,
    required this.benchmarkHourlyRateCents,
    required this.lastYearHourlyRateCents,
    required this.idealHourlyRateCents,
    required this.hourlyRateYuan,
    required this.roiPerc,
    required this.operatingRoiPerc,
    required this.fullyLoadedRoiPerc,
    required this.evaluationStatus,
    required this.totalLearningMinutes,
    required this.timeRecordCount,
    required this.incomeRecordCount,
    required this.expenseRecordCount,
    required this.learningRecordCount,
    required this.recentRecords,
  });

  final String id;
  final String name;
  final String statusCode;
  final String startedOn;
  final String? endedOn;
  final int? aiEnableRatio;
  final int? score;
  final String? note;
  final List<String> tagIds;
  final String analysisStartDate;
  final String analysisEndDate;
  final int totalTimeMinutes;
  final int totalIncomeCents;
  final int totalExpenseCents;
  final int directExpenseCents;
  final int timeCostCents;
  final int totalCostCents;
  final int profitCents;
  final int breakEvenIncomeCents;
  final int allocatedStructuralCostCents;
  final int operatingCostCents;
  final int operatingProfitCents;
  final int operatingBreakEvenIncomeCents;
  final int fullyLoadedCostCents;
  final int fullyLoadedProfitCents;
  final int fullyLoadedBreakEvenIncomeCents;
  final int benchmarkHourlyRateCents;
  final int lastYearHourlyRateCents;
  final int idealHourlyRateCents;
  final double hourlyRateYuan;
  final double roiPerc;
  final double operatingRoiPerc;
  final double fullyLoadedRoiPerc;
  final String evaluationStatus;
  final int totalLearningMinutes;
  final int timeRecordCount;
  final int incomeRecordCount;
  final int expenseRecordCount;
  final int learningRecordCount;
  final List<RecentRecordItem> recentRecords;

  factory ProjectDetail.fromJson(Map<String, dynamic> json) {
    return ProjectDetail(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      statusCode: json['status_code'] as String? ?? '',
      startedOn: json['started_on'] as String? ?? '',
      endedOn: json['ended_on'] as String?,
      aiEnableRatio: (json['ai_enable_ratio'] as num?)?.toInt(),
      score: (json['score'] as num?)?.toInt(),
      note: json['note'] as String?,
      tagIds: ((json['tag_ids'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      analysisStartDate: json['analysis_start_date'] as String? ?? '',
      analysisEndDate: json['analysis_end_date'] as String? ?? '',
      totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt() ?? 0,
      totalIncomeCents: (json['total_income_cents'] as num?)?.toInt() ?? 0,
      totalExpenseCents: (json['total_expense_cents'] as num?)?.toInt() ?? 0,
      directExpenseCents: (json['direct_expense_cents'] as num?)?.toInt() ?? 0,
      timeCostCents: (json['time_cost_cents'] as num?)?.toInt() ?? 0,
      totalCostCents: (json['total_cost_cents'] as num?)?.toInt() ?? 0,
      profitCents: (json['profit_cents'] as num?)?.toInt() ?? 0,
      breakEvenIncomeCents:
          (json['break_even_income_cents'] as num?)?.toInt() ?? 0,
      allocatedStructuralCostCents:
          (json['allocated_structural_cost_cents'] as num?)?.toInt() ?? 0,
      operatingCostCents: (json['operating_cost_cents'] as num?)?.toInt() ?? 0,
      operatingProfitCents:
          (json['operating_profit_cents'] as num?)?.toInt() ?? 0,
      operatingBreakEvenIncomeCents:
          (json['operating_break_even_income_cents'] as num?)?.toInt() ?? 0,
      fullyLoadedCostCents:
          (json['fully_loaded_cost_cents'] as num?)?.toInt() ?? 0,
      fullyLoadedProfitCents:
          (json['fully_loaded_profit_cents'] as num?)?.toInt() ?? 0,
      fullyLoadedBreakEvenIncomeCents:
          (json['fully_loaded_break_even_income_cents'] as num?)?.toInt() ?? 0,
      benchmarkHourlyRateCents:
          (json['benchmark_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      lastYearHourlyRateCents:
          (json['last_year_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      idealHourlyRateCents:
          (json['ideal_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      hourlyRateYuan: (json['hourly_rate_yuan'] as num?)?.toDouble() ?? 0,
      roiPerc: (json['roi_perc'] as num?)?.toDouble() ?? 0,
      operatingRoiPerc: (json['operating_roi_perc'] as num?)?.toDouble() ?? 0,
      fullyLoadedRoiPerc:
          (json['fully_loaded_roi_perc'] as num?)?.toDouble() ?? 0,
      evaluationStatus: json['evaluation_status'] as String? ?? '',
      totalLearningMinutes:
          (json['total_learning_minutes'] as num?)?.toInt() ?? 0,
      timeRecordCount: (json['time_record_count'] as num?)?.toInt() ?? 0,
      incomeRecordCount: (json['income_record_count'] as num?)?.toInt() ?? 0,
      expenseRecordCount: (json['expense_record_count'] as num?)?.toInt() ?? 0,
      learningRecordCount:
          (json['learning_record_count'] as num?)?.toInt() ?? 0,
      recentRecords: ((json['recent_records'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (item) => RecentRecordItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}
