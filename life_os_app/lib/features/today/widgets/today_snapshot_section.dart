import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/overview_models.dart';
import '../../../models/snapshot_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodaySnapshotSection extends StatelessWidget {
  const TodaySnapshotSection({
    super.key,
    required this.snapshot,
    required this.summary,
  });

  final MetricSnapshotSummaryModel? snapshot;
  final TodaySummaryModel? summary;

  @override
  Widget build(BuildContext context) {
    if (snapshot == null) {
      return const SectionCard(
        eyebrow: 'Health',
        title: '经营健康度',
        child: SectionMessageView(
          icon: Icons.favorite_outline_rounded,
          title: '健康度暂不可用',
          description: '当前没有读取到今日快照。',
        ),
      );
    }

    final actual =
        (summary?.actualHourlyRateCents ?? snapshot!.hourlyRateCents ?? 0) /
            100;
    final ideal = (summary?.idealHourlyRateCents ?? 0) / 100;

    return SectionCard(
      eyebrow: 'Health',
      title: '经营健康度',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final compareChart = SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    [actual, ideal, 1.0].reduce((a, b) => a > b ? a : b) * 1.25,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 20,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0x14000000),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        value.toStringAsFixed(0),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) {
                        const labels = ['实际时薪', '理想时薪'];
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(labels[index]),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  _group(0, actual, const Color(0xFF2363FF)),
                  _group(1, ideal, const Color(0xFF0F9D84)),
                ],
              ),
            ),
          );

          final insightColumn = Column(
            children: [
              _HealthCard(
                title: '时间债',
                value: _currency(snapshot!.timeDebtCents),
                tone: _debtTone(snapshot!.timeDebtCents),
                subtitle: '理想与现实之间的差距',
              ),
              const SizedBox(height: 12),
              _HealthCard(
                title: '被动覆盖率',
                value: _ratio(snapshot!.passiveCoverRatio),
                tone: (snapshot!.passiveCoverRatio ?? 0) >= 1
                    ? Colors.green
                    : Colors.orange,
                subtitle: '被动收入覆盖必要支出',
              ),
              const SizedBox(height: 12),
              _HealthCard(
                title: '自由度金额',
                value: _currency(snapshot!.freedomCents),
                tone: (snapshot!.freedomCents ?? 0) >= 0
                    ? Colors.blue
                    : Colors.red,
                subtitle: '被动收入减必要支出',
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                compareChart,
                const SizedBox(height: 16),
                insightColumn,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: compareChart),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: insightColumn),
            ],
          );
        },
      ),
    );
  }

  BarChartGroupData _group(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          width: 26,
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
      ],
    );
  }

  Color _debtTone(int? cents) {
    if (cents == null) {
      return Colors.blueGrey;
    }
    return cents > 0 ? Colors.red : Colors.green;
  }

  String _currency(int? cents) =>
      cents == null ? '暂无数据' : '¥${(cents / 100).toStringAsFixed(2)}';

  String _ratio(double? value) =>
      value == null ? '暂无数据' : '${(value * 100).toStringAsFixed(1)}%';
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.title,
    required this.value,
    required this.tone,
    required this.subtitle,
  });

  final String title;
  final String value;
  final Color tone;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 44,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 6),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
