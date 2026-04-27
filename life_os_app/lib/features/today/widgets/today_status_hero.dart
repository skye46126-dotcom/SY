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
    if (overview == null || summary == null) {
      return GlassPanel(
        child: SectionMessageView(
          icon: Icons.insights_rounded,
          title: '等待 Today 数据',
          description: unavailableMessage ?? statusMessage ?? '当前没有可展示的今日经营状态。',
        ),
      );
    }

    final compact = MediaQuery.sizeOf(context).width < 720;
    return GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('TODAY STATUS', style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 10),
          Text(
            summary!.headline,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: compact ? 28 : 34,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(label: '财务', tone: summary!.financeStatus),
              _StatusPill(label: '工作', tone: summary!.workStatus),
              _StatusPill(label: '学习', tone: summary!.learningStatus),
              _StatusPill(
                label: summary!.shouldReview ? '建议复盘' : '状态稳定',
                tone: summary!.shouldReview ? 'warning' : 'positive',
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              final cards = [
                _HeroMetric(
                  title: '净收入',
                  value: _currency(overview!.netIncomeCents),
                  caption: '今天的核心结果',
                  accent: const Color(0xFF2363FF),
                ),
                _HeroMetric(
                  title: '工作时长',
                  value: _hours(overview!.totalWorkMinutes),
                  caption: '${overview!.totalWorkMinutes} 分钟',
                  accent: const Color(0xFF0F9D84),
                ),
                _HeroMetric(
                  title: '学习时长',
                  value: _hours(overview!.totalLearningMinutes),
                  caption: '${overview!.totalLearningMinutes} 分钟',
                  accent: const Color(0xFFFF8A3D),
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    for (var i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      cards[i],
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 12),
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
                  '自由度 ${_currency(snapshot!.freedomCents)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '被动覆盖 ${_ratio(snapshot!.passiveCoverRatio)}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  '时间债 ${_currency(snapshot!.timeDebtCents)}',
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

  String _hours(int minutes) => '${(minutes / 60).toStringAsFixed(1)}h';

  String _ratio(double? value) =>
      value == null ? '暂无数据' : '${(value * 100).toStringAsFixed(1)}%';
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.title,
    required this.value,
    required this.caption,
    required this.accent,
  });

  final String title;
  final String value;
  final String caption;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withValues(alpha: 0.52),
        border: Border.all(color: Colors.white.withValues(alpha: 0.64)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.labelSmall),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(caption, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.tone,
  });

  final String label;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final colors = switch (tone) {
      'positive' || 'on_track' || 'done' => (
          const Color(0xFFE1F6EE),
          const Color(0xFF0F9D84)
        ),
      'warning' || 'behind' => (
          const Color(0xFFFFF0E1),
          const Color(0xFFE6811A)
        ),
      'negative' || 'critical' || 'missing' => (
          const Color(0xFFFFE3E2),
          const Color(0xFFD64C4C)
        ),
      _ => (const Color(0xFFE8EEF8), const Color(0xFF60708A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.$2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
