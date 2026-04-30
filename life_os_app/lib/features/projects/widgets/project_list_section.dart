import 'package:flutter/material.dart';

import '../../../models/project_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ProjectListSection extends StatelessWidget {
  const ProjectListSection({
    super.key,
    required this.state,
    required this.onOpen,
  });

  final List<ProjectOverview>? state;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    if (state == null) {
      return const SectionCard(
        eyebrow: 'Projects',
        title: '项目列表',
        child: SectionMessageView(
          icon: Icons.folder_open_rounded,
          title: '项目列表待加载',
          description: '等待项目查询接口返回。',
        ),
      );
    }

    return SectionCard(
      eyebrow: 'Projects',
      title: '项目列表',
      child: Column(
        children: [
          for (final item in state!) ...[
            InkWell(
              onTap: () => onOpen(item.id),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.42),
                  borderRadius: BorderRadius.circular(20),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.58)),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  children: [
                    Text(item.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text('状态: ${item.statusCode}'),
                    Text('时间: ${item.totalTimeMinutes} 分钟'),
                    Text(
                        '收入: ¥${(item.totalIncomeCents / 100).toStringAsFixed(2)}'),
                    Text(
                        '支出: ¥${(item.totalExpenseCents / 100).toStringAsFixed(2)}'),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
