import 'package:flutter/material.dart';

import '../../../models/overview_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodayGoalProgressSection extends StatelessWidget {
  const TodayGoalProgressSection({
    super.key,
    required this.goalProgress,
  });

  final TodayGoalProgressModel? goalProgress;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'Goal Progress',
      title: '今日目标进度',
      child: goalProgress == null
          ? const SectionMessageView(
              icon: Icons.flag_circle_rounded,
              title: '目标进度暂不可用',
              description: '当前没有可展示的目标进度数据。',
            )
          : Column(
              children: [
                for (final item in goalProgress!.items) ...[
                  _GoalRow(item: item),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _GoalRow extends StatelessWidget {
  const _GoalRow({
    required this.item,
  });

  final TodayGoalProgressItemModel item;

  @override
  Widget build(BuildContext context) {
    final progress = (item.progressRatioBps / 10000).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(item.title, style: Theme.of(context).textTheme.titleMedium)),
            Text('${item.completedValue} / ${item.targetValue} ${item.unit}'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress),
        const SizedBox(height: 6),
        Text(_statusLabel(item.status), style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'done':
        return '已达标';
      case 'missing':
        return '尚未开始';
      case 'in_progress':
        return '进行中';
      default:
        return '未设置';
    }
  }
}
