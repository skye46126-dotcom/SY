import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/config_models.dart';
import '../../../models/project_models.dart';
import '../../../models/tag_models.dart';
import '../../../shared/view_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../../../shared/widgets/state_views.dart';
import '../../../shared/widgets/tag_selector.dart';
import '../capture_controller.dart';
import 'record_form_section.dart';

class AiCaptureSection extends StatelessWidget {
  const AiCaptureSection({
    super.key,
    required this.aiState,
    required this.inputController,
    required this.inputFocusNode,
    required this.autofocusInput,
    required this.parseMode,
    required this.onParseModeChanged,
    required this.onParsePressed,
    required this.onDraftChanged,
    required this.onCommitPressed,
    required this.optionResolver,
    required this.sourceSuggestions,
    required this.projectOptions,
    required this.tags,
  });

  final ViewState<Map<String, Object?>> aiState;
  final TextEditingController inputController;
  final FocusNode inputFocusNode;
  final bool autofocusInput;
  final AiCaptureParseMode parseMode;
  final ValueChanged<AiCaptureParseMode> onParseModeChanged;
  final VoidCallback onParsePressed;
  final ValueChanged<Map<String, Object?>> onDraftChanged;
  final VoidCallback onCommitPressed;
  final List<DimensionOptionModel> Function(CaptureFieldOptions key)
      optionResolver;
  final List<String> sourceSuggestions;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'AI Capture',
      title: '自然语言录入',
      trailing: ElevatedButton.icon(
        onPressed: onParsePressed,
        icon: const Icon(Icons.auto_awesome_rounded, size: 18),
        label: const Text('解析草稿'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: inputController,
            focusNode: inputFocusNode,
            autofocus: autofocusInput,
            minLines: 6,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: '输入自然语言',
              hintText: '输入当天原始记录，解析后逐条确认和修改。',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SegmentedControl<AiCaptureParseMode>(
                  value: parseMode,
                  onChanged: onParseModeChanged,
                  options: const [
                    SegmentedControlOption(
                      value: AiCaptureParseMode.auto,
                      label: '自动',
                    ),
                    SegmentedControlOption(
                      value: AiCaptureParseMode.fast,
                      label: '快速',
                    ),
                    SegmentedControlOption(
                      value: AiCaptureParseMode.deep,
                      label: '深度',
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  _modeHelp(parseMode),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          switch (aiState.status) {
            ViewStatus.loading => const _LlmParsingView(),
            ViewStatus.data => _DraftListPreview(
                envelope: aiState.data!,
                onChanged: onDraftChanged,
                onCommitPressed: onCommitPressed,
                optionResolver: optionResolver,
                sourceSuggestions: sourceSuggestions,
                projectOptions: projectOptions,
                tags: tags,
              ),
            ViewStatus.empty => SectionMessageView(
                icon: Icons.drafts_rounded,
                title: '没有生成草稿',
                description: aiState.message ?? 'AI 返回为空。',
              ),
            ViewStatus.unavailable => SectionMessageView(
                icon: Icons.link_off_rounded,
                title: 'AI 接口未接入',
                description: aiState.message ?? '等待 Rust AI service 接入。',
              ),
            ViewStatus.error => SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '解析失败',
                description: aiState.message ?? '请稍后重试。',
              ),
            _ => const SectionMessageView(
                icon: Icons.edit_note_rounded,
                title: '先输入，再确认',
                description: '解析结果会拆成可编辑条目，引用内容不会直接入库。',
              ),
          },
        ],
      ),
    );
  }
}

String _modeHelp(AiCaptureParseMode mode) {
  return switch (mode) {
    AiCaptureParseMode.auto => '自动判断是否需要脏文本清洗。',
    AiCaptureParseMode.fast => '一次 AI 解析，适合清晰短文本。',
    AiCaptureParseMode.deep => '先清洗重排，再结构化解析。',
  };
}

class _LlmParsingView extends StatefulWidget {
  const _LlmParsingView();

  @override
  State<_LlmParsingView> createState() => _LlmParsingViewState();
}

