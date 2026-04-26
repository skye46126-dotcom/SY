import 'package:flutter/material.dart';

import '../../../models/overview_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodayMetricsSection extends StatelessWidget {
  const TodayMetricsSection({
    super.key,
    required this.overview,
    required this.summary,
    required this.message,
  });

  final TodayOverview? overview;
  final TodaySummaryModel? summary;
  final String? message;

  String _currency(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

  String _hours(int minutes) => '${(minutes / 60).toStringAsFixed(1)}h';

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return SectionCard(
        eyebrow: 'Core Metrics',
        title: '核心 4 指标卡片',
        child: SectionMessageView(
          icon: Icons.bar_chart_rounded,
          title: '指标区已建立',
          description: message ?? '等待 TodayOverview 返回真实数据。',
        ),
      );
    }

    final items = [
      ('净收入', _currency(overview!.netIncomeCents)),
      ('工作时长', _hours(overview!.totalWorkMinutes)),
      ('学习时长', _hours(overview!.totalLearningMinutes)),
      (
        '实际时薪',
        summary?.actualHourlyRateCents == null
            ? '暂无数据'
            : _currency(summary!.actualHourlyRateCents!)
      ),
    ];

    return SectionCard(
      eyebrow: 'Core Metrics',
      title: '核心 4 指标卡片',
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final item in items)
            Container(
              width: 240,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.$1, style: Theme.of(context).textTheme.labelSmall),
                  const SizedBox(height: 8),
                  Text(item.$2, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
