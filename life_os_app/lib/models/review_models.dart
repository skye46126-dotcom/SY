import 'record_models.dart';

class ReviewNoteModel {
  const ReviewNoteModel({
    required this.id,
    required this.userId,
    required this.occurredOn,
    required this.noteType,
    required this.title,
    required this.content,
    required this.source,
    required this.visibility,
    required this.confidence,
    required this.rawText,
    required this.linkedRecordKind,
    required this.linkedRecordId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String occurredOn;
  final String noteType;
  final String title;
  final String content;
  final String source;
  final String visibility;
  final double? confidence;
  final String? rawText;
  final String? linkedRecordKind;
  final String? linkedRecordId;
  final String createdAt;
  final String updatedAt;

  factory ReviewNoteModel.fromJson(Map<String, dynamic> json) {
    return ReviewNoteModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      occurredOn: json['occurred_on'] as String? ?? '',
      noteType: json['note_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      source: json['source'] as String? ?? '',
      visibility: json['visibility'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble(),
      rawText: json['raw_text'] as String?,
      linkedRecordKind: json['linked_record_kind'] as String?,
      linkedRecordId: json['linked_record_id'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

enum ReviewWindowKind {
  day,
  week,
  month,
  year,
  range,
}

ReviewWindowKind reviewWindowKindFromJson(Object? value) {
  final normalized = value.toString().trim().toLowerCase();
  switch (normalized) {
    case 'day':
      return ReviewWindowKind.day;
    case 'week':
      return ReviewWindowKind.week;
    case 'month':
      return ReviewWindowKind.month;
    case 'year':
      return ReviewWindowKind.year;
    case 'range':
      return ReviewWindowKind.range;
    default:
      return ReviewWindowKind.day;
  }
}

class ReviewWindow {
  const ReviewWindow({
    required this.kind,
    required this.periodName,
    required this.startDate,
    required this.endDate,
    required this.previousStartDate,
    required this.previousEndDate,
  });

  final ReviewWindowKind kind;
  final String periodName;
  final String startDate;
  final String endDate;
  final String previousStartDate;
  final String previousEndDate;

  factory ReviewWindow.fromJson(Map<String, dynamic> json) {
    return ReviewWindow(
      kind: reviewWindowKindFromJson(json['kind']),
      periodName: json['period_name'] as String? ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      previousStartDate: json['previous_start_date'] as String? ?? '',
      previousEndDate: json['previous_end_date'] as String? ?? '',
    );
  }
}

class TimeCategoryAllocation {
  const TimeCategoryAllocation({
    required this.categoryName,
    required this.minutes,
    required this.percentage,
  });

  final String categoryName;
  final int minutes;
  final double percentage;

  factory TimeCategoryAllocation.fromJson(Map<String, dynamic> json) {
    return TimeCategoryAllocation(
      categoryName: json['category_name'] as String? ?? '',
      minutes: (json['minutes'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ReviewTagMetric {
  const ReviewTagMetric({
    required this.tagName,
    required this.emoji,
    required this.value,
    required this.percentage,
  });

  final String tagName;
  final String? emoji;
  final int value;
  final double percentage;

  factory ReviewTagMetric.fromJson(Map<String, dynamic> json) {
    return ReviewTagMetric(
      tagName: json['tag_name'] as String? ?? '',
      emoji: json['emoji'] as String?,
      value: (json['value'] as num?)?.toInt() ?? 0,
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ProjectProgressItem {
  const ProjectProgressItem({
    required this.projectId,
    required this.projectName,
    required this.timeSpentMinutes,
    required this.incomeEarnedCents,
    required this.directExpenseCents,
    required this.timeCostCents,
    required this.allocatedStructuralCostCents,
    required this.operatingCostCents,
    required this.fullyLoadedCostCents,
    required this.hourlyRateYuan,
    required this.operatingRoiPerc,
    required this.fullyLoadedRoiPerc,
    required this.evaluationStatus,
  });

  final String projectId;
  final String projectName;
  final int timeSpentMinutes;
  final int incomeEarnedCents;
  final int directExpenseCents;
  final int timeCostCents;
  final int allocatedStructuralCostCents;
  final int operatingCostCents;
  final int fullyLoadedCostCents;
  final double hourlyRateYuan;
  final double operatingRoiPerc;
  final double fullyLoadedRoiPerc;
  final String evaluationStatus;

  factory ProjectProgressItem.fromJson(Map<String, dynamic> json) {
    return ProjectProgressItem(
      projectId: json['project_id'] as String? ?? '',
      projectName: json['project_name'] as String? ?? '',
      timeSpentMinutes: (json['time_spent_minutes'] as num?)?.toInt() ?? 0,
      incomeEarnedCents: (json['income_earned_cents'] as num?)?.toInt() ?? 0,
      directExpenseCents: (json['direct_expense_cents'] as num?)?.toInt() ?? 0,
      timeCostCents: (json['time_cost_cents'] as num?)?.toInt() ?? 0,
      allocatedStructuralCostCents:
          (json['allocated_structural_cost_cents'] as num?)?.toInt() ?? 0,
      operatingCostCents: (json['operating_cost_cents'] as num?)?.toInt() ?? 0,
      fullyLoadedCostCents:
          (json['fully_loaded_cost_cents'] as num?)?.toInt() ?? 0,
      hourlyRateYuan: (json['hourly_rate_yuan'] as num?)?.toDouble() ?? 0,
      operatingRoiPerc: (json['operating_roi_perc'] as num?)?.toDouble() ?? 0,
      fullyLoadedRoiPerc:
          (json['fully_loaded_roi_perc'] as num?)?.toDouble() ?? 0,
      evaluationStatus: json['evaluation_status'] as String? ?? '',
    );
  }
}

class ReviewReport {
  const ReviewReport({
    required this.window,
    required this.aiSummary,
    required this.totalTimeMinutes,
    required this.totalWorkMinutes,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.previousIncomeCents,
    required this.previousExpenseCents,
    required this.previousWorkMinutes,
    required this.incomeChangeRatio,
    required this.expenseChangeRatio,
    required this.workChangeRatio,
    required this.actualHourlyRateCents,
    required this.idealHourlyRateCents,
    required this.timeDebtCents,
    required this.passiveCoverRatio,
    required this.aiAssistRate,
    required this.workEfficiencyAvg,
    required this.learningEfficiencyAvg,
    required this.timeAllocations,
    required this.topProjects,
    required this.sinkholeProjects,
    required this.keyEvents,
    required this.incomeHistory,
    required this.historyRecords,
    required this.reviewNotes,
    required this.timeTagMetrics,
    required this.expenseTagMetrics,
  });

  final ReviewWindow window;
  final String aiSummary;
  final int totalTimeMinutes;
  final int totalWorkMinutes;
  final int totalIncomeCents;
  final int totalExpenseCents;
  final int previousIncomeCents;
  final int previousExpenseCents;
  final int previousWorkMinutes;
  final double? incomeChangeRatio;
  final double? expenseChangeRatio;
  final double? workChangeRatio;
  final int? actualHourlyRateCents;
  final int idealHourlyRateCents;
  final int? timeDebtCents;
  final double? passiveCoverRatio;
  final double? aiAssistRate;
  final double? workEfficiencyAvg;
  final double? learningEfficiencyAvg;
  final List<TimeCategoryAllocation> timeAllocations;
  final List<ProjectProgressItem> topProjects;
  final List<ProjectProgressItem> sinkholeProjects;
  final List<RecentRecordItem> keyEvents;
  final List<RecentRecordItem> incomeHistory;
  final List<RecentRecordItem> historyRecords;
  final List<ReviewNoteModel> reviewNotes;
  final List<ReviewTagMetric> timeTagMetrics;
  final List<ReviewTagMetric> expenseTagMetrics;

  factory ReviewReport.fromJson(Map<String, dynamic> json) {
    return ReviewReport(
      window: ReviewWindow.fromJson(
        (json['window'] as Map?)?.cast<String, dynamic>() ?? const {},
      ),
      aiSummary: json['ai_summary'] as String? ?? '',
      totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt() ?? 0,
      totalWorkMinutes: (json['total_work_minutes'] as num?)?.toInt() ?? 0,
      totalIncomeCents: (json['total_income_cents'] as num?)?.toInt() ?? 0,
      totalExpenseCents: (json['total_expense_cents'] as num?)?.toInt() ?? 0,
      previousIncomeCents:
          (json['previous_income_cents'] as num?)?.toInt() ?? 0,
      previousExpenseCents:
          (json['previous_expense_cents'] as num?)?.toInt() ?? 0,
      previousWorkMinutes:
          (json['previous_work_minutes'] as num?)?.toInt() ?? 0,
      incomeChangeRatio: (json['income_change_ratio'] as num?)?.toDouble(),
      expenseChangeRatio: (json['expense_change_ratio'] as num?)?.toDouble(),
      workChangeRatio: (json['work_change_ratio'] as num?)?.toDouble(),
      actualHourlyRateCents:
          (json['actual_hourly_rate_cents'] as num?)?.toInt(),
      idealHourlyRateCents:
          (json['ideal_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      timeDebtCents: (json['time_debt_cents'] as num?)?.toInt(),
      passiveCoverRatio: (json['passive_cover_ratio'] as num?)?.toDouble(),
      aiAssistRate: (json['ai_assist_rate'] as num?)?.toDouble(),
      workEfficiencyAvg: (json['work_efficiency_avg'] as num?)?.toDouble(),
      learningEfficiencyAvg:
          (json['learning_efficiency_avg'] as num?)?.toDouble(),
      timeAllocations: ((json['time_allocations'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              TimeCategoryAllocation.fromJson(item.cast<String, dynamic>()))
          .toList(),
      topProjects: ((json['top_projects'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              ProjectProgressItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      sinkholeProjects: ((json['sinkhole_projects'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              ProjectProgressItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      keyEvents: ((json['key_events'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (item) => RecentRecordItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      incomeHistory: ((json['income_history'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (item) => RecentRecordItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      historyRecords: ((json['history_records'] as List?) ?? const [])
          .whereType<Map>()
          .map(
              (item) => RecentRecordItem.fromJson(item.cast<String, dynamic>()))
          .toList(),
      reviewNotes: ((json['review_notes'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ReviewNoteModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      timeTagMetrics: ((json['time_tag_metrics'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ReviewTagMetric.fromJson(item.cast<String, dynamic>()))
          .toList(),
      expenseTagMetrics: ((json['expense_tag_metrics'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => ReviewTagMetric.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}