class _LlmParsingViewState extends State<_LlmParsingView> {
  static const _messages = [
    '正在调用 LLM 理解原始记录',
    '正在抽取时间、金额、项目和标签',
    '正在执行规则补全与校验',
    '正在生成可确认草稿',
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                _messages[_index],
                key: ValueKey(_index),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftListPreview extends StatelessWidget {
  const _DraftListPreview({
    required this.envelope,
    required this.onChanged,
    required this.onCommitPressed,
    required this.optionResolver,
    required this.sourceSuggestions,
    required this.projectOptions,
    required this.tags,
  });

  final Map<String, Object?> envelope;
  final ValueChanged<Map<String, Object?>> onChanged;
  final VoidCallback onCommitPressed;
  final List<DimensionOptionModel> Function(CaptureFieldOptions key)
      optionResolver;
  final List<String> sourceSuggestions;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;

  @override
  Widget build(BuildContext context) {
    final items = ((envelope['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final readyItems = items.where(_isCommitReady).toList();
    final needsReviewItems = items.where(_isNeedsReview).toList();
    final blockedItems = items.where(_isBlocked).toList();
    final notes = ((envelope['review_notes'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .where(
            (item) => (item['visibility']?.toString() ?? 'compact') != 'hidden')
        .toList();
    final ignored = ((envelope['ignored_context'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final warnings = ((envelope['warnings'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .toList();
    final committableCount = items.where(_isSubmittable).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'AI 草稿 · 可入库 ${readyItems.length} 条 · 需确认 ${needsReviewItems.length} 条 · 阻塞 ${blockedItems.length} 条 · 复盘素材 ${notes.length} 条',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            FilledButton.icon(
              onPressed: committableCount == 0 && notes.isEmpty
                  ? null
                  : onCommitPressed,
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('提交可入库/已确认'),
            ),
          ],
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 8),
          _WarningBox(warnings: warnings),
        ],
        const SizedBox(height: 12),
        if (readyItems.isNotEmpty) ...[
          _SectionHeader(
            icon: Icons.task_alt_rounded,
            label: '可入库事件',
            count: readyItems.length,
          ),
          const SizedBox(height: 8),
        ],
        for (final item in readyItems) ...[
          _DraftItemCard(
            index: items.indexOf(item),
            item: item,
            optionResolver: optionResolver,
            sourceSuggestions: sourceSuggestions,
            projectOptions: projectOptions,
            tags: tags,
            onConvertToNote: () => _moveItemToReviewNote(items.indexOf(item)),
            onIgnore: () => _moveItemToIgnored(items.indexOf(item)),
            onChanged: (nextItem) =>
                _replaceItem(items.indexOf(item), nextItem),
          ),
          const SizedBox(height: 10),
        ],
        if (needsReviewItems.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _SectionHeader(
                  icon: Icons.rule_rounded,
                  label: '需要确认',
                  count: needsReviewItems.length,
                ),
              ),
              TextButton.icon(
                onPressed: () => _approveAllNeedsReview(needsReviewItems),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('一键通过'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final item in needsReviewItems) ...[
            _DraftItemCard(
              index: items.indexOf(item),
              item: item,
              optionResolver: optionResolver,
              sourceSuggestions: sourceSuggestions,
              projectOptions: projectOptions,
              tags: tags,
              onApprovalChanged: (allowed) =>
                  _setItemApproval(items.indexOf(item), allowed),
              onConvertToNote: () => _moveItemToReviewNote(items.indexOf(item)),
              onIgnore: () => _moveItemToIgnored(items.indexOf(item)),
              onChanged: (nextItem) =>
                  _replaceItem(items.indexOf(item), nextItem),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (blockedItems.isNotEmpty) ...[
          const SizedBox(height: 4),
          _SectionHeader(
            icon: Icons.block_rounded,
            label: '阻塞条目',
            count: blockedItems.length,
          ),
          const SizedBox(height: 8),
          for (final item in blockedItems) ...[
            _DraftItemCard(
              index: items.indexOf(item),
              item: item,
              optionResolver: optionResolver,
              sourceSuggestions: sourceSuggestions,
              projectOptions: projectOptions,
              tags: tags,
              onConvertToNote: () => _moveItemToReviewNote(items.indexOf(item)),
              onChanged: (nextItem) =>
                  _replaceItem(items.indexOf(item), nextItem),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 4),
          ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.notes_rounded),
            title: Text('复盘素材 ${notes.length} 条'),
            children: [
              for (final note in notes) ...[
                _ReviewNoteTile(
                  note: note,
                  onConvertToIgnored: () =>
                      _moveReviewNoteToIgnored(notes.indexOf(note)),
                  onConvertToEvent: () =>
                      _moveReviewNoteToEvent(context, notes.indexOf(note)),
                  onChanged: (nextNote) =>
                      _replaceReviewNote(notes.indexOf(note), nextNote),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
        if (ignored.isNotEmpty) ...[
          const SizedBox(height: 4),
          ExpansionTile(
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            leading: const Icon(Icons.visibility_off_rounded),
            title: Text('已忽略上下文 ${ignored.length} 条'),
            children: [
              for (final item in ignored) ...[
                _IgnoredContextTile(
                  item: item,
                  onConvertToNote: () =>
                      _moveIgnoredToReviewNote(ignored.indexOf(item)),
                  onConvertToEvent: () =>
                      _moveIgnoredToEvent(context, ignored.indexOf(item)),
                ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ],
      ],
    );
  }

  void _replaceItem(int index, Map<String, Object?> nextItem) {
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextItems = ((envelope['items'] as List?) ?? const [])
        .map((item) => item is Map ? Map<String, Object?>.from(item) : item)
        .toList();
    nextItems[index] = nextItem;
    nextEnvelope['items'] = nextItems;
    onChanged(nextEnvelope);
  }

  void _setItemApproval(int index, bool allowed) {
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextItems = ((envelope['items'] as List?) ?? const [])
        .map((item) => item is Map ? Map<String, Object?>.from(item) : item)
        .toList();
    final current = Map<String, Object?>.from(
      (nextItems[index] as Map).cast<String, Object?>(),
    );
    current['user_confirmed'] = allowed;
    nextItems[index] = current;
    nextEnvelope['items'] = nextItems;
    onChanged(nextEnvelope);
  }

  void _approveAllNeedsReview(List<Map<String, Object?>> needsReviewItems) {
    final indexes = needsReviewItems
        .map((item) => ((envelope['items'] as List?) ?? const []).indexOf(item))
        .where((index) => index >= 0)
        .toSet();
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextItems =
        ((envelope['items'] as List?) ?? const []).asMap().entries.map((entry) {
      if (!indexes.contains(entry.key) || entry.value is! Map) {
        return entry.value;
      }
      final next = Map<String, Object?>.from(
        (entry.value as Map).cast<String, Object?>(),
      );
      next['user_confirmed'] = true;
      return next;
    }).toList();
    nextEnvelope['items'] = nextItems;
    onChanged(nextEnvelope);
  }

  void _replaceReviewNote(int index, Map<String, Object?> nextNote) {
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextNotes = ((envelope['review_notes'] as List?) ?? const [])
        .map((item) => item is Map ? Map<String, Object?>.from(item) : item)
        .toList();
    nextNotes[index] = nextNote;
    nextEnvelope['review_notes'] = nextNotes;
    onChanged(nextEnvelope);
  }

  void _moveItemToReviewNote(int index) {
    final sourceItems = ((envelope['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final item = sourceItems[index];
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextItems = ((envelope['items'] as List?) ?? const []).toList();
    nextItems.removeAt(index);
    final nextNotes = ((envelope['review_notes'] as List?) ?? const [])
        .map((entry) => entry is Map ? Map<String, Object?>.from(entry) : entry)
        .toList();
    nextNotes.add(_reviewNoteFromItem(item));
    nextEnvelope['items'] = nextItems;
    nextEnvelope['review_notes'] = nextNotes;
    onChanged(nextEnvelope);
  }

  void _moveItemToIgnored(int index) {
    final sourceItems = ((envelope['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final item = sourceItems[index];
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextItems = ((envelope['items'] as List?) ?? const []).toList();
    nextItems.removeAt(index);
    final nextIgnored = ((envelope['ignored_context'] as List?) ?? const [])
        .map((entry) => entry is Map ? Map<String, Object?>.from(entry) : entry)
        .toList();
    nextIgnored.add({
      'raw_text':
          item['raw_text']?.toString() ?? item['title']?.toString() ?? '',
      'reason': 'user_ignored',
    });
    nextEnvelope['items'] = nextItems;
    nextEnvelope['ignored_context'] = nextIgnored;
    onChanged(nextEnvelope);
  }

  void _moveReviewNoteToIgnored(int index) {
    final sourceNotes = ((envelope['review_notes'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final note = sourceNotes[index];
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextNotes =
        ((envelope['review_notes'] as List?) ?? const []).toList();
    nextNotes.removeAt(index);
    final nextIgnored = ((envelope['ignored_context'] as List?) ?? const [])
        .map((entry) => entry is Map ? Map<String, Object?>.from(entry) : entry)
        .toList();
    nextIgnored.add({
      'raw_text':
          note['raw_text']?.toString() ?? note['content']?.toString() ?? '',
      'reason': 'user_ignored_note',
    });
    nextEnvelope['review_notes'] = nextNotes;
    nextEnvelope['ignored_context'] = nextIgnored;
    onChanged(nextEnvelope);
  }

  void _moveIgnoredToReviewNote(int index) {
    final sourceIgnored = ((envelope['ignored_context'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final ignored = sourceIgnored[index];
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextIgnored =
        ((envelope['ignored_context'] as List?) ?? const []).toList();
    nextIgnored.removeAt(index);
    final nextNotes = ((envelope['review_notes'] as List?) ?? const [])
        .map((entry) => entry is Map ? Map<String, Object?>.from(entry) : entry)
        .toList();
    nextNotes.add(_reviewNoteFromIgnored(ignored));
    nextEnvelope['ignored_context'] = nextIgnored;
    nextEnvelope['review_notes'] = nextNotes;
    onChanged(nextEnvelope);
  }

  Future<void> _moveReviewNoteToEvent(BuildContext context, int index) async {
    final sourceNotes = ((envelope['review_notes'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final note = sourceNotes[index];
    final targetKind = await _pickTargetRecordKind(context);
    if (targetKind == null) {
      return;
    }
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextNotes =
        ((envelope['review_notes'] as List?) ?? const []).toList();
    nextNotes.removeAt(index);
    final nextItems = ((envelope['items'] as List?) ?? const [])
        .map((entry) => entry is Map ? Map<String, Object?>.from(entry) : entry)
        .toList();
    nextItems.add(
      _reviewableItemFromText(
        kind: targetKind,
        contextDate: envelope['context_date']?.toString(),
        title: note['title']?.toString() ?? '待整理事件',
        rawText:
            note['raw_text']?.toString() ?? note['content']?.toString() ?? '',
        body: note['content']?.toString(),
      ),
    );
    nextEnvelope['review_notes'] = nextNotes;
    nextEnvelope['items'] = nextItems;
    onChanged(nextEnvelope);
  }

  Future<void> _moveIgnoredToEvent(BuildContext context, int index) async {
    final sourceIgnored = ((envelope['ignored_context'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final ignored = sourceIgnored[index];
    final targetKind = await _pickTargetRecordKind(context);
    if (targetKind == null) {
      return;
    }
    final nextEnvelope = Map<String, Object?>.from(envelope);
    final nextIgnored =
        ((envelope['ignored_context'] as List?) ?? const []).toList();
    nextIgnored.removeAt(index);
    final nextItems = ((envelope['items'] as List?) ?? const [])
        .map((entry) => entry is Map ? Map<String, Object?>.from(entry) : entry)
        .toList();
    nextItems.add(
      _reviewableItemFromText(
        kind: targetKind,
        contextDate: envelope['context_date']?.toString(),
        title: '拉回整理',
        rawText: ignored['raw_text']?.toString() ?? '',
        body: ignored['raw_text']?.toString(),
      ),
    );
    nextEnvelope['ignored_context'] = nextIgnored;
    nextEnvelope['items'] = nextItems;
    onChanged(nextEnvelope);
  }

  bool _isRecord(Map<String, Object?> item) {
    final kind = item['kind']?.toString();
    return {
      'time_record',
      'income_record',
      'expense_record',
      'learning_record',
    }.contains(kind);
  }

  bool _isCommitReady(Map<String, Object?> item) {
    if (!_isRecord(item)) return false;
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    return validation['status']?.toString() == 'commit_ready';
  }

  bool _isNeedsReview(Map<String, Object?> item) {
    if (!_isRecord(item)) return false;
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    return validation['status']?.toString() == 'needs_review';
  }

  bool _isBlocked(Map<String, Object?> item) {
    if (!_isRecord(item)) return false;
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    return validation['status']?.toString() == 'blocked';
  }

  bool _isSubmittable(Map<String, Object?> item) {
    return _isCommitReady(item) ||
        (_isNeedsReview(item) && item['user_confirmed'] == true);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label · $count',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    );
  }
}

class _ReviewNoteTile extends StatelessWidget {
  const _ReviewNoteTile({
    required this.note,
    required this.onConvertToIgnored,
    required this.onConvertToEvent,
    required this.onChanged,
  });

  final Map<String, Object?> note;
  final VoidCallback onConvertToIgnored;
  final VoidCallback onConvertToEvent;
  final ValueChanged<Map<String, Object?>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.46),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF94A3B8).withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ActionPill(
                      label:
                          _noteTypeLabel(note['note_type']?.toString() ?? ''),
                      color: const Color(0xFF64748B),
                      onTap: () => _pickNoteType(context),
                    ),
                    _ActionPill(
                      label: _visibilityLabel(
                          note['visibility']?.toString() ?? ''),
                      color: const Color(0xFF475569),
                      onTap: () => _pickVisibility(context),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onConvertToEvent,
                child: const Text('转事件'),
              ),
              TextButton(
                onPressed: onConvertToIgnored,
                child: const Text('忽略'),
              ),
              const Spacer(),
              Text(
                ((note['confidence'] as num?)?.toDouble() ?? 0)
                    .toStringAsFixed(2),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: note['title']?.toString() ?? '',
            decoration: const InputDecoration(labelText: '标题'),
            onChanged: (value) => _update('title', value),
          ),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: note['content']?.toString() ?? '',
            decoration: const InputDecoration(labelText: '内容'),
            minLines: 1,
            maxLines: 3,
            onChanged: (value) => _update('content', value),
          ),
        ],
      ),
    );
  }

  void _update(String key, String value) {
    final next = Map<String, Object?>.from(note);
    next[key] = value;
    onChanged(next);
  }

  Future<void> _pickNoteType(BuildContext context) async {
    final selected = await _pickSimpleOption(
      context,
      title: '复盘类型',
      options: const {
        'reflection': '反思',
        'feeling': '感受',
        'plan': '计划',
        'idea': '灵感',
        'context': '上下文',
        'ai_usage': 'AI 使用',
        'risk': '风险',
        'summary': '总结',
      },
      current: note['note_type']?.toString() ?? 'reflection',
    );
    if (selected != null) {
      _update('note_type', selected);
    }
  }

  Future<void> _pickVisibility(BuildContext context) async {
    final selected = await _pickSimpleOption(
      context,
      title: '可见性',
      options: const {
        'compact': '简洁',
        'normal': '正常',
        'hidden': '隐藏',
      },
      current: note['visibility']?.toString() ?? 'compact',
    );
    if (selected != null) {
      _update('visibility', selected);
    }
  }
}

class _DraftItemCard extends StatelessWidget {
  const _DraftItemCard({
    required this.index,
    required this.item,
    required this.optionResolver,
    required this.sourceSuggestions,
    required this.projectOptions,
    required this.tags,
    this.onApprovalChanged,
    this.onConvertToNote,
    this.onIgnore,
    required this.onChanged,
  });

  final int index;
  final Map<String, Object?> item;
  final List<DimensionOptionModel> Function(CaptureFieldOptions key)
      optionResolver;
  final List<String> sourceSuggestions;
  final List<ProjectOption> projectOptions;
  final List<TagModel> tags;
  final ValueChanged<bool>? onApprovalChanged;
  final VoidCallback? onConvertToNote;
  final VoidCallback? onIgnore;
  final ValueChanged<Map<String, Object?>> onChanged;

  @override
  Widget build(BuildContext context) {
    final kind = item['kind']?.toString() ?? 'unknown';
    final validation =
        ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
    final status = validation['status']?.toString() ?? 'unknown';
    final missingRequired =
        ((validation['missing_required'] as List?) ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toSet();
    final blockingErrors =
        ((validation['blocking_errors'] as List?) ?? const [])
            .map((item) => item.toString())
            .where((item) => item.trim().isNotEmpty)
            .toList();
    final fieldMap =
        ((item['fields'] as Map?) ?? const {}).cast<String, Object?>();
    final definitions = _draftFieldDefinitionsFor(kind);
    final userConfirmed = item['user_confirmed'] == true;
    final canApprove = status == 'needs_review' && onApprovalChanged != null;
    final links = ((item['links'] as Map?) ?? const {}).cast<String, Object?>();
    final selectedProjectIds = _selectedProjectIds(links);
    final selectedTagIds = _selectedTagIds(links);
    final unresolvedProjects = _unresolvedLinkNames(links['projects']);
    final unresolvedTags = _unresolvedLinkNames(links['tags']);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _statusColor(status).withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Pill(label: _kindLabel(kind), color: _kindColor(kind)),
              const SizedBox(width: 8),
              _Pill(label: _statusLabel(status), color: _statusColor(status)),
              if (canApprove) ...[
                const SizedBox(width: 8),
                _Pill(
                  label: userConfirmed ? '已允许提交' : '待确认',
                  color: userConfirmed
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFD97706),
                ),
              ],
              const Spacer(),
              if (onConvertToNote != null)
                IconButton(
                  onPressed: onConvertToNote,
                  tooltip: '转复盘',
                  icon: const Icon(Icons.notes_rounded, size: 18),
                ),
              if (onIgnore != null)
                IconButton(
                  onPressed: onIgnore,
                  tooltip: '忽略',
                  icon: const Icon(Icons.visibility_off_rounded, size: 18),
                ),
              Text('#${index + 1}',
                  style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          if (canApprove) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => onApprovalChanged!(!userConfirmed),
                icon: Icon(
                  userConfirmed
                      ? Icons.remove_done_rounded
                      : Icons.task_alt_rounded,
                  size: 18,
                ),
                label: Text(userConfirmed ? '取消通过' : '允许提交'),
              ),
            ),
          ],
          if (missingRequired.isNotEmpty || blockingErrors.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final key in missingRequired)
                  _Pill(
                    label: '缺 ${_fieldLabel(key)}',
                    color: const Color(0xFFDC2626),
                  ),
                for (final error in blockingErrors)
                  _Pill(
                    label: _compactBlockingLabel(error),
                    color: const Color(0xFFB91C1C),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          TextFormField(
            initialValue: item['title']?.toString() ?? '',
            decoration: const InputDecoration(labelText: '标题'),
            onChanged: (value) => _updateTopLevel('title', value),
          ),
          const SizedBox(height: 8),
          for (final definition in definitions) ...[
            _FieldEditor(
              definition: definition,
              field:
                  (fieldMap[definition.key] as Map?)?.cast<String, Object?>() ??
                      const {},
              options: definition.optionsKey == null
                  ? const []
                  : optionResolver(definition.optionsKey!),
              sourceSuggestions: sourceSuggestions,
              missingRequired: missingRequired.contains(definition.key),
              blockingError: _blockingErrorForField(
                definition.key,
                blockingErrors,
              ),
              onChanged: (value) => _updateField(definition.key, value),
            ),
            const SizedBox(height: 8),
          ],
          for (final entry in fieldMap.entries.where(
            (entry) =>
                _visibleField(entry.key) &&
                definitions.every((definition) => definition.key != entry.key),
          )) ...[
            _FieldEditor(
              definition: _fallbackDefinitionFor(entry.key),
              field: (entry.value as Map?)?.cast<String, Object?>() ?? const {},
              options: const [],
              sourceSuggestions: sourceSuggestions,
              missingRequired: missingRequired.contains(entry.key),
              blockingError: _blockingErrorForField(
                entry.key,
                blockingErrors,
              ),
              onChanged: (value) => _updateField(entry.key, value),
            ),
            const SizedBox(height: 8),
          ],
          if (projectOptions.isNotEmpty) ...[
            const SizedBox(height: 4),
            _ProjectLinkSelector(
              selectedIds: selectedProjectIds,
              projectOptions: projectOptions,
              onToggle: _toggleProjectLink,
            ),
          ],
          if (unresolvedProjects.isNotEmpty) ...[
            const SizedBox(height: 8),
            _UnresolvedLinkRow(
              title: '未解析项目引用',
              names: unresolvedProjects,
              onRemove: _removeProjectLinkByName,
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            TagSelector(
              title: '标签',
              selectedIds: selectedTagIds,
              labels: {
                for (final tag in tags)
                  tag.id: '${tag.emoji ?? ''} ${tag.name}'.trim(),
              },
              onToggle: _toggleTagLink,
            ),
          ],
          if (unresolvedTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            _UnresolvedLinkRow(
              title: '未解析标签引用',
              names: unresolvedTags,
              onRemove: _removeTagLinkByName,
            ),
          ],
          TextFormField(
            initialValue: item['note']?.toString() ?? '',
            decoration: const InputDecoration(labelText: '备注'),
            minLines: 1,
            maxLines: 3,
            onChanged: (value) => _updateTopLevel('note', value),
          ),
          if ((item['raw_text']?.toString() ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              '原文：${item['raw_text']}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  void _updateTopLevel(String key, String value) {
    final next = Map<String, Object?>.from(item);
    next[key] = value;
    next['user_confirmed'] = true;
    onChanged(next);
  }

  void _updateField(String key, String value) {
    final next = Map<String, Object?>.from(item);
    final fields = ((next['fields'] as Map?) ?? const {})
        .map((fieldKey, fieldValue) => MapEntry(
              fieldKey.toString(),
              fieldValue is Map
                  ? Map<String, Object?>.from(fieldValue)
                  : <String, Object?>{},
            ));
    final field = Map<String, Object?>.from(fields[key] ?? const {});
    field['value'] = value;
    field['raw'] = value;
    field['source'] = 'user';
    fields[key] = field;
    next['fields'] = fields;
    next['user_confirmed'] = true;
    onChanged(next);
  }

  void _toggleProjectLink(String projectId) {
    final next = Map<String, Object?>.from(item);
    final nextLinks = Map<String, Object?>.from(
      ((next['links'] as Map?) ?? const {}).cast<String, Object?>(),
    );
    final current = ((nextLinks['projects'] as List?) ?? const [])
        .whereType<Map>()
        .map((link) => Map<String, Object?>.from(link.cast<String, Object?>()))
        .toList();
    final project = projectOptions.firstWhere((item) => item.id == projectId);
    final existingIndex = current.indexWhere(
      (link) => link['project_id']?.toString() == projectId,
    );
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
    } else {
      current.add({
        'project_id': project.id,
        'name': project.name,
        'weight_ratio': 1.0,
        'source': 'user',
        'resolution_status': 'id_selected',
        'warnings': <String>[],
      });
    }
    nextLinks['projects'] = current;
    next['links'] = nextLinks;
    next['user_confirmed'] = true;
    onChanged(next);
  }

  void _toggleTagLink(String tagId) {
    final next = Map<String, Object?>.from(item);
    final nextLinks = Map<String, Object?>.from(
      ((next['links'] as Map?) ?? const {}).cast<String, Object?>(),
    );
    final current = ((nextLinks['tags'] as List?) ?? const [])
        .whereType<Map>()
        .map((link) => Map<String, Object?>.from(link.cast<String, Object?>()))
        .toList();
    final tag = tags.firstWhere((item) => item.id == tagId);
    final existingIndex = current.indexWhere(
      (link) => link['tag_id']?.toString() == tagId,
    );
    if (existingIndex >= 0) {
      current.removeAt(existingIndex);
    } else {
      current.add({
        'tag_id': tag.id,
        'name': tag.name,
        'scope': item['kind']?.toString(),
        'source': 'user',
        'resolution_status': 'id_selected',
        'warnings': <String>[],
      });
    }
    nextLinks['tags'] = current;
    next['links'] = nextLinks;
    next['user_confirmed'] = true;
    onChanged(next);
  }

  void _removeProjectLinkByName(String name) {
    _removeLinkByName('projects', name);
  }

  void _removeTagLinkByName(String name) {
    _removeLinkByName('tags', name);
  }

  void _removeLinkByName(String linkKey, String name) {
    final next = Map<String, Object?>.from(item);
    final nextLinks = Map<String, Object?>.from(
      ((next['links'] as Map?) ?? const {}).cast<String, Object?>(),
    );
    final current = ((nextLinks[linkKey] as List?) ?? const [])
        .whereType<Map>()
        .map((link) => Map<String, Object?>.from(link.cast<String, Object?>()))
        .where((link) => link['name']?.toString() != name)
        .toList();
    nextLinks[linkKey] = current;
    next['links'] = nextLinks;
    next['user_confirmed'] = true;
    onChanged(next);
  }

  bool _visibleField(String key) {
    return !{
      'raw',
      'reference_kind',
      'reference_text',
    }.contains(key);
  }
}

class _FieldEditor extends StatelessWidget {
  const _FieldEditor({
    required this.definition,
    required this.field,
    required this.options,
    required this.sourceSuggestions,
    required this.missingRequired,
    required this.blockingError,
    required this.onChanged,
  });

  final CaptureFieldDefinition definition;
  final Map<String, Object?> field;
  final List<DimensionOptionModel> options;
  final List<String> sourceSuggestions;
  final bool missingRequired;
  final String? blockingError;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final warning = ((field['warnings'] as List?) ?? const [])
        .map((item) => item.toString())
        .where((item) => item.trim().isNotEmpty)
        .join('；');
    final currentValue = field['value']?.toString() ?? '';
    final errorText =
        blockingError ?? (missingRequired ? '请补充${definition.label}' : null);
    switch (definition.kind) {
      case CaptureFieldKind.time:
        return _PickerField(
          label: definition.label,
          value: currentValue,
          helperText: errorText == null && warning.isNotEmpty ? warning : null,
          errorText: errorText,
          hintText: definition.hintText ?? '选择时间',
          icon: Icons.schedule_rounded,
          onTap: () async {
            final selected = await _pickTime(context, currentValue);
            if (selected != null) {
              onChanged(selected);
            }
          },
        );
      case CaptureFieldKind.date:
        return _PickerField(
          label: definition.label,
          value: currentValue,
          helperText: errorText == null && warning.isNotEmpty ? warning : null,
          errorText: errorText,
          hintText: definition.hintText ?? '选择日期',
          icon: Icons.calendar_month_rounded,
          onTap: () async {
            final selected = await _pickDate(context, currentValue);
            if (selected != null) {
              onChanged(selected);
            }
          },
        );
      case CaptureFieldKind.dropdown:
        return _OptionPickerField(
          label: definition.label,
          value: currentValue,
          options: options,
          helperText: errorText == null && warning.isNotEmpty ? warning : null,
          errorText: errorText,
          onSelected: onChanged,
        );
      case CaptureFieldKind.boolean:
        final selected = currentValue.trim().toLowerCase() == 'true';
        return SwitchListTile(
          value: selected,
          onChanged: (value) => onChanged(value.toString()),
          contentPadding: EdgeInsets.zero,
          title: Text(definition.label),
          subtitle: errorText != null
              ? Text(errorText,
                  style: const TextStyle(color: Color(0xFFDC2626)))
              : (warning.isEmpty ? null : Text(warning)),
        );
      case CaptureFieldKind.text:
        if (definition.key == 'source') {
          return _SourceAutocompleteField(
            value: currentValue,
            suggestions: sourceSuggestions,
            label: definition.label,
            helperText:
                errorText == null && warning.isNotEmpty ? warning : null,
            errorText: errorText,
            onChanged: onChanged,
          );
        }
        return TextFormField(
          initialValue: currentValue,
          decoration: InputDecoration(
            labelText: definition.label,
            hintText: definition.hintText,
            helperText:
                errorText == null && warning.isNotEmpty ? warning : null,
            errorText: errorText,
          ),
          onChanged: onChanged,
        );
      case CaptureFieldKind.multiline:
      case CaptureFieldKind.money:
      case CaptureFieldKind.integer:
      case CaptureFieldKind.percentage:
      case CaptureFieldKind.score:
        return TextFormField(
          initialValue: currentValue,
          minLines: definition.maxLines > 1 ? definition.maxLines : 1,
          maxLines: definition.maxLines,
          keyboardType: _keyboardTypeFor(definition.kind),
          decoration: InputDecoration(
            labelText: definition.label,
            hintText: definition.hintText,
            helperText:
                errorText == null && warning.isNotEmpty ? warning : null,
            errorText: errorText,
            suffixText: definition.suffixText,
          ),
          onChanged: onChanged,
        );
    }
  }
}

class _WarningBox extends StatelessWidget {
  const _WarningBox({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFFCC80)),
      ),
      child: Text(
        warnings.join('\n'),
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _ProjectLinkSelector extends StatelessWidget {
  const _ProjectLinkSelector({
    required this.selectedIds,
    required this.projectOptions,
    required this.onToggle,
  });

  final Set<String> selectedIds;
  final List<ProjectOption> projectOptions;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('关联项目', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final project in projectOptions)
              FilterChip(
                label: Text(project.name),
                selected: selectedIds.contains(project.id),
                onSelected: (_) => onToggle(project.id),
              ),
          ],
        ),
      ],
    );
  }
}

class _UnresolvedLinkRow extends StatelessWidget {
  const _UnresolvedLinkRow({
    required this.title,
    required this.names,
    required this.onRemove,
  });

  final String title;
  final List<String> names;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final name in names)
              InputChip(
                label: Text(name),
                onDeleted: () => onRemove(name),
              ),
          ],
        ),
      ],
    );
  }
}

String? _blockingErrorForField(String key, List<String> blockingErrors) {
  for (final error in blockingErrors) {
    if (error.contains(key)) {
      return _compactBlockingLabel(error);
    }
    if (key == 'ai_assist_ratio' && error.contains('ai_assist_ratio')) {
      return _compactBlockingLabel(error);
    }
    if (key == 'duration_minutes' && error.contains('duration_minutes')) {
      return _compactBlockingLabel(error);
    }
  }
  return null;
}

String _compactBlockingLabel(String error) {
  if (error.contains('between 0 and 10')) {
    return '分数超范围';
  }
  if (error.contains('between 0 and 100')) {
    return 'AI占比超范围';
  }
  if (error.contains('duration_minutes')) {
    return '时长无效';
  }
  return '字段无效';
}

Set<String> _selectedProjectIds(Map<String, Object?> links) {
  return ((links['projects'] as List?) ?? const [])
      .whereType<Map>()
      .map((link) => link['project_id']?.toString() ?? '')
      .where((value) => value.trim().isNotEmpty)
      .toSet();
}

Set<String> _selectedTagIds(Map<String, Object?> links) {
  return ((links['tags'] as List?) ?? const [])
      .whereType<Map>()
      .map((link) => link['tag_id']?.toString() ?? '')
      .where((value) => value.trim().isNotEmpty)
      .toSet();
}

List<String> _unresolvedLinkNames(Object? rawLinks) {
  return (rawLinks as List? ?? const [])
      .whereType<Map>()
      .where(
        (link) => (link['resolution_status']?.toString() ?? '') == 'unresolved',
      )
      .map((link) => link['name']?.toString() ?? '')
      .where((value) => value.trim().isNotEmpty)
      .toList();
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: _Pill(label: label, color: color),
    );
  }
}

String _kindLabel(String kind) {
  return switch (kind) {
    'time_record' => '时间',
    'income_record' => '收入',
    'expense_record' => '支出',
    'learning_record' => '学习',
    'time_marker' => '时间锚点',
    'reference_note' => '引用',
    'project' => '项目',
    'tag' => '标签',
    _ => '未知',
  };
}

String _statusLabel(String status) {
  return switch (status) {
    'commit_ready' => '可入库',
    'needs_review' => '需审核',
    'reference_only' => '仅引用',
    'blocked' => '阻塞',
    _ => '未知',
  };
}

String _fieldLabel(String key) {
  return switch (key) {
    'date' => '日期',
    'start_time' => '开始时间',
    'end_time' => '结束时间',
    'duration_minutes' => '时长分钟',
    'duration_text' => '时长原文',
    'time_status' => '时间状态',
    'amount' => '金额',
    'category' => '类别',
    'source' => '来源',
    'content' => '内容',
    'efficiency_score' => '效率',
    'value_score' => '价值',
    'state_score' => '状态',
    'ai_assist_ratio' => 'AI 占比',
    'application_level' => '应用等级',
    'facets' => '引用面向',
    _ => key,
  };
}

String _noteTypeLabel(String kind) {
  return switch (kind) {
    'reflection' => '反思',
    'feeling' => '感受',
    'plan' => '计划',
    'idea' => '灵感',
    'context' => '上下文',
    'ai_usage' => 'AI 使用',
    'risk' => '风险',
    'summary' => '总结',
    _ => '复盘',
  };
}

String _visibilityLabel(String visibility) {
  return switch (visibility) {
    'hidden' => '隐藏',
    'normal' => '正常',
    _ => '简洁',
  };
}

Color _kindColor(String kind) {
  return switch (kind) {
    'time_record' => const Color(0xFF2563EB),
    'income_record' => const Color(0xFF059669),
    'expense_record' => const Color(0xFFDC2626),
    'learning_record' => const Color(0xFF7C3AED),
    'time_marker' => const Color(0xFF0891B2),
    'reference_note' => const Color(0xFF64748B),
    _ => const Color(0xFF475569),
  };
}

Color _statusColor(String status) {
  return switch (status) {
    'commit_ready' => const Color(0xFF059669),
    'needs_review' => const Color(0xFFD97706),
    'reference_only' => const Color(0xFF64748B),
    'blocked' => const Color(0xFFDC2626),
    _ => const Color(0xFF475569),
  };
}

List<CaptureFieldDefinition> _draftFieldDefinitionsFor(String kind) {
  switch (kind) {
    case 'time_record':
      return const [
        CaptureFieldDefinition(
          key: 'date',
          label: '日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'start_time',
          label: '开始时间',
          kind: CaptureFieldKind.time,
        ),
        CaptureFieldDefinition(
          key: 'end_time',
          label: '结束时间',
          kind: CaptureFieldKind.time,
        ),
        CaptureFieldDefinition(
          key: 'duration_minutes',
          label: '时长分钟',
          kind: CaptureFieldKind.integer,
          suffixText: '分钟',
        ),
        CaptureFieldDefinition(
          key: 'category',
          label: '类别',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.timeCategory,
        ),
        CaptureFieldDefinition(
          key: 'efficiency_score',
          label: '效率',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
        ),
        CaptureFieldDefinition(
          key: 'value_score',
          label: '价值',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
        ),
        CaptureFieldDefinition(
          key: 'state_score',
          label: '状态',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
        ),
        CaptureFieldDefinition(
          key: 'description',
          label: '内容',
          kind: CaptureFieldKind.multiline,
          maxLines: 2,
          fullWidth: true,
        ),
      ];
    case 'learning_record':
      return const [
        CaptureFieldDefinition(
          key: 'date',
          label: '日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'content',
          label: '学习内容',
          kind: CaptureFieldKind.text,
        ),
        CaptureFieldDefinition(
          key: 'duration_minutes',
          label: '学习时长',
          kind: CaptureFieldKind.integer,
          suffixText: '分钟',
        ),
        CaptureFieldDefinition(
          key: 'application_level',
          label: '应用等级',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.learningLevel,
        ),
        CaptureFieldDefinition(
          key: 'start_time',
          label: '开始时间',
          kind: CaptureFieldKind.time,
        ),
        CaptureFieldDefinition(
          key: 'end_time',
          label: '结束时间',
          kind: CaptureFieldKind.time,
        ),
        CaptureFieldDefinition(
          key: 'efficiency_score',
          label: '效率',
          kind: CaptureFieldKind.score,
          suffixText: '/10',
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
        ),
      ];
    case 'income_record':
      return const [
        CaptureFieldDefinition(
          key: 'date',
          label: '日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'amount',
          label: '金额',
          kind: CaptureFieldKind.money,
          suffixText: '元',
        ),
        CaptureFieldDefinition(
          key: 'source',
          label: '来源',
          kind: CaptureFieldKind.text,
        ),
        CaptureFieldDefinition(
          key: 'type',
          label: '收入类型',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.incomeType,
        ),
        CaptureFieldDefinition(
          key: 'is_passive',
          label: '被动收入',
          kind: CaptureFieldKind.boolean,
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
        ),
      ];
    case 'expense_record':
      return const [
        CaptureFieldDefinition(
          key: 'date',
          label: '日期',
          kind: CaptureFieldKind.date,
        ),
        CaptureFieldDefinition(
          key: 'amount',
          label: '金额',
          kind: CaptureFieldKind.money,
          suffixText: '元',
        ),
        CaptureFieldDefinition(
          key: 'category',
          label: '支出类别',
          kind: CaptureFieldKind.dropdown,
          optionsKey: CaptureFieldOptions.expenseCategory,
        ),
        CaptureFieldDefinition(
          key: 'ai_assist_ratio',
          label: 'AI 占比',
          kind: CaptureFieldKind.percentage,
          suffixText: '%',
        ),
      ];
    default:
      return const [];
  }
}

CaptureFieldDefinition _fallbackDefinitionFor(String key) {
  return CaptureFieldDefinition(
    key: key,
    label: _fieldLabel(key),
    kind: CaptureFieldKind.text,
  );
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

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.icon,
    this.helperText,
    this.errorText,
    this.hintText,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final IconData icon;
  final String? helperText;
  final String? errorText;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          errorText: errorText,
          hintText: hintText,
          suffixIcon: Icon(icon),
        ),
        child: Text(
          value.isEmpty ? (hintText ?? '') : value,
          style: value.isEmpty
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

class _OptionPickerField extends StatelessWidget {
  const _OptionPickerField({
    required this.label,
    required this.options,
    required this.value,
    required this.onSelected,
    this.helperText,
    this.errorText,
  });

  final String label;
  final List<DimensionOptionModel> options;
  final String value;
  final ValueChanged<String> onSelected;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final selected = options
        .where((item) => item.code == value)
        .cast<DimensionOptionModel?>()
        .firstWhere((item) => item != null, orElse: () => null);
    final displayText = selected?.displayName ?? value;

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
                                onTap: () =>
                                    Navigator.of(context).pop(item.code),
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
          errorText: errorText,
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

class _SourceAutocompleteField extends StatelessWidget {
  const _SourceAutocompleteField({
    required this.value,
    required this.suggestions,
    required this.label,
    required this.onChanged,
    this.helperText,
    this.errorText,
  });

  final String value;
  final List<String> suggestions;
  final String label;
  final ValueChanged<String> onChanged;
  final String? helperText;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: value),
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) {
          return suggestions;
        }
        return suggestions.where(
          (item) => item.toLowerCase().contains(query),
        );
      },
      onSelected: onChanged,
      fieldViewBuilder: (context, textController, focusNode, onSubmitted) {
        textController.value = TextEditingValue(
          text: value,
          selection: TextSelection.collapsed(offset: value.length),
        );
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            errorText: errorText,
          ),
          onChanged: onChanged,
        );
      },
    );
  }
}

class _IgnoredContextTile extends StatelessWidget {
  const _IgnoredContextTile({
    required this.item,
    required this.onConvertToNote,
    required this.onConvertToEvent,
  });

  final Map<String, Object?> item;
  final VoidCallback onConvertToNote;
  final VoidCallback onConvertToEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: const Color(0xFF94A3B8).withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item['raw_text']?.toString() ?? ''),
              ),
              TextButton(
                onPressed: onConvertToNote,
                child: const Text('转复盘'),
              ),
              TextButton(
                onPressed: onConvertToEvent,
                child: const Text('转事件'),
              ),
            ],
          ),
          Text(
            item['reason']?.toString() ?? 'ignored',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

Future<String?> _pickDate(BuildContext context, String currentValue) async {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final initial = currentValue.isEmpty
      ? DateTime.now()
      : DateTime.tryParse(currentValue) ?? DateTime.now();
  final result = await showDatePicker(
    context: rootContext,
    initialDate: initial,
    firstDate: DateTime(2020),
    lastDate: DateTime(2100),
  );
  return result?.toIso8601String().split('T').first;
}

Future<String?> _pickTime(BuildContext context, String currentValue) async {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final initial =
      _parseTime(currentValue) ?? const TimeOfDay(hour: 9, minute: 0);
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
              initialDateTime:
                  DateTime(2024, 1, 1, initial.hour, initial.minute),
              onDateTimeChanged: (value) {
                selected = TimeOfDay(hour: value.hour, minute: value.minute);
              },
            ),
          ),
        ],
      ),
    ),
  );
  return result == null ? null : _timeText(result);
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

String _timeText(TimeOfDay value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

Future<String?> _pickTargetRecordKind(BuildContext context) async {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  return showModalBottomSheet<String>(
    context: rootContext,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('转成时间记录'),
            onTap: () => Navigator.of(context).pop('time_record'),
          ),
          ListTile(
            title: const Text('转成学习记录'),
            onTap: () => Navigator.of(context).pop('learning_record'),
          ),
          ListTile(
            title: const Text('转成收入记录'),
            onTap: () => Navigator.of(context).pop('income_record'),
          ),
          ListTile(
            title: const Text('转成支出记录'),
            onTap: () => Navigator.of(context).pop('expense_record'),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _pickSimpleOption(
  BuildContext context, {
  required String title,
  required Map<String, String> options,
  required String current,
}) async {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  return showModalBottomSheet<String>(
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
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
              ],
            ),
          ),
          for (final entry in options.entries)
            ListTile(
              title: Text(entry.value),
              subtitle: Text(entry.key),
              trailing:
                  entry.key == current ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
        ],
      ),
    ),
  );
}

Map<String, Object?> _reviewNoteFromItem(Map<String, Object?> item) {
  final rawText =
      item['raw_text']?.toString() ?? item['title']?.toString() ?? '';
  return {
    'draft_id': 'note_${DateTime.now().microsecondsSinceEpoch}',
    'raw_text': rawText,
    'title': item['title']?.toString() ?? '复盘素材',
    'note_type': 'reflection',
    'content': item['note']?.toString() ?? rawText,
    'visibility': 'compact',
    'source': 'user_reclassified',
    'confidence': item['confidence'] ?? 0.5,
  };
}

Map<String, Object?> _reviewNoteFromIgnored(Map<String, Object?> item) {
  final rawText = item['raw_text']?.toString() ?? '';
  return {
    'draft_id': 'note_${DateTime.now().microsecondsSinceEpoch}',
    'raw_text': rawText,
    'title': rawText.isEmpty ? '复盘素材' : rawText.characters.take(12).toString(),
    'note_type': 'reflection',
    'content': rawText,
    'visibility': 'compact',
    'source': 'user_reclassified',
    'confidence': 0.4,
  };
}

Map<String, Object?> _reviewableItemFromText({
  required String kind,
  required String? contextDate,
  required String title,
  required String rawText,
  required String? body,
}) {
  final fields = <String, Object?>{};
  final missing = <String>[];
  switch (kind) {
    case 'time_record':
      fields['date'] = _fieldValue(contextDate ?? '');
      fields['description'] = _fieldValue(body ?? title);
      missing.addAll(['start_time', 'end_time', 'category']);
      break;
    case 'learning_record':
      fields['date'] = _fieldValue(contextDate ?? '');
      fields['content'] = _fieldValue(body ?? title);
      fields['application_level'] = _fieldValue('input');
      missing.add('duration_minutes');
      break;
    case 'income_record':
      fields['date'] = _fieldValue(contextDate ?? '');
      fields['source'] = _fieldValue(body ?? title);
      missing.addAll(['amount', 'type']);
      break;
    case 'expense_record':
      fields['date'] = _fieldValue(contextDate ?? '');
      missing.addAll(['amount', 'category']);
      break;
  }
  return {
    'draft_id': 'draft_${DateTime.now().microsecondsSinceEpoch}',
    'intent': 'record',
    'kind': kind,
    'raw_text': rawText,
    'title': title,
    'note': body,
    'unmapped_text': null,
    'fields': fields,
    'links': {
      'projects': <Object?>[],
      'tags': <Object?>[],
      'dimensions': <Object?>[],
    },
    'validation': {
      'status': 'needs_review',
      'missing_required': missing,
      'blocking_errors': <Object?>[],
      'warnings': ['reclassified_from_note_or_ignored'],
    },
    'confidence': 0.35,
    'source': 'user_reclassified',
    'user_confirmed': false,
  };
}

Map<String, Object?> _fieldValue(String value) {
  return {
    'value': value,
    'raw': value,
    'source': 'user',
    'required': false,
    'editable': true,
    'confidence': null,
    'warnings': <Object?>[],
  };
}
