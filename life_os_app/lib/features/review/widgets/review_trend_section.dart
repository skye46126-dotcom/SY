import 'package:fl_chart/fl_chart.dart';
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

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const SectionCard(
        eyebrow: 'Trends',
        title: '本期 vs 上期',
        child: SectionMessageView(
          icon: Icons.show_chart_rounded,
          title: '趋势图暂不可用',
          description: '等待收入、支出和工作时长的对比数据。',
        ),
      );
    }

    final currentIncome = report!.totalIncomeCents / 100;
    final previousIncome = report!.previousIncomeCents / 100;
    final currentExpense = report!.totalExpenseCents / 100;
    final previousExpense = report!.previousExpenseCents / 100;
    final currentWork = report!.totalWorkMinutes.toDouble();
    final previousWork = report!.previousWorkMinutes.toDouble();
    final maxValue = [
      currentIncome,
      previousIncome,
      currentExpense,
      previousExpense,
      currentWork,
      previousWork,
      1.0,
    ].reduce((a, b) => a > b ? a : b);

    return SectionCard(
      eyebrow: 'Trends',
      title: '本期 vs 上期',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 260,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue * 1.25,
                groupsSpace: 20,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
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
                        const labels = ['收入', '支出', '工作'];
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
                  _group(0, currentIncome, previousIncome),
                  _group(1, currentExpense, previousExpense),
                  _group(2, currentWork, previousWork),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TrendChip(label: '收入变化', value: _ratio(report!.incomeChangeRatio)),
              _TrendChip(label: '支出变化', value: _ratio(report!.expenseChangeRatio)),
              _TrendChip(label: '工作变化', value: _ratio(report!.workChangeRatio)),
              _TrendChip(label: '被动覆盖', value: _ratio(report!.passiveCoverRatio)),
              _TrendChip(
                label: '快照时薪',
                value: snapshot?.hourlyRateCents == null
                    ? '暂无数据'
                    : '¥${(snapshot!.hourlyRateCents! / 100).toStringAsFixed(2)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _group(int x, double current, double previous) {
    return BarChartGroupData(
      x: x,
      barsSpace: 6,
      barRods: [
        BarChartRodData(
          toY: current,
          width: 16,
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFF2363FF),
        ),
        BarChartRodData(
          toY: previous,
          width: 16,
          borderRadius: BorderRadius.circular(6),
          color: const Color(0xFF8C9BB2),
        ),
      ],
    );
  }

  String _ratio(double? value) {
    if (value == null) {
      return '无法计算';
    }
    final prefix = value > 0 ? '+' : '';
    return '$prefix${(value * 100).toStringAsFixed(1)}%';
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.56)),
      ),
      child: Text(
        '$label · $value',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: const Color(0xFF152033),
            ),
      ),
    );
  }
}
