import 'package:flutter/material.dart';

import '../../../models/project_models.dart';
import '../../../models/record_models.dart';
import '../../../models/tag_models.dart';

class RecordEditorResult {
  const RecordEditorResult({
    required this.method,
    required this.payload,
  });

  final String method;
  final Map<String, Object?> payload;
}

class RecordEditorDialog extends StatefulWidget {
  const RecordEditorDialog.time({
    super.key,
    required this.recordId,
    required this.userId,
    required this.anchorDate,
    required this.timeSnapshot,
    required this.projectOptions,
    required this.tags,
  })  : incomeSnapshot = null,
        expenseSnapshot = null,
        learningSnapshot = null,
        kind = RecordKind.time;

  const RecordEditorDialog.income({
    super.key,
    required this.recordId,
    required this.userId,
    required this.anchorDate,
    required this.incomeSnapshot,
    required this.projectOptions,
    required this.tags,
  })  : timeSnapshot = null,
        expenseSnapshot = null,
        learningSnapshot = null,
        kind = RecordKind.income;

  const RecordEditorDialog.expense({
    super.key,
    required this.recordId,
    required this.userId,
    required this.anchorDate,
    required this.expenseSnapshot,
    required this.projectOptions,
    required this.tags,
  })  : timeSnapshot = null,
        incomeSnapshot = null,
        learningSnapshot = null,
        kind = RecordKind.expense;

  const RecordEditorDialog.learning({
    super.key,
    required this.recordId,
    required this.userId,
    required this.anchorDate,
    required this.learningSnapshot,
    required this.projectOptions,
    required this.tags,
  })  : timeSnapshot = null,
        incomeSnapshot = null,
        expenseSnapshot = null,
        kind = RecordKind.learning;

