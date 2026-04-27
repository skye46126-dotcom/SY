import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/ai_models.dart';
import '../../models/sync_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ViewState<AiServiceConfigModel?> _aiState = ViewState.initial();
  ViewState<CloudSyncConfigModel?> _cloudState = ViewState.initial();
  ViewState<String> _demoState = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    setState(() {
      _aiState = ViewState.loading();
      _cloudState = ViewState.loading();
    });
    try {
      final service = LifeOsScope.of(context);
      final runtime = LifeOsScope.runtimeOf(context);
      final ai = await service.getActiveAiServiceConfig(
        userId: runtime.userId,
      );
      final cloud = await service.getActiveCloudSyncConfig(
        userId: runtime.userId,
      );
      if (!mounted) return;
      setState(() {
        _aiState = ViewState.ready(ai);
        _cloudState = ViewState.ready(cloud);
      });
    } catch (error) {
      setState(() {
        _aiState = ViewState.error(error.toString());
        _cloudState = ViewState.error(error.toString());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final runtime = LifeOsScope.runtimeOf(context);
    final profile = runtime.profile;
    return ModulePage(
      title: '设置',
      subtitle: 'Settings',
      children: [
        SectionCard(
          eyebrow: 'General',
          title: '通用设置',
          child: Column(
            children: [
              if (profile != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(profile.displayName),
                  subtitle: Text(
                    '${profile.username} · ${profile.timezone} · ${profile.currencyCode}',
                  ),
                ),
              _SettingsLink(
                title: '经营参数',
                description: '理想时薪、每日目标、时区和币种。',
                onTap: () =>
                    Navigator.of(context).pushNamed('/settings/operating'),
              ),
              const SizedBox(height: 12),
              _SettingsLink(
                title: '标签管理',
                description: '统一管理标签维度和层级。',
                onTap: () => Navigator.of(context).pushNamed('/settings/tags'),
              ),
              const SizedBox(height: 12),
              _SettingsLink(
                title: '维度管理',
                description: '维护时间、收入、支出、学习与项目状态类型。',
                onTap: () =>
                    Navigator.of(context).pushNamed('/settings/dimensions'),
              ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Integration',
          title: '集成与同步',
          child: Column(
            children: [
              _SettingsLink(
                title: 'AI 服务配置',
                description: switch (_aiState.status) {
                  ViewStatus.data when _aiState.data != null =>
                    '${_aiState.data!.provider} · ${_aiState.data!.model ?? '-'}',
                  ViewStatus.loading => '正在读取 AI 配置',
                  _ => _aiState.message ?? '当前没有激活的 AI 配置',
                },
                onTap: () =>
                    Navigator.of(context).pushNamed('/settings/ai-services'),
              ),
              const SizedBox(height: 12),
              _SettingsLink(
                title: '导出中心',
                description: '状态图片文档、归档规则与数据库备份入口。',
                onTap: () =>
                    Navigator.of(context).pushNamed('/settings/export-center'),
              ),
              const SizedBox(height: 12),
              _SettingsLink(
                title: '备份与恢复',
                description: '本地与远程备份入口。',
                onTap: () =>
                    Navigator.of(context).pushNamed('/settings/backup'),
              ),
              const SizedBox(height: 12),
              _SettingsLink(
                title: '云同步配置',
                description: switch (_cloudState.status) {
                  ViewStatus.data when _cloudState.data != null =>
                    '${_cloudState.data!.provider} · ${_cloudState.data!.endpointUrl ?? '-'}',
                  ViewStatus.loading => '正在读取云同步配置',
                  _ => _cloudState.message ?? '当前没有激活的云同步配置',
                },
                onTap: () =>
                    Navigator.of(context).pushNamed('/settings/cloud-sync'),
              ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Demo',
          title: '演示数据',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_demoState.status == ViewStatus.loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SectionLoadingView(label: '正在处理演示数据'),
                ),
              if (_demoState.status == ViewStatus.data)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_demoState.data!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              if (_demoState.status == ViewStatus.error)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _demoState.message ?? '演示数据操作失败',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _seedDemoData,
                      child: const Text('注入演示数据'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearDemoData,
                      child: const Text('清空演示数据'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _seedDemoData() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    setState(() => _demoState = ViewState.loading());
    try {
      final result = await service.invokeRaw(
        method: 'seed_demo_data',
        payload: {'user_id': runtime.userId},
      );
      if (!mounted) return;
      setState(() {
        _demoState = ViewState.ready(
          (result as Map?)?['message']?.toString() ?? 'demo data seeded',
        );
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _demoState = ViewState.error(error.toString()));
    }
  }

  Future<void> _clearDemoData() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    setState(() => _demoState = ViewState.loading());
    try {
      final result = await service.invokeRaw(
        method: 'clear_demo_data',
        payload: {'user_id': runtime.userId},
      );
      if (!mounted) return;
      setState(() {
        _demoState = ViewState.ready(
          (result as Map?)?['message']?.toString() ?? 'demo data cleared',
        );
      });
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _demoState = ViewState.error(error.toString()));
    }
  }
}

class _SettingsLink extends StatelessWidget {
  const _SettingsLink({
    required this.title,
    required this.description,
    this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
