import 'package:flutter/material.dart';

import '../../../app/app.dart';
import '../../../models/config_models.dart';
import '../../../models/project_models.dart';
import '../../../models/record_models.dart';
import '../../../models/tag_models.dart';
import '../../../shared/view_state.dart';
import '../../../shared/widgets/record_editor_surface.dart';
import '../../../shared/widgets/safe_pop.dart';
import '../../../shared/widgets/state_views.dart';
import '../../capture/capture_controller.dart';
import '../../capture/widgets/record_form_section.dart';

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
        kind = RecordKind.expense;

  final String recordId;
  final String userId;
  final String anchorDate;
  final RecordKind kind;
  final TimeRecordSnapshotModel? timeSnapshot;
  final IncomeRecordSnapshotModel? incomeSnapshot;
  final ExpenseRecordSnapshotModel? expenseSnapshot;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;

  static Future<RecordEditorResult?> show(
    BuildContext context, {
    required RecordEditorDialog dialog,
  }) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    return showModalBottomSheet<RecordEditorResult>(
      context: rootContext,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (context) => FractionallySizedBox(
        heightFactor: 0.94,
        child: dialog,
      ),
    );
  }

  @override
  State<RecordEditorDialog> createState() => _RecordEditorDialogState();
}

class _RecordEditorDialogState extends State<RecordEditorDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Set<String> _selectedProjectIds;
  late final Set<String> _selectedTagIds;
  ViewState<CaptureMetadataModel> _metadataState = ViewState.initial();

  @override
  void initState() {
    super.initState();
    _controllers = _buildControllers();
    _selectedProjectIds = _initialProjectIds();
    _selectedTagIds = _initialTagIds();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMetadata());
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
    final captureType = _captureTypeFor(widget.kind);
    return RecordEditorSurface(
      title: '编辑${widget.kind.label}记录',
      subtitle: widget.anchorDate,
      onCancel: () => safePop<void>(context),
      onSave: () => safePop(context, _buildResult()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_metadataState.status == ViewStatus.loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SectionLoadingView(label: '正在读取维度选项'),
            ),
          if (_metadataState.status == ViewStatus.error)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '维度元数据读取失败',
                description: _metadataState.message ?? '请稍后重试。',
              ),
            ),
          AdaptiveRecordForm(
            fields: captureFieldDefinitionsFor(captureType),
            controllers: _controllers,
            anchorDate: widget.anchorDate,
            optionResolver: _optionsFor,
            sourceSuggestions:
                _metadataState.data?.incomeSourceSuggestions ?? const [],
          ),
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
    );
  }

  Future<void> _loadMetadata() async {
    setState(() => _metadataState = ViewState.loading());
    try {
      final data = await LifeOsScope.of(context).invokeRaw(
        method: 'get_capture_metadata',
        payload: {'user_id': widget.userId},
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _metadataState = ViewState.ready(
          CaptureMetadataModel.fromJson((data as Map).cast<String, dynamic>()),
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _metadataState = ViewState.error(error.toString()));
    }
  }

  List<DimensionOptionModel> _optionsFor(CaptureFieldOptions key) {
    final metadata = _metadataState.data;
    if (metadata == null) {
      return const [];
    }
    return switch (key) {
      CaptureFieldOptions.timeCategory => metadata.timeCategories,
      CaptureFieldOptions.incomeType => metadata.incomeTypes,
      CaptureFieldOptions.expenseCategory => metadata.expenseCategories,
      CaptureFieldOptions.learningLevel => metadata.learningLevels,
      CaptureFieldOptions.projectStatus => metadata.projectStatuses,
    };
  }

  Map<String, TextEditingController> _buildControllers() {
    switch (widget.kind) {
      case RecordKind.time:
        final snapshot = widget.timeSnapshot!;
        return {
          'occurred_on': TextEditingController(text: snapshot.occurredOn),
          'started_at': TextEditingController(
            text: snapshot.startedAt == null
                ? ''
                : _utcToTime(snapshot.startedAt!),
          ),
          'ended_at': TextEditingController(
            text: snapshot.endedAt == null ? '' : _utcToTime(snapshot.endedAt!),
          ),
          'duration_minutes':
              TextEditingController(text: '${snapshot.durationMinutes}'),
          'category_code': TextEditingController(text: snapshot.categoryCode),
          'content': TextEditingController(text: snapshot.content),
          'application_level_code':
              TextEditingController(text: snapshot.applicationLevelCode ?? ''),
          'efficiency_score':
              TextEditingController(text: _text(snapshot.efficiencyScore)),
          'value_score':
              TextEditingController(text: _text(snapshot.valueScore)),
          'state_score':
              TextEditingController(text: _text(snapshot.stateScore)),
          'ai_assist_ratio':
              TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
      case RecordKind.income:
        final snapshot = widget.incomeSnapshot!;
        return {
          'occurred_on': TextEditingController(text: snapshot.occurredOn),
          'source_name': TextEditingController(text: snapshot.sourceName),
          'type_code': TextEditingController(text: snapshot.typeCode),
          'amount_yuan':
              TextEditingController(text: _amount(snapshot.amountCents)),
          'is_passive':
              TextEditingController(text: snapshot.isPassive.toString()),
          'ai_assist_ratio':
              TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
      case RecordKind.expense:
        final snapshot = widget.expenseSnapshot!;
        return {
          'occurred_on': TextEditingController(text: snapshot.occurredOn),
          'category_code': TextEditingController(text: snapshot.categoryCode),
          'amount_yuan':
              TextEditingController(text: _amount(snapshot.amountCents)),
          'ai_assist_ratio':
              TextEditingController(text: _text(snapshot.aiAssistRatio)),
          'note': TextEditingController(text: snapshot.note ?? ''),
        };
    }
  }

  Set<String> _initialProjectIds() {
    switch (widget.kind) {
      case RecordKind.time:
        return widget.timeSnapshot!.projectAllocations
            .map((item) => item.projectId)
            .toSet();
      case RecordKind.income:
        return widget.incomeSnapshot!.projectAllocations
            .map((item) => item.projectId)
            .toSet();
      case RecordKind.expense:
        return widget.expenseSnapshot!.projectAllocations
            .map((item) => item.projectId)
            .toSet();
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
              'occurred_on': _controllers['occurred_on']!.text,
              'started_at':
                  _optionalUtcTimestamp(_controllers['started_at']!.text),
              'ended_at': _optionalUtcTimestamp(_controllers['ended_at']!.text),
              'duration_minutes': _intValue('duration_minutes'),
              'category_code': _controllers['category_code']!.text,
              'content': _controllers['content']!.text,
              'application_level_code': _nullable('application_level_code'),
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
              'is_passive':
                  _controllers['is_passive']!.text.trim().toLowerCase() ==
                      'true',
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
    }
  }

  String _text(int? value) => value?.toString() ?? '';

  String _amount(int cents) => (cents / 100).toStringAsFixed(2);

  int? _intValue(String key) {
    final raw = _controllers[key]!.text.trim();
    if (raw.isEmpty) {
      return null;
    }
    return int.tryParse(raw);
  }

  String? _nullable(String key) {
    final raw = _controllers[key]!.text.trim();
    return raw.isEmpty ? null : raw;
  }

  int _amountToCents(String value) =>
      (double.parse(value.trim()) * 100).round();

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

  String? _optionalUtcTimestamp(String time) {
    if (time.trim().isEmpty) {
      return null;
    }
    return _toUtcTimestamp(time);
  }

  CaptureType _captureTypeFor(RecordKind kind) {
    switch (kind) {
      case RecordKind.time:
        return CaptureType.time;
      case RecordKind.income:
        return CaptureType.income;
      case RecordKind.expense:
        return CaptureType.expense;
    }
  }
}
