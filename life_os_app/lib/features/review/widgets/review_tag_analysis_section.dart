import 'package:flutter/material.dart';

import '../../../models/review_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewTagAnalysisSection extends StatelessWidget {
  const ReviewTagAnalysisSection({
    super.key,
    required this.title,
    required this.metrics,
    required this.onTap,
  });

  final String title;
  final List<ReviewTagMetric> metrics;
  final ValueChanged<ReviewTagMetric> onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'Tags',
      title: title,
      child: metrics.isEmpty
          ? const SectionMessageView(
              icon: Icons.sell_outlined,
              title: '暂无标签数据',
              description: '当前周期没有可展示的标签结构。',
            )
          : Column(
              children: [
                for (final metric in metrics.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => onTap(metric),
                      child: _TagMetricBar(metric: metric),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TagMetricBar extends StatelessWidget {
  const _TagMetricBar({
    required this.metric,
  });

  final ReviewTagMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  '${metric.emoji ?? ''} ${metric.tagName}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${metric.percentage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (metric.percentage / 100).clamp(0.0, 1.0),
              minHeight: 12,
              backgroundColor: const Color(0xFFE7EDF7),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF2363FF)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '数值 ${metric.value}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
