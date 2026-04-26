import 'package:flutter/material.dart';

import '../../../models/snapshot_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodaySnapshotSection extends StatelessWidget {
  const TodaySnapshotSection({
    super.key,
    required this.snapshot,
  });

  final MetricSnapshotSummaryModel? snapshot;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'Snapshot',
      title: '小时债 / 时薪 / 成本快照',
      child: snapshot == null
          ? const SectionMessageView(
              icon: Icons.auto_awesome_mosaic_rounded,
              title: '快照暂不可用',
              description: '没有读取到今日快照。',
            )
          : Wrap(
              spacing: 18,
              runSpacing: 12,
              children: [
                _item('实际时薪', _currency(snapshot!.hourlyRateCents)),
                _item('时间债', _currency(snapshot!.timeDebtCents)),
                _item('被动覆盖', _ratio(snapshot!.passiveCoverRatio)),
                _item('自由度金额', _currency(snapshot!.freedomCents)),
                _item('收入', _currency(snapshot!.totalIncomeCents)),
                _item('支出', _currency(snapshot!.totalExpenseCents)),
                _item(
                  '工作时长',
                  snapshot!.totalWorkMinutes == null
                      ? '暂无数据'
                      : '${snapshot!.totalWorkMinutes} 分钟',
                ),
              ],
            ),
    );
  }

  Widget _item(String title, String value) {
    return Builder(
      builder: (context) {
        return Container(
          width: 220,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        );
      },
    );
  }

  String _currency(int? cents) =>
      cents == null ? '暂无数据' : '¥${(cents / 100).toStringAsFixed(2)}';

  String _ratio(double? value) =>
      value == null ? '暂无数据' : '${(value * 100).toStringAsFixed(1)}%';
}
