import 'package:flutter/material.dart';

import '../../../models/review_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewProjectPerformanceSection extends StatelessWidget {
  const ReviewProjectPerformanceSection({
    super.key,
    required this.title,
    required this.projects,
    required this.onProjectTap,
  });

  final String title;
  final List<ProjectProgressItem> projects;
  final ValueChanged<String> onProjectTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'Projects',
      title: title,
      child: projects.isEmpty
          ? const SectionMessageView(
              icon: Icons.work_outline_rounded,
              title: '暂无项目数据',
              description: '当前周期没有可展示的项目表现。',
            )
          : Column(
              children: [
                for (final item in projects.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _ProjectBar(
                      item: item,
                      onTap: () => onProjectTap(item.projectId),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _ProjectBar extends StatelessWidget {
  const _ProjectBar({
    required this.item,
    required this.onTap,
  });

  final ProjectProgressItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final normalized = ((item.operatingRoiPerc + 100) / 200).clamp(0.0, 1.0);
    final tone = item.operatingRoiPerc >= 0
        ? const Color(0xFF0F9D84)
        : const Color(0xFFD64C4C);
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
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
                Expanded(
                  child: Text(
                    item.projectName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${item.operatingRoiPerc.toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: tone,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: normalized,
                minHeight: 12,
                backgroundColor: const Color(0xFFE7EDF7),
                valueColor: AlwaysStoppedAnimation(tone),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '收入 ¥${(item.incomeEarnedCents / 100).toStringAsFixed(2)} · 时间 ${item.timeSpentMinutes} 分钟 · 全成本 ¥${(item.fullyLoadedCostCents / 100).toStringAsFixed(2)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
