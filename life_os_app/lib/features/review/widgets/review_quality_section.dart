import 'package:flutter/material.dart';

import '../../../models/review_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewQualitySection extends StatelessWidget {
  const ReviewQualitySection({
    super.key,
    required this.report,
  });

  final ReviewReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const SectionCard(
        eyebrow: 'Efficiency',
        title: '效率与 AI',
        child: SectionMessageView(
          icon: Icons.speed_rounded,
          title: '效率指标暂不可用',
          description: '当前没有可展示的 AI 与效率质量数据。',
        ),
      );
    }

    return SectionCard(
      eyebrow: 'Efficiency',
      title: '效率与 AI',
      child: Column(
        children: [
          _QualityRow(
            label: 'AI 辅助率',
            value: report!.aiAssistRate,
            color: const Color(0xFF2363FF),
          ),
          const SizedBox(height: 14),
          _QualityRow(
            label: '工作效率',
            value: report!.workEfficiencyAvg == null
                ? null
                : report!.workEfficiencyAvg! / 10,
            color: const Color(0xFF0F9D84),
            rightLabel: report!.workEfficiencyAvg == null
                ? '暂无数据'
                : '${report!.workEfficiencyAvg!.toStringAsFixed(1)} / 10',
          ),
          const SizedBox(height: 14),
          _QualityRow(
            label: '学习效率',
            value: report!.learningEfficiencyAvg == null
                ? null
                : report!.learningEfficiencyAvg! / 10,
            color: const Color(0xFFFF8A3D),
            rightLabel: report!.learningEfficiencyAvg == null
                ? '暂无数据'
                : '${report!.learningEfficiencyAvg!.toStringAsFixed(1)} / 10',
          ),
        ],
      ),
    );
  }
}

class _QualityRow extends StatelessWidget {
  const _QualityRow({
    required this.label,
    required this.value,
    required this.color,
    this.rightLabel,
  });

  final String label;
  final double? value;
  final Color color;
  final String? rightLabel;

  @override
  Widget build(BuildContext context) {
    final normalized = (value ?? 0).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(label, style: Theme.of(context).textTheme.titleMedium),
            ),
            Text(
              rightLabel ??
                  (value == null ? '暂无数据' : '${(normalized * 100).toStringAsFixed(1)}%'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: normalized,
            minHeight: 14,
            backgroundColor: const Color(0xFFE7EDF7),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}
