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
    return SectionCard(
      eyebrow: 'Summary',
      title: '复盘摘要',
      child: report == null
          ? SectionMessageView(
              icon: Icons.summarize_rounded,
              title: '摘要区已就位',
              description: message ?? '等待 ReviewReport 返回摘要和趋势。',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(report!.aiSummary, style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    Text('收入: ¥${(report!.totalIncomeCents / 100).toStringAsFixed(2)}'),
                    Text('支出: ¥${(report!.totalExpenseCents / 100).toStringAsFixed(2)}'),
                    Text('工作时长: ${report!.totalWorkMinutes} 分钟'),
                    Text('总时间: ${report!.totalTimeMinutes} 分钟'),
                    if (snapshot != null)
                      Text(
                        '自由度金额: ${snapshot!.freedomCents == null ? '暂无数据' : '¥${(snapshot!.freedomCents! / 100).toStringAsFixed(2)}'}',
                      ),
                    if (snapshot != null)
                      Text(
                        '时间债: ${snapshot!.timeDebtCents == null ? '暂无数据' : '¥${(snapshot!.timeDebtCents! / 100).toStringAsFixed(2)}'}',
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
