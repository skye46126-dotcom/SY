import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/project_models.dart';
import '../../models/record_models.dart';
import '../../models/review_models.dart';
import '../../models/tag_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/glass_panel.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';
import 'widgets/record_editor_dialog.dart';

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({
    super.key,
    required this.anchorDate,
  });

  final String anchorDate;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class DayDetailData {
  const DayDetailData({
    required this.records,
    required this.reviewNotes,
  });

  final List<RecentRecordItem> records;
  final List<ReviewNoteModel> reviewNotes;
}

class _DayDetailPageState extends State<DayDetailPage> {
  ViewState<DayDetailData> _state = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    setState(() {
      _state = ViewState.loading();
    });
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final service = LifeOsScope.of(context);
      final records = await service.getRecordsForDate(
        userId: runtime.userId,
        date: widget.anchorDate,
        timezone: runtime.timezone,
      );
      final reviewNotes = await service.listReviewNotesForDate(
        userId: runtime.userId,
        occurredOn: widget.anchorDate,
      );
      if (!mounted) return;
      setState(() {
        _state = ViewState.ready(
          DayDetailData(records: records, reviewNotes: reviewNotes),
        );
      });
    } on UnimplementedError {
      if (!mounted) return;
      setState(() {
        _state = ViewState.unavailable('按日明细接口尚未接入 Rust。');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = ViewState.error(error.toString());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _state.data;
    final records = data?.records ?? const <RecentRecordItem>[];
    final reviewNotes = data?.reviewNotes ?? const <ReviewNoteModel>[];
    return ModulePage(
      title: '日详情',
      subtitle: widget.anchorDate,
      children: [
        _DayActionRow(
          onAddRecord: _openHistoricalCapture,
          onAddReviewNote: _createReviewNote,
          onPickDate: _pickDate,
        ),
        if (_state.status == ViewStatus.loading)
          const SectionLoadingView(label: '正在读取当日记录'),
        if (_state.hasData) ...[
          _DaySummaryHero(
            anchorDate: widget.anchorDate,
            records: records,
          ),
          SectionCard(
            eyebrow: 'Records',
            title: '当日流水',
            child: records.isEmpty
                ? const SectionMessageView(
                    icon: Icons.calendar_month_outlined,
                    title: '当天没有记录',
                    description: '可以从上方新增记录补录这一天。',
                  )
                : Column(
                    children: [
                      for (var index = 0; index < records.length; index++) ...[
                        if (index > 0) const SizedBox(height: 12),
                        _DayRecordCard(
                          record: records[index],
                          onEdit: () => _editRecord(records[index]),
                          onDelete: () => _deleteRecord(records[index]),
                        ),
                      ],
                    ],
                  ),
          ),
          SectionCard(
            eyebrow: 'Review Notes',
            title: '复盘素材',
            child: reviewNotes.isEmpty
                ? const SectionMessageView(
                    icon: Icons.rate_review_outlined,
                    title: '暂无复盘素材',
                    description: '可以从上方新增素材补上当天反思、风险或上下文。',
                  )
                : Column(
                    children: [
                      for (var index = 0;
                          index < reviewNotes.length;
                          index++) ...[
                        if (index > 0) const SizedBox(height: 12),
                        _ReviewNoteCard(
                          note: reviewNotes[index],
                          onEdit: () => _editReviewNote(reviewNotes[index]),
                          onDelete: () => _deleteReviewNote(reviewNotes[index]),
                        ),
                      ],
                    ],
                  ),
          ),
        ] else if (_state.status != ViewStatus.loading)
          SectionCard(
            eyebrow: 'Records',
            title: '当日流水',
            child: SectionMessageView(
              icon: Icons.calendar_month_outlined,
              title: '当日明细暂不可用',
              description: _state.message ?? '请稍后重试。',
            ),
          ),
      ],
    );
  }

  Future<void> _openHistoricalCapture() async {
    final changed = await Navigator.of(context).pushNamed<bool>(
      '/capture?type=time&mode=manual&contextDate=${Uri.encodeQueryComponent(widget.anchorDate)}&returnTo=day',
    );
    if (!mounted || changed != true) {
      return;
    }
    await _load();
  }

  Future<void> _pickDate() async {
    final initialDate = DateTime.tryParse(widget.anchorDate) ?? DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (selected == null || !mounted) {
      return;
    }
    final next = _formatDate(selected);
    if (next == widget.anchorDate) {
      return;
    }
    Navigator.of(context).pushReplacementNamed('/day/$next');
  }

  Future<void> _createReviewNote() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final result = await ReviewNoteEditorDialog.show(
      context,
      userId: runtime.userId,
      anchorDate: widget.anchorDate,
    );
    final input = result?.input;
    if (input == null) {
      return;
    }
    await service.createReviewNote(input: input);
    if (!mounted) return;
    await _load();
  }

  Future<void> _editReviewNote(ReviewNoteModel note) async {
    final service = LifeOsScope.of(context);
    final result = await ReviewNoteEditorDialog.show(
      context,
      userId: note.userId,
      anchorDate: widget.anchorDate,
      note: note,
    );
    if (result == null) {
      return;
    }
    if (result.delete) {
      await _deleteReviewNote(note, confirm: false);
      return;
    }
    final input = result.input;
    if (input == null) {
      return;
    }
    await service.updateReviewNote(
      noteId: note.id,
      input: input,
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _deleteReviewNote(
    ReviewNoteModel note, {
    bool confirm = true,
  }) async {
    final service = LifeOsScope.of(context);
    if (confirm) {
      final confirmed = await _confirmDeleteReviewNote();
      if (confirmed != true) {
        return;
      }
    }
    await service.deleteReviewNote(
      userId: note.userId,
      noteId: note.id,
    );
    if (!mounted) return;
    await _load();
  }

  Future<bool?> _confirmDeleteReviewNote() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除素材'),
        content: const Text('删除后，这条素材不会出现在日详情和复盘报告中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(RecentRecordItem record) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).invokeRaw(
      method: 'delete_record',
      payload: {
        'user_id': runtime.userId,
        'record_id': record.recordId,
        'kind': record.kind.name,
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _editRecord(RecentRecordItem record) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final method = switch (record.kind) {
      RecordKind.time => 'get_time_record_snapshot',
      RecordKind.income => 'get_income_record_snapshot',
      RecordKind.expense => 'get_expense_record_snapshot',
    };
    final snapshot = await service.invokeRaw(
      method: method,
      payload: {
        'user_id': runtime.userId,
        'record_id': record.recordId,
      },
    );
    if (snapshot == null || !mounted) return;
    final projectOptions = await service.getProjectOptions(
      userId: runtime.userId,
      includeDone: true,
    );
    final tags = await service.getTags(userId: runtime.userId);
    if (!mounted) return;

    final typedProjectOptions = projectOptions.cast<ProjectOption>();
    final typedTags = tags.cast<TagModel>();
    final dialog = switch (record.kind) {
      RecordKind.time => RecordEditorDialog.time(
          recordId: record.recordId,
          userId: runtime.userId,
          anchorDate: widget.anchorDate,
          timeSnapshot: TimeRecordSnapshotModel.fromJson(
              snapshot.cast<String, dynamic>()),
          projectOptions: typedProjectOptions,
          tags: typedTags,
        ),
      RecordKind.income => RecordEditorDialog.income(
          recordId: record.recordId,
          userId: runtime.userId,
          anchorDate: widget.anchorDate,
          incomeSnapshot: IncomeRecordSnapshotModel.fromJson(
              snapshot.cast<String, dynamic>()),
          projectOptions: typedProjectOptions,
          tags: typedTags,
        ),
      RecordKind.expense => RecordEditorDialog.expense(
          recordId: record.recordId,
          userId: runtime.userId,
          anchorDate: widget.anchorDate,
          expenseSnapshot: ExpenseRecordSnapshotModel.fromJson(
              snapshot.cast<String, dynamic>()),
          projectOptions: typedProjectOptions,
          tags: typedTags,
        ),
    };
    final result = await RecordEditorDialog.show(context, dialog: dialog);
    if (result == null) return;
    await service.invokeRaw(method: result.method, payload: result.payload);
    if (!mounted) return;
    await _load();
  }
}

class _DayActionRow extends StatelessWidget {
  const _DayActionRow({
    required this.onAddRecord,
    required this.onAddReviewNote,
    required this.onPickDate,
  });

  final VoidCallback onAddRecord;
  final VoidCallback onAddReviewNote;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton(
          onPressed: onAddRecord,
          child: const Text('新增时间记录'),
        ),
        OutlinedButton(
          onPressed: onAddReviewNote,
          child: const Text('新增复盘素材'),
        ),
        OutlinedButton(
          onPressed: onPickDate,
          child: const Text('切换日期'),
        ),
      ],
    );
  }
}

