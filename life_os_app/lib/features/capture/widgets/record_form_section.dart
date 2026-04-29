import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/config_models.dart';
import '../../../models/project_models.dart';
import '../../../models/tag_models.dart';
import '../../../shared/view_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tag_selector.dart';
import '../capture_controller.dart';

enum CaptureFieldKind {
  text,
  multiline,
  time,
  date,
  dropdown,
  money,
  integer,
  percentage,
  score,
  boolean,
}

class CaptureFieldDefinition {
  const CaptureFieldDefinition({
    required this.key,
    required this.label,
    required this.kind,
    this.maxLines = 1,
    this.fullWidth = false,
    this.hintText,
    this.helperText,
    this.suffixText,
    this.optionsKey,
  });

  final String key;
  final String label;
  final CaptureFieldKind kind;
  final int maxLines;
  final bool fullWidth;
  final String? hintText;
  final String? helperText;
  final String? suffixText;
  final CaptureFieldOptions? optionsKey;
}

List<CaptureFieldDefinition> captureFieldDefinitionsFor(CaptureType type) {
  switch (type) {
    case CaptureType.time:
      return const [
        CaptureFieldDefinition(
          key: 'started_at',
          label: '开始时间',
          kind: CaptureFieldKind.time,
          helperText: '使用时间轮盘选择，支持闹钟式滑动。',
        ),
        CaptureFieldDefinition(
          key: 'ended_at',
          label: '结束时间',
          kind: CaptureFieldKind.time,
        ),
        CaptureFieldDefinition(
          key: 'category_code',
          label: '类别',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.timeCategory,
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
          helperText: '0-100，表示本次工作中 AI 参与的比例。',
        ),
        CaptureFieldDefinition(
          key: 'efficiency_score',
          label: '效率评分',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
          helperText: '1-10 分，10 分代表非常高效。',
        ),
        CaptureFieldDefinition(
          key: 'value_score',
          label: '价值评分',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
          helperText: '1-10 分，10 分代表这段时间非常有价值。',
        ),
        CaptureFieldDefinition(
          key: 'state_score',
          label: '状态评分',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
          helperText: '1-10 分，10 分代表你的专注和状态都很好。',
        ),
        CaptureFieldDefinition(
          key: 'note',
          label: '备注',
          kind: CaptureFieldKind.multiline,
          maxLines: 4,
          fullWidth: true,
          hintText: '补充本次工作的上下文、产出或阻碍。',
        ),
      ];
    case CaptureType.income:
      return const [
        CaptureFieldDefinition(
          key: 'amount_yuan',
          label: '金额',
          kind: CaptureFieldKind.money,
          suffixText: '元',
        ),
        CaptureFieldDefinition(
          key: 'source_name',
          label: '来源名称',
          kind: CaptureFieldKind.text,
          hintText: '例如：客户 A、工资、平台分成',
          helperText: '这里写具体来源，类型请在下方选择。',
        ),
        CaptureFieldDefinition(
          key: 'occurred_on',
          label: '发生日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'type_code',
          label: '收入类型',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.incomeType,
        ),
        CaptureFieldDefinition(
          key: 'is_passive',
          label: '被动收入',
          kind: CaptureFieldKind.boolean,
          helperText: '打开后会参与被动收入覆盖率计算。',
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
          helperText: '0-100，表示这笔收入中 AI 对交付的参与比例。',
        ),
        CaptureFieldDefinition(
          key: 'note',
          label: '备注',
          kind: CaptureFieldKind.multiline,
          maxLines: 4,
          fullWidth: true,
          hintText: '例如回款阶段、项目背景、补充说明。',
        ),
      ];
    case CaptureType.expense:
      return const [
        CaptureFieldDefinition(
          key: 'amount_yuan',
          label: '金额',
          kind: CaptureFieldKind.money,
          suffixText: '元',
        ),
        CaptureFieldDefinition(
          key: 'category_code',
          label: '支出类别',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.expenseCategory,
        ),
        CaptureFieldDefinition(
          key: 'occurred_on',
          label: '发生日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
          helperText: '0-100，表示这笔支出是否由 AI 工作流驱动。',
        ),
        CaptureFieldDefinition(
          key: 'note',
          label: '备注',
          kind: CaptureFieldKind.multiline,
          maxLines: 4,
          fullWidth: true,
          hintText: '补充购买内容、场景、用途。',
        ),
      ];
    case CaptureType.learning:
      return const [
        CaptureFieldDefinition(
          key: 'content',
          label: '学习内容',
          kind: CaptureFieldKind.text,
          hintText: '例如：Rust FFI 调试、产品分析',
        ),
        CaptureFieldDefinition(
          key: 'duration_minutes',
          label: '学习时长',
          kind: CaptureFieldKind.integer,
          suffixText: '分钟',
        ),
        CaptureFieldDefinition(
          key: 'occurred_on',
          label: '发生日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'application_level_code',
          label: '应用等级',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.learningLevel,
        ),
        CaptureFieldDefinition(
          key: 'started_at',
          label: '开始时间',
          kind: CaptureFieldKind.time,
          helperText: '可选，用于保留更完整的学习时段。',
        ),
        CaptureFieldDefinition(
          key: 'ended_at',
          label: '结束时间',
          kind: CaptureFieldKind.time,
        ),
        CaptureFieldDefinition(
          key: 'efficiency_score',
          label: '效率评分',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
          helperText: '1-10 分，10 分代表吸收和输出都很好。',
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
          helperText: '0-100，表示学习过程中 AI 的辅助比例。',
        ),
        CaptureFieldDefinition(
          key: 'note',
          label: '备注',
          kind: CaptureFieldKind.multiline,
          maxLines: 4,
          fullWidth: true,
          hintText: '记录关键收获、应用计划或资料来源。',
        ),
      ];
    case CaptureType.project:
      return const [
        CaptureFieldDefinition(
          key: 'name',
          label: '项目名称',
          kind: CaptureFieldKind.text,
        ),
        CaptureFieldDefinition(
          key: 'status_code',
          label: '项目状态',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.projectStatus,
        ),
        CaptureFieldDefinition(
          key: 'started_on',
          label: '开始日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'ended_on',
          label: '结束日期',
          kind: CaptureFieldKind.date,
          helperText: '可选，未结束可以留空。',
        ),
        CaptureFieldDefinition(
          key: 'score',
          label: '项目评分',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
          helperText: '1-10 分，用于主观评估项目质量。',
        ),
        CaptureFieldDefinition(
          key: 'ai_enable_ratio',
          label: 'AI 启用比例',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
          helperText: '0-100，表示项目整体对 AI 的依赖程度。',
        ),
        CaptureFieldDefinition(
          key: 'note',
          label: '备注',
          kind: CaptureFieldKind.multiline,
          maxLines: 4,
          fullWidth: true,
          hintText: '补充项目目标、边界、阶段说明。',
        ),
      ];
  }
}

