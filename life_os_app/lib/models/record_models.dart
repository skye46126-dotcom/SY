enum RecordKind {
  time,
  income,
  expense,
}

RecordKind recordKindFromJson(Object? value) {
  final normalized = value.toString().trim().toLowerCase();
  switch (normalized) {
    case 'time':
      return RecordKind.time;
    case 'income':
      return RecordKind.income;
    case 'expense':
      return RecordKind.expense;
    default:
      return RecordKind.time;
  }
}

extension RecordKindLabel on RecordKind {
  String get label {
    switch (this) {
      case RecordKind.time:
        return '时间';
      case RecordKind.income:
        return '收入';
      case RecordKind.expense:
        return '支出';
    }
  }
}

class RecentRecordItem {
  const RecentRecordItem({
    required this.recordId,
    required this.kind,
    required this.occurredAt,
    required this.title,
    required this.detail,
  });

  final String recordId;
  final RecordKind kind;
  final String occurredAt;
  final String title;
  final String detail;

  factory RecentRecordItem.fromJson(Map<String, dynamic> json) {
    return RecentRecordItem(
      recordId: json['record_id'] as String? ?? '',
      kind: recordKindFromJson(json['kind']),
      occurredAt: json['occurred_at'] as String? ?? '',
      title: json['title'] as String? ?? '',
      detail: json['detail'] as String? ?? '',
    );
  }
}

class ProjectAllocationModel {
  const ProjectAllocationModel({
    required this.projectId,
    required this.weightRatio,
  });

  final String projectId;
  final double weightRatio;

  factory ProjectAllocationModel.fromJson(Map<String, dynamic> json) {
    return ProjectAllocationModel(
      projectId: json['project_id'] as String? ?? '',
      weightRatio: (json['weight_ratio'] as num?)?.toDouble() ?? 1.0,
    );
  }
}

class TimeRecordSnapshotModel {
  const TimeRecordSnapshotModel({
    required this.recordId,
    required this.occurredOn,
    required this.startedAt,
    required this.endedAt,
    required this.durationMinutes,
    required this.categoryCode,
    required this.content,
    required this.applicationLevelCode,
    required this.efficiencyScore,
    required this.valueScore,
    required this.stateScore,
    required this.aiAssistRatio,
    required this.note,
    required this.projectAllocations,
    required this.tagIds,
  });

  final String recordId;
  final String occurredOn;
  final String? startedAt;
  final String? endedAt;
  final int durationMinutes;
  final String categoryCode;
  final String content;
  final String? applicationLevelCode;
  final int? efficiencyScore;
  final int? valueScore;
  final int? stateScore;
  final int? aiAssistRatio;
  final String? note;
  final List<ProjectAllocationModel> projectAllocations;
  final List<String> tagIds;

  factory TimeRecordSnapshotModel.fromJson(Map<String, dynamic> json) {
    return TimeRecordSnapshotModel(
      recordId: json['record_id'] as String? ?? '',
      occurredOn: json['occurred_on'] as String? ?? '',
      startedAt: json['started_at'] as String?,
      endedAt: json['ended_at'] as String?,
      durationMinutes: (json['duration_minutes'] as num?)?.toInt() ?? 0,
      categoryCode: json['category_code'] as String? ?? '',
      content: json['content'] as String? ?? '',
      applicationLevelCode: json['application_level_code'] as String?,
      efficiencyScore: (json['efficiency_score'] as num?)?.toInt(),
      valueScore: (json['value_score'] as num?)?.toInt(),
      stateScore: (json['state_score'] as num?)?.toInt(),
      aiAssistRatio: (json['ai_assist_ratio'] as num?)?.toInt(),
      note: json['note'] as String?,
      projectAllocations: ((json['project_allocations'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              ProjectAllocationModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      tagIds: ((json['tag_ids'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class IncomeRecordSnapshotModel {
  const IncomeRecordSnapshotModel({
    required this.recordId,
    required this.occurredOn,
    required this.sourceName,
    required this.typeCode,
    required this.amountCents,
    required this.isPassive,
    required this.aiAssistRatio,
    required this.note,
    required this.isPublicPool,
    required this.projectAllocations,
    required this.tagIds,
  });

  final String recordId;
  final String occurredOn;
  final String sourceName;
  final String typeCode;
  final int amountCents;
  final bool isPassive;
  final int? aiAssistRatio;
  final String? note;
  final bool isPublicPool;
  final List<ProjectAllocationModel> projectAllocations;
  final List<String> tagIds;

  factory IncomeRecordSnapshotModel.fromJson(Map<String, dynamic> json) {
    return IncomeRecordSnapshotModel(
      recordId: json['record_id'] as String? ?? '',
      occurredOn: json['occurred_on'] as String? ?? '',
      sourceName: json['source_name'] as String? ?? '',
      typeCode: json['type_code'] as String? ?? '',
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      isPassive: json['is_passive'] == true,
      aiAssistRatio: (json['ai_assist_ratio'] as num?)?.toInt(),
      note: json['note'] as String?,
      isPublicPool: json['is_public_pool'] == true,
      projectAllocations: ((json['project_allocations'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              ProjectAllocationModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      tagIds: ((json['tag_ids'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class ExpenseRecordSnapshotModel {
  const ExpenseRecordSnapshotModel({
    required this.recordId,
    required this.occurredOn,
    required this.categoryCode,
    required this.amountCents,
    required this.aiAssistRatio,
    required this.note,
    required this.projectAllocations,
    required this.tagIds,
  });

  final String recordId;
  final String occurredOn;
  final String categoryCode;
  final int amountCents;
  final int? aiAssistRatio;
  final String? note;
  final List<ProjectAllocationModel> projectAllocations;
  final List<String> tagIds;

  factory ExpenseRecordSnapshotModel.fromJson(Map<String, dynamic> json) {
    return ExpenseRecordSnapshotModel(
      recordId: json['record_id'] as String? ?? '',
      occurredOn: json['occurred_on'] as String? ?? '',
      categoryCode: json['category_code'] as String? ?? '',
      amountCents: (json['amount_cents'] as num?)?.toInt() ?? 0,
      aiAssistRatio: (json['ai_assist_ratio'] as num?)?.toInt(),
      note: json['note'] as String?,
      projectAllocations: ((json['project_allocations'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) =>
              ProjectAllocationModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      tagIds: ((json['tag_ids'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
