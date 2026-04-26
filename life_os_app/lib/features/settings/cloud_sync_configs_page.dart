import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/sync_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class CloudSyncConfigsPage extends StatefulWidget {
  const CloudSyncConfigsPage({super.key});

  @override
  State<CloudSyncConfigsPage> createState() => _CloudSyncConfigsPageState();
}

class _CloudSyncConfigsPageState extends State<CloudSyncConfigsPage> {
  ViewState<List<CloudSyncConfigModel>> _state = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    setState(() => _state = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final items = await LifeOsScope.of(context).listCloudSyncConfigs(
        userId: runtime.userId,
      );
      if (!mounted) return;
      setState(() {
        _state = items.isEmpty ? ViewState.empty('暂无云同步配置。') : ViewState.ready(items);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = ViewState.error(error.toString()));
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '云同步配置',
      subtitle: 'Cloud Sync',
      actions: [
        ElevatedButton(
          onPressed: () => _openConfigDialog(),
          child: const Text('新增配置'),
        ),
        OutlinedButton(
          onPressed: _load,
          child: const Text('刷新'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Configs',
          title: '配置列表',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取云同步配置'),
            ViewStatus.data => Column(
                children: [
                  for (final item in _state.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(item.isActive ? Icons.cloud_done : Icons.cloud_queue),
                      title: Text('${item.provider} · ${item.endpointUrl ?? '-'}'),
                      subtitle: Text(
                        '${item.bucketName ?? '-'} · ${item.region ?? '-'} · ${item.rootPath ?? '-'}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'activate':
                              _activate(item);
                            case 'edit':
                              _openConfigDialog(existing: item);
                            case 'delete':
                              _delete(item);
                          }
                        },
                        itemBuilder: (context) => [
                          if (!item.isActive)
                            const PopupMenuItem(value: 'activate', child: Text('设为激活')),
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ),
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.cloud_outlined,
                title: '云同步配置暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
      ],
    );
  }

  Future<void> _activate(CloudSyncConfigModel item) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'update_cloud_sync_config',
      payload: {
        'config_id': item.id,
        'input': {
          'user_id': runtime.userId,
          'provider': item.provider,
          'endpoint_url': item.endpointUrl,
          'bucket_name': item.bucketName,
          'region': item.region,
          'root_path': item.rootPath,
          'device_id': item.accessKeyId ?? 'android',
          'api_key_encrypted': item.secretEncrypted ?? '',
          'is_active': true,
        },
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(CloudSyncConfigModel item) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'delete_cloud_sync_config',
      payload: {
        'user_id': runtime.userId,
        'config_id': item.id,
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openConfigDialog({CloudSyncConfigModel? existing}) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final provider = TextEditingController(text: existing?.provider ?? 'lifeos_http');
    final endpoint = TextEditingController(text: existing?.endpointUrl ?? '');
    final bucket = TextEditingController(text: existing?.bucketName ?? '');
    final region = TextEditingController(text: existing?.region ?? '');
    final rootPath = TextEditingController(text: existing?.rootPath ?? '');
    final deviceId = TextEditingController(text: existing?.accessKeyId ?? 'android');
    final apiKey = TextEditingController(text: existing?.secretEncrypted ?? '');
    bool isActive = existing?.isActive ?? true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(existing == null ? '新增云同步配置' : '编辑云同步配置'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: provider, decoration: const InputDecoration(labelText: 'Provider')),
                    TextField(controller: endpoint, decoration: const InputDecoration(labelText: 'Endpoint URL')),
                    TextField(controller: bucket, decoration: const InputDecoration(labelText: 'Bucket')),
                    TextField(controller: region, decoration: const InputDecoration(labelText: 'Region')),
                    TextField(controller: rootPath, decoration: const InputDecoration(labelText: 'Root Path')),
                    TextField(controller: deviceId, decoration: const InputDecoration(labelText: 'Device ID')),
                    TextField(controller: apiKey, decoration: const InputDecoration(labelText: 'API Key')),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) => setState(() => isActive = value),
                      title: const Text('激活'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
              ],
            ),
          );
        },
      );
      if (confirmed != true) return;
      await service.invokeRaw(
        method: existing == null ? 'create_cloud_sync_config' : 'update_cloud_sync_config',
        payload: {
          if (existing != null) 'config_id': existing.id,
          'input': {
            'user_id': runtime.userId,
            'provider': provider.text,
            'endpoint_url': endpoint.text,
            'bucket_name': bucket.text.isEmpty ? null : bucket.text,
            'region': region.text.isEmpty ? null : region.text,
            'root_path': rootPath.text.isEmpty ? null : rootPath.text,
            'device_id': deviceId.text,
            'api_key_encrypted': apiKey.text,
            'is_active': isActive,
          },
        },
      );
      if (!mounted) return;
      await _load();
    } finally {
      provider.dispose();
      endpoint.dispose();
      bucket.dispose();
      region.dispose();
      rootPath.dispose();
      deviceId.dispose();
      apiKey.dispose();
    }
  }
}