class RecordFormSection extends StatelessWidget {
  const RecordFormSection({
    super.key,
    required this.selectedType,
    required this.anchorDate,
    required this.controllers,
    required this.submitState,
    required this.projectOptions,
    required this.tags,
    required this.selectedProjectIds,
    required this.selectedTagIds,
    required this.optionResolver,
    required this.sourceSuggestions,
    required this.onProjectToggle,
    required this.onTagToggle,
    required this.onSubmit,
  });

  final CaptureType selectedType;
  final String anchorDate;
  final Map<String, TextEditingController> controllers;
  final ViewState<void> submitState;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;
  final Set<String> selectedProjectIds;
  final Set<String> selectedTagIds;
  final List<DimensionOptionModel> Function(CaptureFieldOptions key)
      optionResolver;
  final List<String> sourceSuggestions;
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
          AdaptiveRecordForm(
            fields: fields,
            controllers: controllers,
            anchorDate: anchorDate,
            optionResolver: optionResolver,
            sourceSuggestions: sourceSuggestions,
          ),
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
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.62)),
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

class AdaptiveRecordForm extends StatefulWidget {
  const AdaptiveRecordForm({
    super.key,
    required this.fields,
    required this.controllers,
    required this.anchorDate,
    required this.optionResolver,
    required this.sourceSuggestions,
  });