  final String recordId;
  final String userId;
  final String anchorDate;
  final RecordKind kind;
  final TimeRecordSnapshotModel? timeSnapshot;
  final IncomeRecordSnapshotModel? incomeSnapshot;
  final ExpenseRecordSnapshotModel? expenseSnapshot;
  final LearningRecordSnapshotModel? learningSnapshot;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;

  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Set<String> _selectedProjectIds;
  late final Set<String> _selectedTagIds;
  bool _isPassive = false;

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers();
    _selectedProjectIds = _initialProjectIds();
    _selectedTagIds = _initialTagIds();
    _isPassive = widget.incomeSnapshot?.isPassive ?? false;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('编辑${widget.kind.label}记录'),
      content: SizedBox(
        width: 720,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ..._formFields(),
              const SizedBox(height: 16),
              if (widget.projectOptions.isNotEmpty) ...[
                Text('项目', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in widget.projectOptions)
                      FilterChip(
                        label: Text(item.name),
                        selected: _selectedProjectIds.contains(item.id),
                        onSelected: (_) {
                          setState(() {
                            if (_selectedProjectIds.contains(item.id)) {
                              _selectedProjectIds.remove(item.id);
                            } else {
                              _selectedProjectIds.add(item.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              if (widget.tags.isNotEmpty) ...[
                Text('标签', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in widget.tags)
                      FilterChip(
                        label: Text('${tag.emoji ?? ''} ${tag.name}'),
                        selected: _selectedTagIds.contains(tag.id),
                        onSelected: (_) {
                          setState(() {
                            if (_selectedTagIds.contains(tag.id)) {
                              _selectedTagIds.remove(tag.id);
                            } else {
                              _selectedTagIds.add(tag.id);
                            }
                          });
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: const Text('保存'),
        ),
      ],
    );
  }

  List<Widget> _formFields() {
    switch (widget.kind) {
      case RecordKind.time:
        return [
          _field('started_at', '开始时间'),
          _field('ended_at', '结束时间'),
          _field('category_code', '类别'),
          _field('efficiency_score', '效率'),
          _field('value_score', '价值'),
          _field('state_score', '状态'),
          _field('ai_assist_ratio', 'AI 占比'),
          _field('note', '备注', maxLines: 3),
        ];
      case RecordKind.income:
        return [
          _field('occurred_on', '发生日期'),
          _field('source_name', '来源'),
          _field('type_code', '类型'),
          _field('amount_yuan', '金额(元)'),
          SwitchListTile(
            value: _isPassive,
            onChanged: (value) => setState(() => _isPassive = value),
            title: const Text('被动收入'),
          ),
          _field('ai_assist_ratio', 'AI 占比'),
          _field('note', '备注', maxLines: 3),
        ];
      case RecordKind.expense:
        return [
          _field('occurred_on', '发生日期'),
          _field('category_code', '类别'),
          _field('amount_yuan', '金额(元)'),
          _field('ai_assist_ratio', 'AI 占比'),
          _field('note', '备注', maxLines: 3),
        ];
      case RecordKind.learning:
        return [
          _field('occurred_on', '发生日期'),
          _field('started_at', '开始时间'),
          _field('ended_at', '结束时间'),
          _field('content', '内容'),
          _field('duration_minutes', '时长(分钟)'),
          _field('application_level_code', '应用等级'),
          _field('efficiency_score', '效率'),
          _field('ai_assist_ratio', 'AI 占比'),
          _field('note', '备注', maxLines: 3),
        ];
    }
  }

  Widget _field(String key, String label, {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: _controllers[key],
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Map<String, TextEditingController> _buildControllers() {
    switch (widget.kind) {
      case RecordKind.time:
        final snapshot = widget.timeSnapshot!;
        return {
          'started_at': TextEditingController(text: _utcToTime(snapshot.startedAt)),
          'ended_at': TextEditingController(text: _utcToTime(snapshot.endedAt)),
          'category_code': TextEditingController(text: snapshot.categoryCode),
          'efficiency_score': TextEditingController(text: _text(snapshot.efficiencyScore)),
          'value_score': TextEditingController(text: _text(snapshot.valueScore)),
          'state_score': TextEditingController(text: _text(snapshot.stateScore)),
          'ai_assist_ratio': TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
      case RecordKind.income:
        final snapshot = widget.incomeSnapshot!;
        return {
          'occurred_on': TextEditingController(text: snapshot.occurredOn),
          'source_name': TextEditingController(text: snapshot.sourceName),
          'type_code': TextEditingController(text: snapshot.typeCode),
          'amount_yuan': TextEditingController(text: _amount(snapshot.amountCents)),
          'ai_assist_ratio': TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
      case RecordKind.expense:
        final snapshot = widget.expenseSnapshot!;
        return {
          'occurred_on': TextEditingController(text: snapshot.occurredOn),
          'category_code': TextEditingController(text: snapshot.categoryCode),
          'amount_yuan': TextEditingController(text: _amount(snapshot.amountCents)),
          'ai_assist_ratio': TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
      case RecordKind.learning:
        final snapshot = widget.learningSnapshot!;
        return {
          'occurred_on': TextEditingController(text: snapshot.occurredOn),
          'started_at': TextEditingController(text: snapshot.startedAt == null ? '' : _utcToTime(snapshot.startedAt!)),
          'ended_at': TextEditingController(text: snapshot.endedAt == null ? '' : _utcToTime(snapshot.endedAt!)),
          'content': TextEditingController(text: snapshot.content),
          'duration_minutes': TextEditingController(text: '${snapshot.durationMinutes}'),
          'application_level_code': TextEditingController(text: snapshot.applicationLevelCode),
          'efficiency_score': TextEditingController(text: _text(snapshot.efficiencyScore)),
          'ai_assist_ratio': TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
    }
  }

  Set<String> _initialProjectIds() {
    switch (widget.kind) {
      case RecordKind.time:
        return widget.timeSnapshot!.projectAllocations.map((item) => item.projectId).toSet();
      case RecordKind.income:
        return widget.incomeSnapshot!.projectAllocations.map((item) => item.projectId).toSet();
      case RecordKind.expense:
        return widget.expenseSnapshot!.projectAllocations.map((item) => item.projectId).toSet();
      case RecordKind.learning:
        return widget.learningSnapshot!.projectAllocations.map((item) => item.projectId).toSet();
    }
  }

  Set<String> _initialTagIds() {
    switch (widget.kind) {
      case RecordKind.time:
        return widget.timeSnapshot!.tagIds.toSet();
      case RecordKind.income:
        return widget.incomeSnapshot!.tagIds.toSet();
      case RecordKind.expense:
        return widget.expenseSnapshot!.tagIds.toSet();
      case RecordKind.learning:
        return widget.learningSnapshot!.tagIds.toSet();
    }
  }

  RecordEditorResult _buildResult() {
    final projectAllocations = _selectedProjectIds
        .map((id) => {'project_id': id, 'weight_ratio': 1.0})
        .toList();
    final tagIds = _selectedTagIds.toList();
    switch (widget.kind) {
      case RecordKind.time:
        return RecordEditorResult(
          method: 'update_time_record',
          payload: {
            'record_id': widget.recordId,
            'input': {
              'user_id': widget.userId,
              'started_at': _toUtcTimestamp(_controllers['started_at']!.text),
              'ended_at': _toUtcTimestamp(_controllers['ended_at']!.text),
              'category_code': _controllers['category_code']!.text,
              'efficiency_score': _intValue('efficiency_score'),
              'value_score': _intValue('value_score'),
              'state_score': _intValue('state_score'),
              'ai_assist_ratio': _intValue('ai_assist_ratio'),
              'note': _nullable('note'),
              'source': 'manual',
              'is_public_pool': false,
              'project_allocations': projectAllocations,
              'tag_ids': tagIds,
            },
          },
        );
      case RecordKind.income:
        return RecordEditorResult(
          method: 'update_income_record',
          payload: {
            'record_id': widget.recordId,
            'input': {
              'user_id': widget.userId,
              'occurred_on': _controllers['occurred_on']!.text,
              'source_name': _controllers['source_name']!.text,
              'type_code': _controllers['type_code']!.text,
              'amount_cents': _amountToCents(_controllers['amount_yuan']!.text),
              'is_passive': _isPassive,
              'ai_assist_ratio': _intValue('ai_assist_ratio'),
              'note': _nullable('note'),
              'source': 'manual',
              'is_public_pool': false,
              'project_allocations': projectAllocations,
              'tag_ids': tagIds,
            },
          },
        );
      case RecordKind.expense:
        return RecordEditorResult(
          method: 'update_expense_record',
          payload: {
            'record_id': widget.recordId,
            'input': {
              'user_id': widget.userId,
              'occurred_on': _controllers['occurred_on']!.text,
              'category_code': _controllers['category_code']!.text,
              'amount_cents': _amountToCents(_controllers['amount_yuan']!.text),
              'ai_assist_ratio': _intValue('ai_assist_ratio'),
              'note': _nullable('note'),
              'source': 'manual',
              'project_allocations': projectAllocations,
              'tag_ids': tagIds,
            },
          },
        );
      case RecordKind.learning:
        return RecordEditorResult(
          method: 'update_learning_record',
          payload: {
            'record_id': widget.recordId,
            'input': {
              'user_id': widget.userId,
              'occurred_on': _controllers['occurred_on']!.text,
              'started_at': _controllers['started_at']!.text.isEmpty ? null : _toUtcTimestamp(_controllers['started_at']!.text),
              'ended_at': _controllers['ended_at']!.text.isEmpty ? null : _toUtcTimestamp(_controllers['ended_at']!.text),
              'content': _controllers['content']!.text,
              'duration_minutes': int.parse(_controllers['duration_minutes']!.text),
              'application_level_code': _controllers['application_level_code']!.text,
              'efficiency_score': _intValue('efficiency_score'),
              'ai_assist_ratio': _intValue('ai_assist_ratio'),
              'note': _nullable('note'),
              'source': 'manual',
              'is_public_pool': false,
              'project_allocations': projectAllocations,
              'tag_ids': tagIds,
            },
          },
        );
    }
  }

  String _text(int? value) => value?.toString() ?? '';

  String _amount(int cents) => (cents / 100).toStringAsFixed(2);

  int? _intValue(String key) {
    final raw = _controllers[key]!.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  String? _nullable(String key) {
    final raw = _controllers[key]!.text.trim();
    return raw.isEmpty ? null : raw;
  }

  int _amountToCents(String value) => (double.parse(value.trim()) * 100).round();

  String _utcToTime(String value) {
    final dateTime = DateTime.parse(value).toLocal();
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _toUtcTimestamp(String time) {
    final normalized = time.length == 5 ? '${time.trim()}:00' : time.trim();
    final local = DateTime.parse('${widget.anchorDate} $normalized');
    return local.toUtc().toIso8601String();
  }
}
