class TagModel {
  const TagModel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tagGroup,
    required this.scope,
    required this.parentTagId,
    required this.level,
    required this.status,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final String? emoji;
  final String? tagGroup;
  final String? scope;
  final String? parentTagId;
  final int? level;
  final String? status;
  final int? sortOrder;

  factory TagModel.fromJson(Map<String, dynamic> json) {
    return TagModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      emoji: json['emoji'] as String?,
      tagGroup: json['tag_group'] as String?,
      scope: json['scope'] as String?,
      parentTagId: json['parent_tag_id'] as String?,
      level: (json['level'] as num?)?.toInt(),
      status: json['status'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt(),
    );
  }
}
