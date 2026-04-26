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
        ManagementListGroup(
          eyebrow: 'Data Management',
          title: '数据管理',
          items: [
            ManagementEntry(
              title: '收入流水',
              description: '查看收入记录、来源与回款结构。',
              onTap: () => Navigator.of(context).pushNamed('/ledger/income'),
            ),
            ManagementEntry(
              title: '支出流水',
              description: '查看支出记录、类别与必要支出。',
              onTap: () => Navigator.of(context).pushNamed('/ledger/expense'),
            ),
            ManagementEntry(
              title: '时间记录',
              description: '按日期查看时间投入与当日详情。',
              onTap: () => Navigator.of(context).pushNamed('/time-management'),
            ),
          ],
        ),
        ManagementListGroup(
          eyebrow: 'Operating Management',
          title: '经营管理',
          items: [
            ManagementEntry(
              title: '项目管理',
              description: '进入项目列表和项目详情分析页。',
              onTap: () => Navigator.of(context).pushNamed('/projects'),
            ),
            ManagementEntry(
              title: '成本管理',
              description: '承接结构化成本、固定成本与 CAPEX。',
              onTap: () => Navigator.of(context).pushNamed('/cost-management'),
            ),
            ManagementEntry(
              title: '标签管理',
              description: '维护统一标签维度与层级关系。',
              onTap: () => Navigator.of(context).pushNamed('/settings/tags'),
            ),
          ],
        ),
        ManagementListGroup(
          eyebrow: 'System Management',
          title: '系统管理',
          muted: true,
          items: [
            ManagementEntry(
              title: '设置',
              description: '通用配置、AI 服务、同步和迁移入口。',
              onTap: () => Navigator.of(context).pushNamed('/settings'),
            ),
          ],
        ),
      ],
    );
  }
}
