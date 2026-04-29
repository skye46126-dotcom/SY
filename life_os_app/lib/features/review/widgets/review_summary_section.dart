import 'package:flutter/material.dart';

import '../../../models/review_models.dart';
import '../../../models/snapshot_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewSummarySection extends StatelessWidget {
  const ReviewSummarySection({
    super.key,
    required this.report,
    required this.snapshot,
    required this.message,
  });

  final ReviewReport? report;
  final MetricSnapshotSummaryModel? snapshot;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return SectionCard(
        eyebrow: 'Summary',
        title: '周期总览',
        child: SectionMessageView(
          icon: Icons.summarize_rounded,
          title: '复盘总览暂不可用',
          description: message ?? '等待 ReviewReport 返回周期数据。',
        ),
      );
    }

    final stats = [
      ('收入', _currency(report!.totalIncomeCents)),
      ('支出', _currency(report!.totalExpenseCents)),
      ('工作时长', '${report!.totalWorkMinutes} 分钟'),
      (
        '实际时薪',
        report!.actualHourlyRateCents == null
            ? '暂无数据'
            : _currency(report!.actualHourlyRateCents!),
      ),
    ];

    return SectionCard(
      eyebrow: 'Summary',
      title: '周期总览',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(report!.aiSummary, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 18),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              if (compact) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final item in stats)
                      _ReviewStatCard(
                        label: item.$1,
                        value: item.$2,
                        width: (constraints.maxWidth - 12) / 2,
                      ),
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < stats.length; i++) ...[
                    Expanded(
                      child: _ReviewStatCard(
                        label: stats[i].$1,
                        value: stats[i].$2,
                      ),
                    ),
                    if (i < stats.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 18),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                Text(
                  '时间债 ${_currency(snapshot!.timeDebtCents)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '自由度 ${_currency(snapshot!.freedomCents)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '被动覆盖 ${_ratio(snapshot!.passiveCoverRatio)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _currency(int? cents) =>
      cents == null ? '暂无数据' : '¥${(cents / 100).toStringAsFixed(2)}';

  String _ratio(double? value) =>
      value == null ? '暂无数据' : '${(value * 100).toStringAsFixed(1)}%';
}

class _ReviewStatCard extends StatelessWidget {
  const _ReviewStatCard({
    required this.label,
    required this.value,
    this.width,
  });

  final String label;
  final String value;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 8),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