class _DaySummaryHero extends StatelessWidget {
  const _DaySummaryHero({
    required this.anchorDate,
    required this.records,
  });

  final String anchorDate;
  final List<RecentRecordItem> records;

  @override
  Widget build(BuildContext context) {
    int countFor(RecordKind kind) =>
        records.where((item) => item.kind == kind).length;
    final latest =
        records.isEmpty ? '' : _formatOccurredAt(records.first.occurredAt);
    final earliest =
        records.isEmpty ? '' : _formatOccurredAt(records.last.occurredAt);
    final timeSpan = latest.isEmpty && earliest.isEmpty
        ? ''
        : latest == earliest
            ? latest
            : '$earliest - $latest';

    return GlassPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Records',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Text(
            '当日流水',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '共 ${records.length} 条记录${timeSpan.isEmpty ? '' : ' · 时间窗口 $timeSpan'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(
                label: '日期 $anchorDate',
                color: const Color(0xFF475569),
              ),
              _SummaryPill(
                label: '时间 ${countFor(RecordKind.time)}',
                color: _kindColor(RecordKind.time),
              ),
              _SummaryPill(
                label: '收入 ${countFor(RecordKind.income)}',
                color: _kindColor(RecordKind.income),
              ),
              _SummaryPill(
                label: '支出 ${countFor(RecordKind.expense)}',
                color: _kindColor(RecordKind.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRecordCard extends StatelessWidget {
  const _DayRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final RecentRecordItem record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kindColor = _kindColor(record.kind);
    final detail = record.detail.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryPill(
                      label: _kindLabel(record.kind),
                      color: kindColor,
                    ),
                    _SummaryPill(
                      label: _formatOccurredAt(record.occurredAt),
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _displayTitle(record),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _kindEmptyDetail(record.kind),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReviewNoteCard extends StatelessWidget {
  const _ReviewNoteCard({
    required this.note,
    required this.onEdit,
    required this.onDelete,
  });

  final ReviewNoteModel note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final linked = [
      if ((note.source).trim().isNotEmpty) _sourceLabel(note.source),
      if ((note.linkedRecordKind ?? '').trim().isNotEmpty)
        '关联 ${note.linkedRecordKind}',
    ].join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryPill(
                      label: _reviewNoteTypeLabel(note.noteType),
                      color: const Color(0xFF64748B),
                    ),
                    _SummaryPill(
                      label: _visibilityLabel(note.visibility),
                      color: const Color(0xFF475569),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            note.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                ),
          ),
          const SizedBox(height: 8),
          Text(note.content, style: Theme.of(context).textTheme.bodyLarge),
          if (linked.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(linked, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class ReviewNoteEditorDialog extends StatefulWidget {
  const ReviewNoteEditorDialog._({
    required this.userId,
    required this.anchorDate,
    this.note,
  });

  final String userId;
  final String anchorDate;
  final ReviewNoteModel? note;

  static Future<ReviewNoteEditorResult?> show(
    BuildContext context, {
    required String userId,
    required String anchorDate,
    ReviewNoteModel? note,
  }) {
    return showDialog<ReviewNoteEditorResult>(
      context: context,
      builder: (context) => ReviewNoteEditorDialog._(
        userId: userId,
        anchorDate: anchorDate,
        note: note,
      ),
    );
  }

  @override
  State<ReviewNoteEditorDialog> createState() => _ReviewNoteEditorDialogState();
}

class ReviewNoteEditorResult {
  const ReviewNoteEditorResult.save(this.input) : delete = false;

  const ReviewNoteEditorResult.delete()
      : input = null,
        delete = true;

  final ReviewNoteMutationInput? input;
  final bool delete;
}

class _ReviewNoteEditorDialogState extends State<ReviewNoteEditorDialog> {
  late final TextEditingController _dateController;
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _rawTextController;
  String _noteType = 'reflection';
  String _visibility = 'normal';

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    _dateController = TextEditingController(
      text: note?.occurredOn.trim().isNotEmpty == true
          ? note!.occurredOn
          : widget.anchorDate,
    );
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _rawTextController = TextEditingController(text: note?.rawText ?? '');
    _noteType = _normalizeOption(
      note?.noteType,
      _reviewNoteTypeOptions,
      fallback: 'reflection',
    );
    _visibility = _normalizeOption(
      note?.visibility,
      _reviewNoteVisibilityOptions,
      fallback: 'normal',
    );
  }

  @override
  void dispose() {
    _dateController.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _rawTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.note == null ? '新增复盘素材' : '编辑复盘素材'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: '发生日期 YYYY-MM-DD'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _noteType,
                decoration: const InputDecoration(labelText: '类型'),
                items: [
                  for (final option in _reviewNoteTypeOptions)
                    DropdownMenuItem(
                      value: option,
                      child: Text(_reviewNoteTypeLabel(option)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _noteType = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: '标题'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: '内容'),
                minLines: 3,
                maxLines: 8,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _visibility,
                decoration: const InputDecoration(labelText: '可见性'),
                items: [
                  for (final option in _reviewNoteVisibilityOptions)
                    DropdownMenuItem(
                      value: option,
                      child: Text(_visibilityLabel(option)),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _visibility = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rawTextController,
                decoration: const InputDecoration(labelText: '原始文本'),
                minLines: 2,
                maxLines: 5,
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.note != null)
          TextButton(
            onPressed: _delete,
            child: const Text('删除'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _submit() {
    final date = _dateController.text.trim();
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (date.isEmpty || title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('日期、标题和内容不能为空')),
      );
      return;
    }
    Navigator.of(context).pop(
      ReviewNoteEditorResult.save(
        ReviewNoteMutationInput(
          userId: widget.userId,
          occurredOn: date,
          noteType: _noteType,
          title: title,
          content: content,
          source: widget.note?.source ?? 'manual',
          visibility: _visibility,
          confidence: widget.note?.confidence,
          rawText: _nullableText(_rawTextController.text),
          linkedRecordKind: widget.note?.linkedRecordKind,
          linkedRecordId: widget.note?.linkedRecordId,
        ),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除素材'),
        content: const Text('删除后，这条素材不会出现在日详情和复盘报告中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    Navigator.of(context).pop(const ReviewNoteEditorResult.delete());
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

String _displayTitle(RecentRecordItem record) {
  final title = record.title.trim();
  if (title.isEmpty) {
    return '${_kindLabel(record.kind)}记录';
  }
  return title;
}

String _kindLabel(RecordKind kind) {
  return switch (kind) {
    RecordKind.time => '时间',
    RecordKind.income => '收入',
    RecordKind.expense => '支出',
  };
}

String _kindEmptyDetail(RecordKind kind) {
  return switch (kind) {
    RecordKind.time => '没有补充备注',
    RecordKind.income => '没有补充来源说明',
    RecordKind.expense => '没有补充支出说明',
  };
}

Color _kindColor(RecordKind kind) {
  return switch (kind) {
    RecordKind.time => const Color(0xFF2563EB),
    RecordKind.income => const Color(0xFF059669),
    RecordKind.expense => const Color(0xFFDC2626),
  };
}

const _reviewNoteTypeOptions = [
  'reflection',
  'feeling',
  'plan',
  'idea',
  'context',
  'ai_usage',
  'risk',
  'summary',
];

const _reviewNoteVisibilityOptions = [
  'compact',
  'normal',
  'hidden',
];

String _reviewNoteTypeLabel(String value) {
  return switch (value) {
    'reflection' => '反思',
    'feeling' => '感受',
    'plan' => '计划',
    'idea' => '想法',
    'context' => '上下文',
    'ai_usage' => 'AI',
    'risk' => '风险',
    'summary' => '总结',
    _ => value,
  };
}

String _visibilityLabel(String value) {
  return switch (value) {
    'compact' => '紧凑',
    'normal' => '正常',
    'hidden' => '隐藏',
    _ => value,
  };
}

String _sourceLabel(String value) {
  return switch (value) {
    'manual' => '手动',
    'ai_capture' => 'AI 捕获',
    'import' => '导入',
    _ => value,
  };
}

String _normalizeOption(
  String? value,
  List<String> options, {
  required String fallback,
}) {
  final normalized = value?.trim() ?? '';
  if (options.contains(normalized)) {
    return normalized;
  }
  return fallback;
}

String? _nullableText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

String _formatDate(DateTime value) {
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String _formatOccurredAt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '未标注时间';
  }
  if (!trimmed.contains('T') &&
      trimmed.length == 10 &&
      trimmed[4] == '-' &&
      trimmed[7] == '-') {
    return trimmed.substring(5);
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (trimmed.length >= 16 && trimmed.contains('T')) {
    final segments = trimmed.split('T');
    if (segments.length == 2 && segments[1].length >= 5) {
      return segments[1].substring(0, 5);
    }
  }
  return trimmed;
}
