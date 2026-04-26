import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/state_views.dart';
import 'projects_controller.dart';
import 'widgets/project_list_section.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  ProjectsController? _controller;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ProjectsController(LifeOsScope.of(context));
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller!.load(userId: LifeOsScope.runtimeOf(context).userId);
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ModulePage(
          title: '项目管理',
          subtitle: 'Projects',
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('返回'),
            ),
          ],
          children: [
            Wrap(
              spacing: 10,
              children: [
                ChoiceChip(
                  label: const Text('全部'),
                  selected: controller.statusCode == null,
                  onSelected: (_) => controller.changeStatus(
                    null,
                    LifeOsScope.runtimeOf(context).userId,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Active / Paused'),
                  selected: controller.statusCode == 'active',
                  onSelected: (_) => controller.changeStatus(
                    'active',
                    LifeOsScope.runtimeOf(context).userId,
                  ),
                ),
                ChoiceChip(
                  label: const Text('Done'),
                  selected: controller.statusCode == 'done',
                  onSelected: (_) => controller.changeStatus(
                    'done',
                    LifeOsScope.runtimeOf(context).userId,
                  ),
                ),
              ],
            ),
            if (controller.state.status == ViewStatus.loading)
              const SectionLoadingView(label: '正在读取项目列表'),
            if (controller.state.status == ViewStatus.empty ||
                controller.state.status == ViewStatus.unavailable ||
                controller.state.status == ViewStatus.error)
              SectionMessageView(
                icon: Icons.inventory_2_outlined,
                title: '项目列表暂不可用',
                description: controller.state.message ?? '请稍后重试。',
              ),
            ProjectListSection(
              state: controller.state.hasData ? controller.state.data : null,
              onOpen: (projectId) {
                Navigator.of(context).pushNamed('/projects/$projectId');
              },
            ),
          ],
        );
      },
    );
  }
}
