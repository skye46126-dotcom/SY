import 'package:flutter/material.dart';

class TagSelector extends StatelessWidget {
  const TagSelector({
    super.key,
    required this.title,
    required this.selectedIds,
    required this.labels,
    required this.onToggle,
    this.inlineThreshold = 5,
  });

  final String title;
  final Set<String> selectedIds;
  final Map<String, String> labels;
  final ValueChanged<String> onToggle;
  final int inlineThreshold;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (labels.length <= inlineThreshold)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in labels.entries)
                _TagChip(
                  label: entry.value.trim(),
                  selected: selectedIds.contains(entry.key),
                  onTap: () => onToggle(entry.key),
                ),
            ],
          )
        else
          _TagSummaryRow(
            labels: labels,
            selectedIds: selectedIds,
            onTap: () => _openTagSheet(context),
          ),
      ],
    );
  }

  Future<void> _openTagSheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF7F9FD),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      '标签只用于内容归类，多选项过多时收纳到弹窗里。',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in labels.entries)
                          _TagChip(
                            label: entry.value.trim(),
                            selected: selectedIds.contains(entry.key),
                            onTap: () {
                              onToggle(entry.key);
                              setSheetState(() {});
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _TagSummaryRow extends StatelessWidget {
  const _TagSummaryRow({
    required this.labels,
    required this.selectedIds,
    required this.onTap,
  });

  final Map<String, String> labels;
  final Set<String> selectedIds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selectedLabels = [
      for (final entry in labels.entries)
        if (selectedIds.contains(entry.key)) entry.value.trim(),
    ];
    final preview = selectedLabels.take(2).join('、');
    final hiddenCount =
        selectedLabels.length > 2 ? selectedLabels.length - 2 : 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.34),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.62)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                preview.isEmpty ? '选择标签' : preview,
                style: Theme.of(context).textTheme.bodyLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hiddenCount > 0)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  '+$hiddenCount',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontSize: 14),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, size: 18),
          ],
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? primary.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.52),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? primary : textColor,
                ),
          ),
        ),
      ),
    );
  }
}
