import 'package:flutter/material.dart';

import '../../../models/overview_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodayTimeMixSection extends StatelessWidget {
  const TodayTimeMixSection({
    super.key,
    required this.overview,
  });

  final TodayOverview? overview;

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return const SectionCard(
        eyebrow: 'Time Mix',
        title: '今日时间结构',
        child: SectionMessageView(
          icon: Icons.stacked_bar_chart_rounded,
          title: '时间结构暂不可用',
          description: '当前没有可展示的时间结构数据。',
        ),
      );
    }

    final work = overview!.totalWorkMinutes;
    final learning = overview!.totalLearningMinutes;
    final other = (overview!.totalTimeMinutes - work - learning).clamp(0, 1 << 30);
    final total = (work + learning + other).clamp(1, 1 << 30);

    return SectionCard(
      eyebrow: 'Time Mix',
      title: '今日时间结构',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: const Color(0xFFE8EEF8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Row(
              children: [
                if (work > 0)
                  Expanded(
                    flex: work,
                    child: Container(color: const Color(0xFF2363FF)),
                  ),
                if (learning > 0)
                  Expanded(
                    flex: learning,
                    child: Container(color: const Color(0xFFFF8A3D)),
                  ),
                if (other > 0)
                  Expanded(
                    flex: other,
                    child: Container(color: const Color(0xFF8C9BB2)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              _MixLegend(
                label: '工作',
                color: const Color(0xFF2363FF),
                minutes: work,
                percentage: work / total,
              ),
              _MixLegend(
                label: '学习',
                color: const Color(0xFFFF8A3D),
                minutes: learning,
                percentage: learning / total,
              ),
              _MixLegend(
                label: '其他',
                color: const Color(0xFF8C9BB2),
                minutes: other,
                percentage: other / total,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MixLegend extends StatelessWidget {
  const _MixLegend({
    required this.label,
    required this.color,
    required this.minutes,
    required this.percentage,
  });

  final String label;
  final Color color;
  final int minutes;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  '$minutes 分钟 · ${(percentage * 100).toStringAsFixed(1)}%',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
