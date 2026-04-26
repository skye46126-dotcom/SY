class TodayOverview {
  const TodayOverview({
    required this.userId,
    required this.anchorDate,
    required this.timezone,
    required this.totalIncomeCents,
    required this.totalExpenseCents,
    required this.netIncomeCents,
    required this.totalTimeMinutes,
    required this.totalWorkMinutes,
    required this.totalLearningMinutes,
  });

  final String userId;
  final String anchorDate;
  final String timezone;
  final int totalIncomeCents;
  final int totalExpenseCents;
  final int netIncomeCents;
  final int totalTimeMinutes;
  final int totalWorkMinutes;
  final int totalLearningMinutes;

  factory TodayOverview.fromJson(Map<String, dynamic> json) {
    return TodayOverview(
      userId: json['user_id'] as String? ?? '',
      anchorDate: json['anchor_date'] as String? ?? '',
      timezone: json['timezone'] as String? ?? '',
      totalIncomeCents: (json['total_income_cents'] as num?)?.toInt() ?? 0,
      totalExpenseCents: (json['total_expense_cents'] as num?)?.toInt() ?? 0,
      netIncomeCents: (json['net_income_cents'] as num?)?.toInt() ?? 0,
      totalTimeMinutes: (json['total_time_minutes'] as num?)?.toInt() ?? 0,
      totalWorkMinutes: (json['total_work_minutes'] as num?)?.toInt() ?? 0,
      totalLearningMinutes: (json['total_learning_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}

class TodayGoalProgressItemModel {
  const TodayGoalProgressItemModel({
    required this.key,
    required this.title,
    required this.unit,
    required this.targetValue,
    required this.completedValue,
    required this.progressRatioBps,
    required this.status,
  });

  final String key;
  final String title;
  final String unit;
  final int targetValue;
  final int completedValue;
  final int progressRatioBps;
  final String status;

  factory TodayGoalProgressItemModel.fromJson(Map<String, dynamic> json) {
    return TodayGoalProgressItemModel(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      unit: json['unit'] as String? ?? '',
      targetValue: (json['target_value'] as num?)?.toInt() ?? 0,
      completedValue: (json['completed_value'] as num?)?.toInt() ?? 0,
      progressRatioBps: (json['progress_ratio_bps'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? '',
    );
  }
}

class TodayGoalProgressModel {
  const TodayGoalProgressModel({
    required this.userId,
    required this.anchorDate,
    required this.items,
  });

  final String userId;
  final String anchorDate;
  final List<TodayGoalProgressItemModel> items;

  factory TodayGoalProgressModel.fromJson(Map<String, dynamic> json) {
    return TodayGoalProgressModel(
      userId: json['user_id'] as String? ?? '',
      anchorDate: json['anchor_date'] as String? ?? '',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => TodayGoalProgressItemModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TodayAlertModel {
  const TodayAlertModel({
    required this.code,
    required this.title,
    required this.message,
    required this.severity,
  });

  final String code;
  final String title;
  final String message;
  final String severity;

  factory TodayAlertModel.fromJson(Map<String, dynamic> json) {
    return TodayAlertModel(
      code: json['code'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      severity: json['severity'] as String? ?? '',
    );
  }
}

class TodayAlertsModel {
  const TodayAlertsModel({
    required this.userId,
    required this.anchorDate,
    required this.items,
  });

  final String userId;
  final String anchorDate;
  final List<TodayAlertModel> items;

  factory TodayAlertsModel.fromJson(Map<String, dynamic> json) {
    return TodayAlertsModel(
      userId: json['user_id'] as String? ?? '',
      anchorDate: json['anchor_date'] as String? ?? '',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => TodayAlertModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TodaySummaryModel {
  const TodaySummaryModel({
    required this.userId,
    required this.anchorDate,
    required this.headline,
    required this.financeStatus,
    required this.workStatus,
    required this.learningStatus,
    required this.shouldReview,
    required this.actualHourlyRateCents,
    required this.idealHourlyRateCents,
    required this.freedomCents,
    required this.passiveCoverRatioBps,
    required this.alerts,
  });

  final String userId;
  final String anchorDate;
  final String headline;
  final String financeStatus;
  final String workStatus;
  final String learningStatus;
  final bool shouldReview;
  final int? actualHourlyRateCents;
  final int idealHourlyRateCents;
  final int? freedomCents;
  final int? passiveCoverRatioBps;
  final List<TodayAlertModel> alerts;

  factory TodaySummaryModel.fromJson(Map<String, dynamic> json) {
    return TodaySummaryModel(
      userId: json['user_id'] as String? ?? '',
      anchorDate: json['anchor_date'] as String? ?? '',
      headline: json['headline'] as String? ?? '',
      financeStatus: json['finance_status'] as String? ?? '',
      workStatus: json['work_status'] as String? ?? '',
      learningStatus: json['learning_status'] as String? ?? '',
      shouldReview: json['should_review'] == true,
      actualHourlyRateCents: (json['actual_hourly_rate_cents'] as num?)?.toInt(),
      idealHourlyRateCents: (json['ideal_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      freedomCents: (json['freedom_cents'] as num?)?.toInt(),
      passiveCoverRatioBps: (json['passive_cover_ratio_bps'] as num?)?.toInt(),
      alerts: ((json['alerts'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => TodayAlertModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}
