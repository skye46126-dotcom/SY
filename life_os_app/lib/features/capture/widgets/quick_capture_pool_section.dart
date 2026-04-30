import 'package:flutter/material.dart';

import '../../../shared/view_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class QuickCapturePoolSection extends StatelessWidget {
  const QuickCapturePoolSection({
    super.key,
    required this.bufferState,
    required this.actionState,
    required this.inputController,
    required this.onAppendPressed,
    required this.onProcessPressed,
    required this.onDeletePressed,
    this.lastActionSummary,
  });

  final ViewState<Map<String, Object?>> bufferState;
  final ViewState<void> actionState;
  final TextEditingController inputController;
  final VoidCallback onAppendPressed;
  final VoidCallback onProcessPressed;
  final ValueChanged<String> onDeletePressed;
  final String? lastActionSummary;

  @override
  Widget build(BuildContext context) {
    final session = ((bufferState.data?['session'] as Map?) ?? const {})
        .cast<String, Object?>();
    final items = ((bufferState.data?['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList();
    final itemCount = items.length;
    final hasItems = itemCount > 0;

    return SectionCard(
      eyebrow: 'Quick Capture Pool',
      title: '快录缓存池',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: inputController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: '加入一句原始记录',
              hintText: '先连续缓存碎片内容，再统一整理进入审核区。',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: actionState.status == ViewStatus.loading
                    ? null
                    : onAppendPressed,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('加入缓存池'),
              ),
              OutlinedButton.icon(
                onPressed: hasItems && actionState.status != ViewStatus.loading
                    ? onProcessPressed
                    : null,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: const Text('整理并进入审核'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _PoolPill(
                label: '当前缓存 $itemCount',
                color: const Color(0xFF2563EB),
              ),
              if ((session['status']?.toString().trim().isNotEmpty ?? false))
                _PoolPill(
                  label: '会话 ${session['status']}',
                  color: const Color(0xFF64748B),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (actionState.status == ViewStatus.loading) ...[
            const SectionLoadingView(label: '正在处理缓存池'),
            const SizedBox(height: 12),
          ],
          if (actionState.status == ViewStatus.error) ...[
            SectionMessageView(
              icon: Icons.error_outline_rounded,
              title: '缓存池操作失败',
              description: actionState.message ?? '请稍后重试。',
            ),
            const SizedBox(height: 12),
          ],
          if (actionState.status == ViewStatus.data &&
              (lastActionSummary?.trim().isNotEmpty ?? false)) ...[
            SectionMessageView(
              icon: Icons.check_circle_outline_rounded,
              title: '缓存池已更新',
              description: lastActionSummary!,
            ),
            const SizedBox(height: 12),
          ],
          if (bufferState.status == ViewStatus.loading && !bufferState.hasData)
            const SectionLoadingView(label: '正在读取缓存池'),
          if (bufferState.status == ViewStatus.error && !bufferState.hasData)
            SectionMessageView(
              icon: Icons.inbox_outlined,
              title: '缓存池暂不可用',
              description: bufferState.message ?? '请稍后重试。',
            ),
          if (bufferState.hasData && items.isEmpty)
            const SectionMessageView(
              icon: Icons.inbox_outlined,
              title: '当前没有缓存内容',
              description: '适合把零散想法、语音转写、临时记录先连续丢进这里，再统一整理。',
            ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (var index = 0; index < items.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _QuickCapturePoolItemCard(
                item: items[index],
                index: index,
                onDelete: () =>
                    onDeletePressed(items[index]['id']?.toString() ?? ''),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _QuickCapturePoolItemCard extends StatelessWidget {
  const _QuickCapturePoolItemCard({
    required this.item,
    required this.index,
    required this.onDelete,
  });

  final Map<String, Object?> item;
  final int index;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final rawText = item['raw_text']?.toString() ?? '';
    final inputKind = item['input_kind']?.toString() ?? 'text';
    final sequenceNo = item['sequence_no']?.toString() ?? '${index + 1}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.66)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PoolPill(
                      label: '#$sequenceNo',
                      color: const Color(0xFF475569),
                    ),
                    _PoolPill(
                      label: inputKind == 'voice' ? '语音' : '文本',
                      color: const Color(0xFF7C3AED),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  rawText,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: '移出缓存',
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}

class _PoolPill extends StatelessWidget {
  const _PoolPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
