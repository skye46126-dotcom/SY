import 'package:flutter/material.dart';

import '../../../models/overview_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodayAlertsSection extends StatelessWidget {
  const TodayAlertsSection({
    super.key,
    required this.alerts,
  });

  final TodayAlertsModel? alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts == null) {
      return const SectionCard(
        eyebrow: 'Alerts',
        title: '今日提醒',
        child: SectionMessageView(
          icon: Icons.warning_amber_rounded,
          title: '提醒数据暂不可用',
          description: '当前没有可展示的提醒列表。',
        ),
      );
    }

    if (alerts!.items.isEmpty) {
      return const SectionCard(
        eyebrow: 'Alerts',
        title: '今日提醒',
        child: SectionMessageView(
          icon: Icons.check_circle_outline_rounded,
          title: '今天没有经营提醒',
          description: '当前没有触发异常或缺失项提醒。',
        ),
      );
    }

    return SectionCard(
      eyebrow: 'Alerts',
      title: '今日提醒',
      child: Column(
        children: [
          for (final item in alerts!.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_icon(item.severity)),
              title: Text(item.title),
              subtitle: Text(item.message),
            ),
        ],
      ),
    );
  }

  IconData _icon(String severity) {
    switch (severity) {
      case 'critical':
        return Icons.error_outline_rounded;
      case 'warning':
        return Icons.warning_amber_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }
}
