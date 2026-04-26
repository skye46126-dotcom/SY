import 'package:flutter/material.dart';

import '../../../models/review_models.dart';
import '../../../models/snapshot_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewTrendSection extends StatelessWidget {
  const ReviewTrendSection({
    super.key,
    required this.report,
    required this.snapshot,
  });

  final ReviewReport? report;
  final MetricSnapshotSummaryModel? snapshot;

  String _ratio(double? value) {
    if (value == null) {
      return '无法计算';
    }
    return '${(value * 100).toStringAsFixed(1)}%';
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'Core Trends',
      title: '核心趋势',
      child: report == null
          ? const SectionMessageView(
              icon: Icons.show_chart_rounded,
              title: '趋势模块已拆分',
              description: '等待收入、支出、工作时长的变化率数据接入。',
            )
          : Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                Text('收入变化: ${_ratio(report!.incomeChangeRatio)}'),
                Text('支出变化: ${_ratio(report!.expenseChangeRatio)}'),
                Text('工作变化: ${_ratio(report!.workChangeRatio)}'),
                Text('被动覆盖: ${_ratio(report!.passiveCoverRatio)}'),
                Text(
                  '快照时薪: ${snapshot?.hourlyRateCents == null ? '暂无数据' : '¥${(snapshot!.hourlyRateCents! / 100).toStringAsFixed(2)}'}',
                ),
              ],
            ),
    );
  }
}
