import 'project_models.dart';
import 'tag_models.dart';

class DimensionOptionModel {
  const DimensionOptionModel({
    required this.code,
    required this.displayName,
    required this.isActive,
    required this.isSystem,
  });

  final String code;
  final String displayName;
  final bool isActive;
  final bool isSystem;

  factory DimensionOptionModel.fromJson(Map<String, dynamic> json) {
    return DimensionOptionModel(
      code: json['code'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      isActive: json['is_active'] == true,
      isSystem: json['is_system'] == true,
    );
  }
}

class CaptureDefaultsModel {
  const CaptureDefaultsModel({
    required this.timeCategoryCode,
    required this.incomeTypeCode,
    required this.expenseCategoryCode,
    required this.learningLevelCode,
    required this.projectStatusCode,
  });

  final String? timeCategoryCode;
  final String? incomeTypeCode;
  final String? expenseCategoryCode;
  final String? learningLevelCode;
  final String? projectStatusCode;

  factory CaptureDefaultsModel.fromJson(Map<String, dynamic> json) {
    return CaptureDefaultsModel(
      timeCategoryCode: json['time_category_code'] as String?,
      incomeTypeCode: json['income_type_code'] as String?,
      expenseCategoryCode: json['expense_category_code'] as String?,
      learningLevelCode: json['learning_level_code'] as String?,
      projectStatusCode: json['project_status_code'] as String?,
    );
  }
}

class CaptureMetadataModel {
  const CaptureMetadataModel({
    required this.projectOptions,
    required this.tags,
    required this.timeCategories,
    required this.incomeTypes,
    required this.expenseCategories,
    required this.learningLevels,
    required this.projectStatuses,
    required this.incomeSourceSuggestions,
    required this.defaults,
  });

  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;
  final List<DimensionOptionModel> timeCategories;
  final List<DimensionOptionModel> incomeTypes;
  final List<DimensionOptionModel> expenseCategories;
  final List<DimensionOptionModel> learningLevels;
  final List<DimensionOptionModel> projectStatuses;
  final List<String> incomeSourceSuggestions;
  final CaptureDefaultsModel defaults;

  factory CaptureMetadataModel.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(
      Object? source,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      return (source as List? ?? const [])
          .whereType<Map>()
          .map((item) => fromJson(item.cast<String, dynamic>()))
          .toList();
    }

    return CaptureMetadataModel(
      projectOptions:
          parseList(json['project_options'], ProjectOption.fromJson),
      tags: parseList(json['tags'], TagModel.fromJson),
      timeCategories:
          parseList(json['time_categories'], DimensionOptionModel.fromJson),
      incomeTypes:
          parseList(json['income_types'], DimensionOptionModel.fromJson),
      expenseCategories:
          parseList(json['expense_categories'], DimensionOptionModel.fromJson),
      learningLevels:
          parseList(json['learning_levels'], DimensionOptionModel.fromJson),
      projectStatuses:
          parseList(json['project_statuses'], DimensionOptionModel.fromJson),
      incomeSourceSuggestions:
          ((json['income_source_suggestions'] as List?) ?? const [])
              .map((item) => item.toString())
              .toList(),
      defaults: CaptureDefaultsModel.fromJson(
        ((json['defaults'] as Map?) ?? const {}).cast<String, dynamic>(),
      ),
    );
  }
}

class OperatingSettingsModel {
  const OperatingSettingsModel({
    required this.timezone,
    required this.currencyCode,
    required this.idealHourlyRateCents,
    required this.todayWorkTargetMinutes,
    required this.todayLearningTargetMinutes,
    required this.currentMonth,
    required this.currentMonthBasicLivingCents,
    required this.currentMonthFixedSubscriptionCents,
  });

  final String timezone;
  final String currencyCode;
  final int idealHourlyRateCents;
  final int todayWorkTargetMinutes;
  final int todayLearningTargetMinutes;
  final String currentMonth;
  final int currentMonthBasicLivingCents;
  final int currentMonthFixedSubscriptionCents;

  factory OperatingSettingsModel.fromJson(Map<String, dynamic> json) {
    return OperatingSettingsModel(
      timezone: json['timezone'] as String? ?? 'Asia/Shanghai',
      currencyCode: json['currency_code'] as String? ?? 'CNY',
      idealHourlyRateCents:
          (json['ideal_hourly_rate_cents'] as num?)?.toInt() ?? 0,
      todayWorkTargetMinutes:
          (json['today_work_target_minutes'] as num?)?.toInt() ?? 180,
      todayLearningTargetMinutes:
          (json['today_learning_target_minutes'] as num?)?.toInt() ?? 60,
      currentMonth: json['current_month'] as String? ?? '',
      currentMonthBasicLivingCents:
          (json['current_month_basic_living_cents'] as num?)?.toInt() ?? 0,
      currentMonthFixedSubscriptionCents:
          (json['current_month_fixed_subscription_cents'] as num?)?.toInt() ??
              0,
    );
  }
}
