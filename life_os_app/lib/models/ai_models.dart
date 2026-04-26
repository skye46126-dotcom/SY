class AiServiceConfigModel {
  const AiServiceConfigModel({
    required this.id,
    required this.userId,
    required this.provider,
    required this.baseUrl,
    required this.apiKeyEncrypted,
    required this.model,
    required this.systemPrompt,
    required this.parserMode,
    required this.temperatureMilli,
    required this.isActive,
    required this.lastValidatedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String provider;
  final String? baseUrl;
  final String? apiKeyEncrypted;
  final String? model;
  final String? systemPrompt;
  final String parserMode;
  final int? temperatureMilli;
  final bool isActive;
  final String? lastValidatedAt;
  final String createdAt;
  final String updatedAt;

  factory AiServiceConfigModel.fromJson(Map<String, dynamic> json) {
    return AiServiceConfigModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      provider: json['provider'] as String? ?? '',
      baseUrl: json['base_url'] as String?,
      apiKeyEncrypted: json['api_key_encrypted'] as String?,
      model: json['model'] as String?,
      systemPrompt: json['system_prompt'] as String?,
      parserMode: json['parser_mode']?.toString() ?? 'auto',
      temperatureMilli: (json['temperature_milli'] as num?)?.toInt(),
      isActive: json['is_active'] == true,
      lastValidatedAt: json['last_validated_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }
}

class AiParseDraftModel {
  const AiParseDraftModel({
    required this.draftId,
    required this.kind,
    required this.payload,
    required this.confidence,
    required this.source,
    required this.warning,
  });

  final String draftId;
  final String kind;
  final Map<String, String> payload;
  final double confidence;
  final String source;
  final String? warning;

  factory AiParseDraftModel.fromJson(Map<String, dynamic> json) {
    return AiParseDraftModel(
      draftId: json['draft_id'] as String? ?? '',
      kind: json['kind']?.toString() ?? '',
      payload: ((json['payload'] as Map?) ?? const {})
          .map((key, value) => MapEntry(key.toString(), value.toString())),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      source: json['source'] as String? ?? '',
      warning: json['warning'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'draft_id': draftId,
      'kind': kind,
      'payload': payload,
      'confidence': confidence,
      'source': source,
      'warning': warning,
    };
  }

  AiParseDraftModel copyWith({
    String? draftId,
    String? kind,
    Map<String, String>? payload,
    double? confidence,
    String? source,
    String? warning,
  }) {
    return AiParseDraftModel(
      draftId: draftId ?? this.draftId,
      kind: kind ?? this.kind,
      payload: payload ?? this.payload,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      warning: warning ?? this.warning,
    );
  }
}

class AiParseResultModel {
  const AiParseResultModel({
    required this.requestId,
    required this.items,
    required this.warnings,
    required this.parserUsed,
  });

  final String requestId;
  final List<AiParseDraftModel> items;
  final List<String> warnings;
  final String parserUsed;

  factory AiParseResultModel.fromJson(Map<String, dynamic> json) {
    return AiParseResultModel(
      requestId: json['request_id'] as String? ?? '',
      items: ((json['items'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AiParseDraftModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
      parserUsed: json['parser_used'] as String? ?? '',
    );
  }
}

class AiCommittedRecordModel {
  const AiCommittedRecordModel({
    required this.draftId,
    required this.kind,
    required this.recordId,
    required this.occurredAt,
    required this.warnings,
  });

  final String draftId;
  final String kind;
  final String recordId;
  final String occurredAt;
  final List<String> warnings;

  factory AiCommittedRecordModel.fromJson(Map<String, dynamic> json) {
    return AiCommittedRecordModel(
      draftId: json['draft_id'] as String? ?? '',
      kind: json['kind']?.toString() ?? '',
      recordId: json['record_id'] as String? ?? '',
      occurredAt: json['occurred_at'] as String? ?? '',
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class AiCommitFailureModel {
  const AiCommitFailureModel({
    required this.draftId,
    required this.kind,
    required this.message,
  });

  final String draftId;
  final String kind;
  final String message;

  factory AiCommitFailureModel.fromJson(Map<String, dynamic> json) {
    return AiCommitFailureModel(
      draftId: json['draft_id'] as String? ?? '',
      kind: json['kind']?.toString() ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class AiCommitResultModel {
  const AiCommitResultModel({
    required this.requestId,
    required this.committed,
    required this.failures,
    required this.warnings,
  });

  final String requestId;
  final List<AiCommittedRecordModel> committed;
  final List<AiCommitFailureModel> failures;
  final List<String> warnings;

  factory AiCommitResultModel.fromJson(Map<String, dynamic> json) {
    return AiCommitResultModel(
      requestId: json['request_id'] as String? ?? '',
      committed: ((json['committed'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AiCommittedRecordModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      failures: ((json['failures'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => AiCommitFailureModel.fromJson(item.cast<String, dynamic>()))
          .toList(),
      warnings: ((json['warnings'] as List?) ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
