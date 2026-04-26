import 'package:flutter/material.dart';

import '../../../models/overview_models.dart';
import '../../../models/snapshot_models.dart';
import '../../../shared/widgets/glass_panel.dart';
import '../../../shared/widgets/state_views.dart';

class TodayStatusHero extends StatelessWidget {
  const TodayStatusHero({
    super.key,
    required this.overview,
    required this.snapshot,
    required this.summary,
    required this.statusMessage,
    required this.unavailableMessage,
  });

  final TodayOverview? overview;
  final MetricSnapshotSummaryModel? snapshot;
  final TodaySummaryModel? summary;
  final String? statusMessage;
  final String? unavailableMessage;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GlassPanel(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 760;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _primaryContent(textTheme),
                const SizedBox(height: 20),
                _summaryCard(textTheme),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _primaryContent(textTheme)),
              const SizedBox(width: 20),
              SizedBox(
                width: 260,
                child: _summaryCard(textTheme),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _primaryContent(TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('TODAY STATUS', style: textTheme.labelSmall),
        const SizedBox(height: 10),
        Text(
          '今日经营状态',
          style: textTheme.headlineMedium?.copyWith(fontSize: 30),
        ),
        const SizedBox(height: 12),
        if (overview != null)
          Text(
            summary?.headline ?? _summaryText(),
            style: textTheme.bodyLarge,
          )
        else
          SectionMessageView(
            icon: Icons.data_thresholding_rounded,
            title: '等待 Today 数据源',
            description:
                unavailableMessage ?? statusMessage ?? '当前没有可展示的 TodayOverview 数据。',
          ),
      ],
    );
  }

  Widget _summaryCard(TextTheme textTheme) {
    return GlassPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('当前模块职责', style: textTheme.labelSmall),
          const SizedBox(height: 10),
          Text('一句话状态', style: textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            summary?.shouldReview == true ? '建议今日复盘' : '今日无需强制复盘',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            summary == null
                ? '目标进度'
                : '财务 ${summary!.financeStatus} · 工作 ${summary!.workStatus} · 学习 ${summary!.learningStatus}',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          Text(
            summary?.alerts.isNotEmpty == true
                ? '今日告警 ${summary!.alerts.length} 条'
                : '最近记录与快捷入口',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  String _summaryText() {
    final overview = this.overview;
    if (overview == null) {
      return '当前没有可展示的 TodayOverview 数据。';
    }
    final net = overview.netIncomeCents / 100;
    final workHours = (overview.totalWorkMinutes / 60).toStringAsFixed(1);
    final learningHours = (overview.totalLearningMinutes / 60).toStringAsFixed(1);
    final freedom = snapshot?.freedomCents == null
        ? null
        : (snapshot!.freedomCents! / 100).toStringAsFixed(2);
    final cover = snapshot?.passiveCoverRatio == null
        ? null
        : (snapshot!.passiveCoverRatio! * 100).toStringAsFixed(1);

    final netTone = net > 0
        ? '今天净收入为正'
        : net < 0
            ? '今天净收入为负'
            : '今天收支持平';
    final workTone = overview.totalWorkMinutes >= 180
        ? '工作时长达标'
        : '工作时长仍偏低';
    final learningTone = overview.totalLearningMinutes >= 60
        ? '学习投入稳定'
        : '学习投入不足';

    return '$netTone，工作 $workHours h，学习 $learningHours h，$workTone，$learningTone'
        '${freedom == null ? '' : '，自由度金额 ¥$freedom'}'
        '${cover == null ? '' : '，被动覆盖率 $cover%'}。';
  }
}
