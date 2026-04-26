import 'package:flutter/material.dart';

import '../../../models/project_models.dart';
import '../../../models/tag_models.dart';
import '../../../shared/view_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tag_selector.dart';
import '../capture_controller.dart';

class CaptureFieldDefinition {
  const CaptureFieldDefinition({
    required this.key,
    required this.label,
    this.maxLines = 1,
    this.fullWidth = false,
    this.hintText,
  });

  final String key;
  final String label;
  final int maxLines;
  final bool fullWidth;
  final String? hintText;
}

List<CaptureFieldDefinition> captureFieldDefinitionsFor(CaptureType type) {
  switch (type) {
    case CaptureType.time:
      return const [
        CaptureFieldDefinition(
            key: 'started_at', label: '开始时间', hintText: '09:30'),
        CaptureFieldDefinition(
            key: 'ended_at', label: '结束时间', hintText: '11:00'),
        CaptureFieldDefinition(
            key: 'category_code', label: '类别', hintText: 'work'),
        CaptureFieldDefinition(key: 'ai_assist_ratio', label: 'AI 占比'),
        CaptureFieldDefinition(key: 'efficiency_score', label: '效率'),
        CaptureFieldDefinition(
            key: 'note', label: '备注', maxLines: 4, fullWidth: true),
      ];
    case CaptureType.income:
      return const [
        CaptureFieldDefinition(key: 'amount_yuan', label: '金额(元)'),
        CaptureFieldDefinition(key: 'source_name', label: '来源'),
        CaptureFieldDefinition(
            key: 'occurred_on', label: '发生日期', hintText: '2026-04-26'),
        CaptureFieldDefinition(
            key: 'type_code', label: '类型', hintText: 'project'),
        CaptureFieldDefinition(
            key: 'is_passive', label: '是否被动收入', hintText: 'true / false'),
        CaptureFieldDefinition(key: 'ai_assist_ratio', label: 'AI 占比'),
        CaptureFieldDefinition(
            key: 'note', label: '备注', maxLines: 4, fullWidth: true),
      ];
    case CaptureType.expense:
      return const [
        CaptureFieldDefinition(key: 'amount_yuan', label: '金额(元)'),
        CaptureFieldDefinition(
            key: 'category_code', label: '类别', hintText: 'necessary'),
        CaptureFieldDefinition(
            key: 'occurred_on', label: '发生日期', hintText: '2026-04-26'),
        CaptureFieldDefinition(key: 'ai_assist_ratio', label: 'AI 占比'),
        CaptureFieldDefinition(
            key: 'note', label: '备注', maxLines: 4, fullWidth: true),
      ];
    case CaptureType.learning:
      return const [
        CaptureFieldDefinition(key: 'content', label: '内容'),
        CaptureFieldDefinition(key: 'duration_minutes', label: '时长(分钟)'),
        CaptureFieldDefinition(
            key: 'occurred_on', label: '发生日期', hintText: '2026-04-26'),
        CaptureFieldDefinition(
            key: 'application_level_code', label: '应用等级', hintText: 'input'),
        CaptureFieldDefinition(
            key: 'started_at', label: '开始时间', hintText: '20:00'),
        CaptureFieldDefinition(
            key: 'ended_at', label: '结束时间', hintText: '21:00'),
        CaptureFieldDefinition(key: 'efficiency_score', label: '效率'),
        CaptureFieldDefinition(key: 'ai_assist_ratio', label: 'AI 占比'),
        CaptureFieldDefinition(
            key: 'note', label: '备注', maxLines: 4, fullWidth: true),
      ];
    case CaptureType.project:
      return const [
        CaptureFieldDefinition(key: 'name', label: '项目名称'),
        CaptureFieldDefinition(
            key: 'status_code', label: '项目状态', hintText: 'active'),
        CaptureFieldDefinition(
            key: 'started_on', label: '开始日期', hintText: '2026-04-26'),
        CaptureFieldDefinition(key: 'ended_on', label: '结束日期'),
        CaptureFieldDefinition(key: 'score', label: '评分'),
        CaptureFieldDefinition(key: 'ai_enable_ratio', label: 'AI 启用比例'),
        CaptureFieldDefinition(
            key: 'note', label: '备注', maxLines: 4, fullWidth: true),
      ];
  }
}

class RecordFormSection extends StatelessWidget {
  const RecordFormSection({
    super.key,
    required this.selectedType,
    required this.controllers,
    required this.submitState,
    required this.projectOptions,
    required this.tags,
    required this.selectedProjectIds,
    required this.selectedTagIds,
    required this.onProjectToggle,
    required this.onTagToggle,
    required this.onSubmit,
  });

  final CaptureType selectedType;
  final Map<String, TextEditingController> controllers;
  final ViewState<void> submitState;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;
  final Set<String> selectedProjectIds;
  final Set<String> selectedTagIds;
  final ValueChanged<String> onProjectToggle;
  final ValueChanged<String> onTagToggle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final fields = captureFieldDefinitionsFor(selectedType);
    return SectionCard(
      eyebrow: 'Manual Capture',
      title: '${selectedType.label}录入',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AdaptiveForm(fields: fields, controllers: controllers),
          if (selectedType != CaptureType.project &&
              projectOptions.isNotEmpty) ...[
            const SizedBox(height: 16),
            _ChoiceSection(
              title: '关联项目',
              selectedIds: selectedProjectIds,
              labels: {
                for (final item in projectOptions) item.id: item.name,
              },
              onToggle: onProjectToggle,
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            TagSelector(
              title: '标签',
              selectedIds: selectedTagIds,
              labels: {
                for (final item in tags)
                  item.id: '${item.emoji ?? ''} ${item.name}',
              },
              onToggle: onTagToggle,
            ),
          ],
          const SizedBox(height: 20),
          if (submitState.status == ViewStatus.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SectionLoadingView(label: '正在提交记录'),
            ),
          if (submitState.status == ViewStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '提交失败',
                description: submitState.message ?? '请检查字段后重试。',
              ),
            ),
          if (submitState.status == ViewStatus.data)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SectionMessageView(
                icon: Icons.check_circle_outline_rounded,
                title: '提交成功',
                description: '记录已经写入数据库。',
              ),
            ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSubmit,
                    child: const Text('保存记录'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceSection extends StatelessWidget {
  const _ChoiceSection({
    required this.title,
    required this.selectedIds,
    required this.labels,
    required this.onToggle,
  });

  final String title;
  final Set<String> selectedIds;
  final Map<String, String> labels;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in labels.entries)
              FilterChip(
                label: Text(entry.value.trim()),
                selected: selectedIds.contains(entry.key),
                onSelected: (_) => onToggle(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _AdaptiveForm extends StatelessWidget {
  const _AdaptiveForm({
    required this.fields,
    required this.controllers,
  });

  final List<CaptureFieldDefinition> fields;
  final Map<String, TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        for (final field in fields)
          SizedBox(
            width: field.fullWidth ? 720 : 352,
            child: TextFormField(
              controller: controllers[field.key],
              minLines: field.maxLines > 1 ? field.maxLines : 1,
              maxLines: field.maxLines,
              decoration: InputDecoration(
                labelText: field.label,
                hintText: field.hintText,
              ),
            ),
          ),
      ],
    );
  }
}
