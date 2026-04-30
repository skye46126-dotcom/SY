import 'package:flutter/material.dart';

import '../../shared/widgets/module_page.dart';
import 'widgets/management_group_card.dart';

class ManagementPage extends StatelessWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '管理',
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
              title: '经营参数',
              description: '理想时薪、每日目标与长期配置。',
              onTap: () =>
                  Navigator.of(context).pushNamed('/settings/operating'),
            ),
            ManagementEntry(
              title: '标签管理',
              description: '维护统一标签维度与层级关系。',
              onTap: () => Navigator.of(context).pushNamed('/settings/tags'),
            ),
            ManagementEntry(
              title: '维度管理',
              description: '维护类型选项，避免自由文本制造脏数据。',
              onTap: () =>
                  Navigator.of(context).pushNamed('/settings/dimensions'),
            ),
          ],
        ),
      ],
    );
  }
}
