import 'package:fl_chart/fl_chart.dart';
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

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return SectionCard(
        eyebrow: 'Cashflow',
        title: '今日现金流',
        child: SectionMessageView(
          icon: Icons.bar_chart_rounded,
          title: '现金流图表暂不可用',
          description: message ?? '等待 TodayOverview 返回现金流数据。',
        ),
      );
    }

    final income = overview!.totalIncomeCents / 100;
    final expense = overview!.totalExpenseCents / 100;
    final net = overview!.netIncomeCents / 100;
    final maxValue = [income.abs(), expense.abs(), net.abs(), 1.0]
        .reduce((value, element) => value > element ? value : element);

    return SectionCard(
      eyebrow: 'Cashflow',
      title: '今日现金流',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final chart = SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.25,
                minY: net < 0 ? net.abs() * -1.25 : 0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: const Color(0x14000000),
                    strokeWidth: 1,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 44,
                      interval: maxValue / 4,
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
                        const labels = ['收入', '支出', '净收入'];
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
                  _group(0, income, const Color(0xFF2363FF)),
                  _group(1, expense, const Color(0xFFD64C4C)),
                  _group(2, net, net >= 0 ? const Color(0xFF0F9D84) : const Color(0xFFE6811A)),
                ],
              ),
            ),
          );

          final summaryCards = Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MiniStat(
                label: '收入',
                value: _currency(overview!.totalIncomeCents),
              ),
              _MiniStat(
                label: '支出',
                value: _currency(overview!.totalExpenseCents),
              ),
              _MiniStat(
                label: '净收入',
                value: _currency(overview!.netIncomeCents),
              ),
              _MiniStat(
                label: '实际时薪',
                value: summary?.actualHourlyRateCents == null
                    ? '暂无数据'
                    : _currency(summary!.actualHourlyRateCents!),
              ),
            ],
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                chart,
                const SizedBox(height: 16),
                summaryCards,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: chart),
              const SizedBox(width: 18),
              Expanded(flex: 2, child: summaryCards),
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
          width: 28,
          borderRadius: BorderRadius.circular(8),
          color: color,
        ),
      ],
    );
  }

  String _currency(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
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
