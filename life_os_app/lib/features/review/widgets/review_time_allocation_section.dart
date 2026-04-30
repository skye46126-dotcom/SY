import 'package:flutter/material.dart';

import '../../../models/review_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewTimeAllocationSection extends StatelessWidget {
  const ReviewTimeAllocationSection({
    super.key,
    required this.report,
  });

  final ReviewReport? report;

  @override
  Widget build(BuildContext context) {
    final allocations =
        report?.timeAllocations ?? const <TimeCategoryAllocation>[];
    return SectionCard(
      eyebrow: 'Time Allocation',
      title: '时间结构',
      child: allocations.isEmpty
          ? const SectionMessageView(
              icon: Icons.stacked_bar_chart_rounded,
              title: '时间结构暂不可用',
              description: '当前没有可展示的时间分类数据。',
            )
          : Column(
              children: [
                for (final item in allocations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _AllocationBar(item: item),
                  ),
              ],
            ),
    );
  }
}

class _AllocationBar extends StatelessWidget {
  const _AllocationBar({
    required this.item,
  });

  final TimeCategoryAllocation item;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.categoryName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Text(
              '${item.minutes} 分钟 · ${item.percentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (item.percentage / 100).clamp(0.0, 1.0),
            minHeight: 14,
            backgroundColor: const Color(0xFFE7EDF7),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF2363FF)),
          ),
        ),
      ],
    );
  }
}