  final List<CaptureFieldDefinition> fields;
  final Map<String, TextEditingController> controllers;
  final String anchorDate;
  final List<DimensionOptionModel> Function(CaptureFieldOptions key)
      optionResolver;
  final List<String> sourceSuggestions;

  @override
  State<AdaptiveRecordForm> createState() => _AdaptiveRecordFormState();
}

class _AdaptiveRecordFormState extends State<AdaptiveRecordForm> {
  @override
  void initState() {
    super.initState();
    widget.controllers.putIfAbsent(
      'is_passive',
      () => TextEditingController(text: 'false'),
    );
  }

  bool get _hasTimeWindow =>
      widget.controllers.containsKey('started_at') &&
      widget.controllers.containsKey('ended_at');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final compact = available < 760;
        final fieldWidth = compact ? available : (available - 14) / 2;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final field in widget.fields)
                  SizedBox(
                    width: field.fullWidth ? available : fieldWidth,
                    child: _buildField(context, field),
                  ),
              ],
            ),
            if (_hasTimeWindow) ...[
              const SizedBox(height: 14),
              _TimeSummaryPanel(
                startedAt: widget.controllers['started_at']?.text ?? '',
                endedAt: widget.controllers['ended_at']?.text ?? '',
                onNowPressed: _setStartNow,
                onDurationPressed: _applyDuration,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildField(BuildContext context, CaptureFieldDefinition field) {
    switch (field.kind) {
      case CaptureFieldKind.time:
        return _readOnlyField(
          label: field.label,
          controller: widget.controllers[field.key]!,
          helperText: field.helperText,
          hintText: field.hintText ?? '选择时间',
          icon: Icons.schedule_rounded,
          onTap: () => _pickTime(field.key),
        );
      case CaptureFieldKind.date:
        return _readOnlyField(
          label: field.label,
          controller: widget.controllers[field.key]!,
          helperText: field.helperText,
          hintText: field.hintText ?? '选择日期',
          icon: Icons.calendar_month_rounded,
          onTap: () => _pickDate(field.key),
        );
      case CaptureFieldKind.dropdown:
        final options = field.optionsKey == null
            ? const <DimensionOptionModel>[]
            : widget.optionResolver(field.optionsKey!);
        return _OptionPickerField(
          label: field.label,
          helperText: field.helperText,
          options: options,
          value: widget.controllers[field.key]!.text,
          onSelected: (value) {
            setState(() {
              widget.controllers[field.key]!.text = value;
            });
          },
        );
      case CaptureFieldKind.boolean:
        final selected =
            widget.controllers[field.key]!.text.trim().toLowerCase() == 'true';
        return SwitchListTile(
          value: selected,
          onChanged: (value) {
            setState(() {
              widget.controllers[field.key]!.text = value.toString();
            });
          },
          contentPadding: EdgeInsets.zero,
          title: Text(field.label),
          subtitle: field.helperText == null ? null : Text(field.helperText!),
        );
      case CaptureFieldKind.multiline:
      case CaptureFieldKind.money:
      case CaptureFieldKind.integer:
      case CaptureFieldKind.percentage:
      case CaptureFieldKind.score:
        return TextFormField(
          controller: widget.controllers[field.key],
          minLines: field.maxLines > 1 ? field.maxLines : 1,
          maxLines: field.maxLines,
          keyboardType: _keyboardTypeFor(field.kind),
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hintText,
            helperText: field.helperText,
            suffixText: field.suffixText,
          ),
        );
      case CaptureFieldKind.text:
        if (field.key == 'source_name') {
          return _SourceAutocompleteField(
            controller: widget.controllers[field.key]!,
            suggestions: widget.sourceSuggestions,
            label: field.label,
            hintText: field.hintText,
            helperText: field.helperText,
          );
        }
        return TextFormField(
          controller: widget.controllers[field.key],
          minLines: field.maxLines > 1 ? field.maxLines : 1,
          maxLines: field.maxLines,
          decoration: InputDecoration(
            labelText: field.label,
            hintText: field.hintText,
            helperText: field.helperText,
          ),
        );
    }
  }

  Widget _readOnlyField({
    required String label,
    required TextEditingController controller,
    required VoidCallback onTap,
    required IconData icon,
    String? helperText,
    String? hintText,
  }) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        hintText: hintText,
        suffixIcon: Icon(icon),
      ),
    );
  }

  Future<void> _pickDate(String key) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final currentText = widget.controllers[key]!.text.trim();
    final initial = currentText.isEmpty
        ? DateTime.tryParse(widget.anchorDate) ?? DateTime.now()
        : DateTime.tryParse(currentText) ??
            DateTime.tryParse(widget.anchorDate) ??
            DateTime.now();
    final result = await showDatePicker(
      context: rootContext,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (result == null) {
      return;
    }
    if (!mounted) return;
    setState(() {
      widget.controllers[key]!.text =
          result.toIso8601String().split('T').first;
    });
  }

  Future<void> _pickTime(String key) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final initial =
        _parseTime(widget.controllers[key]!.text) ??
            const TimeOfDay(hour: 9, minute: 0);
    var selected = initial;
    final result = await showModalBottomSheet<TimeOfDay>(
      context: rootContext,
      useRootNavigator: true,
      builder: (context) => SizedBox(
        height: 320,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
              child: Row(
                children: [
                  const Text(
                    '选择时间',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(selected),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                  2024,
                  1,
                  1,
                  initial.hour,
                  initial.minute,
                ),
                onDateTimeChanged: (value) {
                  selected = TimeOfDay(
                    hour: value.hour,
                    minute: value.minute,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
    if (result == null) {
      return;
    }
    if (!mounted) return;
    setState(() {
      widget.controllers[key]!.text = _timeText(result);
    });
  }

  void _setStartNow() {
    final now = TimeOfDay.now();
    final roundedMinute = (now.minute / 5).round() * 5;
    final normalizedHour =
        roundedMinute == 60 ? (now.hour + 1) % 24 : now.hour;
    final normalizedMinute = roundedMinute == 60 ? 0 : roundedMinute;
    final text = _timeText(
      TimeOfDay(hour: normalizedHour, minute: normalizedMinute),
    );
    setState(() {
      widget.controllers['started_at']?.text = text;
      widget.controllers['ended_at']?.text = _offsetTimeText(text, 30);
    });
  }

  void _applyDuration(int minutes) {
    final started = widget.controllers['started_at']?.text.trim() ?? '';
    if (started.isEmpty) {
      _setStartNow();
      return;
    }
    setState(() {
      widget.controllers['ended_at']?.text = _offsetTimeText(started, minutes);
    });
  }

  TimeOfDay? _parseTime(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final parts = trimmed.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _offsetTimeText(String baseText, int minutes) {
    final base =
        _parseTime(baseText) ?? const TimeOfDay(hour: 9, minute: 0);
    final totalMinutes = base.hour * 60 + base.minute + minutes;
    final normalized = totalMinutes % (24 * 60);
    final hour = normalized ~/ 60;
    final minute = normalized % 60;
    return _timeText(TimeOfDay(hour: hour, minute: minute));
  }

  String _timeText(TimeOfDay value) {
    return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  }

  TextInputType _keyboardTypeFor(CaptureFieldKind kind) {
    switch (kind) {
      case CaptureFieldKind.money:
        return const TextInputType.numberWithOptions(decimal: true);
      case CaptureFieldKind.integer:
      case CaptureFieldKind.percentage:
      case CaptureFieldKind.score:
        return TextInputType.number;
      case CaptureFieldKind.text:
      case CaptureFieldKind.multiline:
      case CaptureFieldKind.time:
      case CaptureFieldKind.date:
      case CaptureFieldKind.dropdown:
      case CaptureFieldKind.boolean:
        return TextInputType.text;
    }
  }
}

class _SourceAutocompleteField extends StatelessWidget {
  const _SourceAutocompleteField({
    required this.controller,
    required this.suggestions,
    required this.label,
    this.hintText,
    this.helperText,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String label;
  final String? hintText;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: controller.text),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return suggestions;
        }
        return suggestions.where(
          (item) => item.toLowerCase().contains(query),
        );
      },
      onSelected: (selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        textController.value = controller.value;
        textController.addListener(() {
          controller.value = textController.value;
        });
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            helperText: helperText,
          ),
        );
      },
    );
  }
}

