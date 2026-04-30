class MetricSnapshotSummaryModel {
  const MetricSnapshotSummaryModel({
    required this.id,
    required this.snapshotDate,
    required this.windowType,
    required this.hourlyRateCents,
    required this.timeDebtCents,
    required this.passiveCoverRatio,
    required this.freedomCents,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.totalWorkMinutes,
    required this.generatedAt,
  });

  final String id;
  final String snapshotDate;
  final String windowType;
  final int? hourlyRateCents;
  final int? timeDebtCents;
  final double? passiveCoverRatio;
  final int? freedomCents;
  final int? totalIncomeCents;
  final int? totalExpenseCents;
  final int? totalWorkMinutes;
  final String generatedAt;

  factory MetricSnapshotSummaryModel.fromJson(Map<String, dynamic> json) {
    return MetricSnapshotSummaryModel(
      id: json['id'] as String? ?? '',
      snapshotDate: json['snapshot_date'] as String? ?? '',
      windowType: json['window_type'] as String? ?? '',
      hourlyRateCents: (json['hourly_rate_cents'] as num?)?.toInt(),
      timeDebtCents: (json['time_debt_cents'] as num?)?.toInt(),
      passiveCoverRatio: (json['passive_cover_ratio'] as num?)?.toDouble(),
      freedomCents: (json['freedom_cents'] as num?)?.toInt(),
      totalIncomeCents: (json['total_income_cents'] as num?)?.toInt(),
      totalExpenseCents: (json['total_expense_cents'] as num?)?.toInt(),
      totalWorkMinutes: (json['total_work_minutes'] as num?)?.toInt(),
      generatedAt: json['generated_at'] as String? ?? '',
    );
  }
}

class ProjectMetricSnapshotSummaryModel {
  const ProjectMetricSnapshotSummaryModel({
    required this.metricSnapshotId,
    required this.projectId,
    required this.incomeCents,
    required this.directExpenseCents,
    required this.structuralCostCents,
    required this.operatingCostCents,
    required this.totalCostCents,
    required this.profitCents,
    required this.investedMinutes,
    required this.roiRatio,
    required this.breakEvenCents,
  });

  final String metricSnapshotId;
  final String projectId;
  final int incomeCents;
  final int directExpenseCents;
  final int structuralCostCents;
  final int operatingCostCents;
  final int totalCostCents;
  final int profitCents;
  final int investedMinutes;
  final double roiRatio;
  final int breakEvenCents;

  factory ProjectMetricSnapshotSummaryModel.fromJson(
      Map<String, dynamic> json) {
    return ProjectMetricSnapshotSummaryModel(
      metricSnapshotId: json['metric_snapshot_id'] as String? ?? '',
      projectId: json['project_id'] as String? ?? '',
      incomeCents: (json['income_cents'] as num?)?.toInt() ?? 0,
      directExpenseCents: (json['direct_expense_cents'] as num?)?.toInt() ?? 0,
      structuralCostCents:
          (json['structural_cost_cents'] as num?)?.toInt() ?? 0,
      operatingCostCents: (json['operating_cost_cents'] as num?)?.toInt() ?? 0,
      totalCostCents: (json['total_cost_cents'] as num?)?.toInt() ?? 0,
      profitCents: (json['profit_cents'] as num?)?.toInt() ?? 0,
      investedMinutes: (json['invested_minutes'] as num?)?.toInt() ?? 0,
      roiRatio: (json['roi_ratio'] as num?)?.toDouble() ?? 0,
      breakEvenCents: (json['break_even_cents'] as num?)?.toInt() ?? 0,
    );
  }
}
