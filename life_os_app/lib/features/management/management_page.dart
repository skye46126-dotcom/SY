import 'package:flutter/material.dart';

import '../../shared/widgets/module_page.dart';
import 'widgets/management_group_card.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '分组管理入口',
      subtitle: 'Management',
      children: [
        ManagementGroupCard(
          eyebrow: 'Data Management',
          title: '数据管理',
          items: const [
            ManagementEntry(
              title: '收入流水',
              description: '查看收入记录、来源与回款结构。',
            ),
            ManagementEntry(
              title: '支出流水',
              description: '查看支出记录、类别与必要支出。',
            ),
            ManagementEntry(
              title: '时间记录',
              description: '按日期查看时间投入与当日详情。',
            ),
          ].map((entry) => ManagementEntry(
                title: entry.title,
                description: entry.description,
                onTap: switch (entry.title) {
                  '收入流水' => () => Navigator.of(context).pushNamed('/ledger/income'),
                  '支出流水' => () => Navigator.of(context).pushNamed('/ledger/expense'),
                  _ => () => Navigator.of(context).pushNamed('/time-management'),
                },
              )).toList(),
        ),
        ManagementGroupCard(
          eyebrow: 'Operating Management',
          title: '经营管理',
          items: const [
            ManagementEntry(
              title: '项目管理',
              description: '进入项目列表和项目详情分析页。',
            ),
            ManagementEntry(
              title: '成本管理',
              description: '承接结构化成本、固定成本与 CAPEX。',
            ),
            ManagementEntry(
              title: '标签管理',
              description: '维护统一标签维度与层级关系。',
            ),
          ].map((entry) => ManagementEntry(
                title: entry.title,
                description: entry.description,
                onTap: switch (entry.title) {
                  '项目管理' => () => Navigator.of(context).pushNamed('/projects'),
                  '成本管理' => () => Navigator.of(context).pushNamed('/cost-management'),
                  _ => () => Navigator.of(context).pushNamed('/settings/tags'),
                },
              )).toList(),
        ),
        ManagementGroupCard(
          eyebrow: 'System Management',
          title: '系统管理',
          items: const [
            ManagementEntry(
              title: '设置',
              description: '通用配置、AI 服务、同步和迁移入口。',
            ),
            ManagementEntry(
              title: '备份与恢复',
              description: '本地/远程备份、恢复和状态记录。',
            ),
            ManagementEntry(
              title: 'AI 配置',
              description: '为 AI 解析和写入保留独立配置入口。',
            ),
          ].map((entry) => ManagementEntry(
                title: entry.title,
                description: entry.description,
                onTap: switch (entry.title) {
                  '设置' => () => Navigator.of(context).pushNamed('/settings'),
                  '备份与恢复' => () => Navigator.of(context).pushNamed('/settings/backup'),
                  _ => () => Navigator.of(context).pushNamed('/settings'),
                },
              )).toList(),
        ),
      ],
    );
  }
}