class _OptionPickerField extends StatelessWidget {
  const _OptionPickerField({
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
    this.helperText,
  });

  final String label;
  final List<DimensionOptionModel> options;
  final String value;
  final ValueChanged<String> onSelected;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final selected = options.where((item) => item.code == value).cast<DimensionOptionModel?>().firstWhere(
          (item) => item != null,
          orElse: () => null,
        );
    final displayText = selected?.displayName ?? '';

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: options.isEmpty
          ? null
          : () async {
              final rootContext =
                  Navigator.of(context, rootNavigator: true).context;
              final selectedCode = await showModalBottomSheet<String>(
                context: rootContext,
                useRootNavigator: true,
                builder: (context) => SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          children: [
                            Text(
                              '选择$label',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('取消'),
                            ),
                          ],
                        ),
                      ),
                      Flexible(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final item in options)
                              ListTile(
                                title: Text(item.displayName),
                                subtitle: Text(item.code),
                                trailing: item.code == value
                                    ? const Icon(Icons.check_rounded)
                                    : null,
                                onTap: () => Navigator.of(context).pop(item.code),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (!context.mounted) return;
              if (selectedCode != null) {
                onSelected(selectedCode);
              }
            },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          hintText: options.isEmpty ? '暂无可选项' : '请选择',
          helperText: helperText,
          suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
        ),
        isEmpty: displayText.isEmpty,
        child: Text(
          displayText,
          style: displayText.isEmpty
              ? Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(context).hintColor)
              : Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _TimeSummaryPanel extends StatelessWidget {
  const _TimeSummaryPanel({
    required this.startedAt,
    required this.endedAt,
    required this.onNowPressed,
    required this.onDurationPressed,
  });

  final String startedAt;
  final String endedAt;
  final VoidCallback onNowPressed;
  final ValueChanged<int> onDurationPressed;

  @override
  Widget build(BuildContext context) {
    final duration = _durationLabel(startedAt, endedAt);
    final crossDay = _isCrossDay(startedAt, endedAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timelapse_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  duration,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (crossDay)
                Text(
                  '跨天',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.orange.shade700,
                      ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: onNowPressed,
                child: const Text('现在开始'),
              ),
              for (final minutes in const [15, 30, 60, 90])
                ChoiceChip(
                  label: Text('+$minutes分钟'),
                  selected: false,
                  onSelected: (_) => onDurationPressed(minutes),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _durationLabel(String start, String end) {
    final startMinutes = _minutes(start);
    final endMinutes = _minutes(end);
    if (startMinutes == null || endMinutes == null) {
      return '选择开始和结束时间后自动计算时长';
    }
    var duration = endMinutes - startMinutes;
    if (duration <= 0) {
      duration += 24 * 60;
    }
    final hours = duration ~/ 60;
    final minutes = duration % 60;
    if (hours > 0) {
      return '预计时长 $hours小时${minutes.toString().padLeft(2, '0')}分钟';
    }
    return '预计时长 $minutes 分钟';
  }

  bool _isCrossDay(String start, String end) {
    final startMinutes = _minutes(start);
    final endMinutes = _minutes(end);
    return startMinutes != null &&
        endMinutes != null &&
        endMinutes <= startMinutes;
  }

  int? _minutes(String raw) {
    final parts = raw.trim().split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return hour * 60 + minute;
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
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in labels.entries)
              FilterChip(
                label: Text(entry.value),
                selected: selectedIds.contains(entry.key),
                onSelected: (_) => onToggle(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}
