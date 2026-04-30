class MonthlyCostBaselineModel {
  const MonthlyCostBaselineModel({
    required this.month,
    required this.basicLivingCents,
    required this.fixedSubscriptionCents,
  });

  final String month;
  final int basicLivingCents;
  final int fixedSubscriptionCents;

  factory MonthlyCostBaselineModel.fromJson(Map<String, dynamic> json) {
    return MonthlyCostBaselineModel(
      month: json['month'] as String? ?? '',
      basicLivingCents: (json['basic_living_cents'] as num?)?.toInt() ?? 0,
      fixedSubscriptionCents:
          (json['fixed_subscription_cents'] as num?)?.toInt() ?? 0,
    );
  }
}

class RecurringCostRuleModel {
  const RecurringCostRuleModel({
    required this.id,
    required this.name,
    required this.categoryCode,
    required this.monthlyAmountCents,
    required this.isNecessary,
    required this.startMonth,
    required this.endMonth,
    required this.isActive,
    required this.note,
  });

  final String id;
  final String name;
  final String categoryCode;
  final int monthlyAmountCents;
  final bool isNecessary;
  final String startMonth;
  final String? endMonth;
  final bool isActive;
  final String? note;

  factory RecurringCostRuleModel.fromJson(Map<String, dynamic> json) {
    return RecurringCostRuleModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      categoryCode: json['category_code'] as String? ?? '',
      monthlyAmountCents: (json['monthly_amount_cents'] as num?)?.toInt() ?? 0,
      isNecessary: json['is_necessary'] == true,
      startMonth: json['start_month'] as String? ?? '',
      endMonth: json['end_month'] as String?,
      isActive: json['is_active'] == true,
      note: json['note'] as String?,
    );
  }
}

class CapexCostModel {
  const CapexCostModel({
    required this.id,
    required this.name,
    required this.purchaseDate,
    required this.purchaseAmountCents,
    required this.usefulMonths,
    required this.residualRateBps,
    required this.monthlyAmortizedCents,
    required this.amortizationStartMonth,
    required this.amortizationEndMonth,
    required this.isActive,
    required this.note,
  });

  final String id;
  final String name;
  final String purchaseDate;
  final int purchaseAmountCents;
  final int usefulMonths;
  final int residualRateBps;
  final int monthlyAmortizedCents;
  final String amortizationStartMonth;
  final String amortizationEndMonth;
  final bool isActive;
  final String? note;

  factory CapexCostModel.fromJson(Map<String, dynamic> json) {
    return CapexCostModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      purchaseDate: json['purchase_date'] as String? ?? '',
      purchaseAmountCents:
          (json['purchase_amount_cents'] as num?)?.toInt() ?? 0,
      usefulMonths: (json['useful_months'] as num?)?.toInt() ?? 0,
      residualRateBps: (json['residual_rate_bps'] as num?)?.toInt() ?? 0,
      monthlyAmortizedCents:
          (json['monthly_amortized_cents'] as num?)?.toInt() ?? 0,
      amortizationStartMonth: json['amortization_start_month'] as String? ?? '',
      amortizationEndMonth: json['amortization_end_month'] as String? ?? '',
      isActive: json['is_active'] == true,
      note: json['note'] as String?,
    );
  }
}

class RateComparisonSummaryModel {
  const RateComparisonSummaryModel({
    required this.anchorDate,
    required this.windowType,
    required this.idealHourlyRateCents,
    required this.previousYearAverageHourlyRateCents,
    required this.actualHourlyRateCents,
    required this.previousYearIncomeCents,
    required this.previousYearWorkMinutes,
    required this.currentIncomeCents,
    required this.currentWorkMinutes,
  });

  final String anchorDate;
  final String windowType;
  final int idealHourlyRateCents;
  final int? previousYearAverageHourlyRateCents;
  final int? actualHourlyRateCents;
  final int previousYearIncomeCents;
  final int previousYearWorkMinutes;
  final int currentIncomeCents;
  final int currentWorkMinutes;

  factory RateComparisonSummaryModel.fromJson(Map<String, dynamic> json) {
    return RateComparisonSummaryModel(
      anchorDate: json['anchor_date'] as String? ?? '',
      windowType: json['window_type'] as String? ?? '',
      idealHourlyRateCents:
          (json['ideal_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      previousYearAverageHourlyRateCents:
          (json['previous_year_average_hourly_rate_cents'] as num?)?.toInt(),
      actualHourlyRateCents:
          (json['actual_hourly_rate_cents'] as num?)?.toInt(),
      previousYearIncomeCents:
          (json['previous_year_income_cents'] as num?)?.toInt() ?? 0,
      previousYearWorkMinutes:
          (json['previous_year_work_minutes'] as num?)?.toInt() ?? 0,
      currentIncomeCents: (json['current_income_cents'] as num?)?.toInt() ?? 0,
      currentWorkMinutes: (json['current_work_minutes'] as num?)?.toInt() ?? 0,
    );
  }
}
