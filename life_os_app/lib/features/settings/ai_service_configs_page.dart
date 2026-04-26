import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/ai_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class AiServiceConfigsPage extends StatefulWidget {
  const AiServiceConfigsPage({super.key});

  @override
  State<AiServiceConfigsPage> createState() => _AiServiceConfigsPageState();
}

class _AiServiceConfigsPageState extends State<AiServiceConfigsPage> {
  ViewState<List<AiServiceConfigModel>> _state = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    setState(() => _state = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final items = await LifeOsScope.of(context).listAiServiceConfigs(
        userId: runtime.userId,
      );
      if (!mounted) return;
      setState(() {
        _state = items.isEmpty ? ViewState.empty('暂无 AI 配置。') : ViewState.ready(items);
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
      title: 'AI 服务配置',
      subtitle: 'AI Configs',
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
            ViewStatus.loading => const SectionLoadingView(label: '正在读取 AI 配置'),
            ViewStatus.data => Column(
                children: [
                  for (final item in _state.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.isActive ? Icons.check_circle : Icons.tune,
                      ),
                      title: Text('${item.provider} · ${item.model ?? '-'}'),
                      subtitle: Text(
                        '${item.parserMode} · ${item.baseUrl ?? '-'}',
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
                icon: Icons.tune_rounded,
                title: 'AI 配置暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
      ],
    );
  }

  Future<void> _activate(AiServiceConfigModel item) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'update_ai_service_config',
      payload: {
        'config_id': item.id,
        'input': {
          'user_id': runtime.userId,
          'provider': item.provider,
          'base_url': item.baseUrl,
          'api_key_encrypted': item.apiKeyEncrypted,
          'model': item.model,
          'system_prompt': item.systemPrompt,
          'parser_mode': _toRustParserMode(item.parserMode),
          'temperature_milli': item.temperatureMilli,
          'is_active': true,
        },
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _delete(AiServiceConfigModel item) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'delete_ai_service_config',
      payload: {
        'user_id': runtime.userId,
        'config_id': item.id,
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openConfigDialog({AiServiceConfigModel? existing}) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final provider = TextEditingController(text: existing?.provider ?? 'deepseek');
    final baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    final model = TextEditingController(text: existing?.model ?? '');
    final apiKey = TextEditingController(text: existing?.apiKeyEncrypted ?? '');
    final parserMode = TextEditingController(text: _displayParserMode(existing?.parserMode ?? 'auto'));
    final temperature = TextEditingController(text: existing?.temperatureMilli?.toString() ?? '');
    final systemPrompt = TextEditingController(text: existing?.systemPrompt ?? '');
    bool isActive = existing?.isActive ?? true;
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: Text(existing == null ? '新增 AI 配置' : '编辑 AI 配置'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    TextField(controller: provider, decoration: const InputDecoration(labelText: 'Provider')),
                    TextField(controller: baseUrl, decoration: const InputDecoration(labelText: 'Base URL')),
                    TextField(controller: model, decoration: const InputDecoration(labelText: 'Model')),
                    TextField(controller: apiKey, decoration: const InputDecoration(labelText: 'API Key')),
                    TextField(controller: parserMode, decoration: const InputDecoration(labelText: 'Parser Mode')),
                    TextField(controller: temperature, decoration: const InputDecoration(labelText: 'Temperature Milli')),
                    TextField(controller: systemPrompt, decoration: const InputDecoration(labelText: 'System Prompt'), maxLines: 4),
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
        method: existing == null ? 'create_ai_service_config' : 'update_ai_service_config',
        payload: {
          if (existing != null) 'config_id': existing.id,
          'input': {
            'user_id': runtime.userId,
            'provider': provider.text,
            'base_url': baseUrl.text.isEmpty ? null : baseUrl.text,
            'api_key_encrypted': apiKey.text.isEmpty ? null : apiKey.text,
            'model': model.text.isEmpty ? null : model.text,
            'system_prompt': systemPrompt.text.isEmpty ? null : systemPrompt.text,
            'parser_mode': parserMode.text.isEmpty ? null : _toRustParserMode(parserMode.text),
            'temperature_milli': int.tryParse(temperature.text),
            'is_active': isActive,
          },
        },
      );
      if (!mounted) return;
      await _load();
    } finally {
      provider.dispose();
      baseUrl.dispose();
      model.dispose();
      apiKey.dispose();
      parserMode.dispose();
      temperature.dispose();
      systemPrompt.dispose();
    }
  }

  String _toRustParserMode(String value) {
    switch (value.trim().toLowerCase()) {
      case 'rule':
        return 'Rule';
      case 'llm':
        return 'Llm';
      case 'vcp':
        return 'Vcp';
      default:
        return 'Auto';
    }
  }

  String _displayParserMode(String value) {
    final lower = value.toLowerCase();
    if (lower == 'auto' || lower == 'rule' || lower == 'llm' || lower == 'vcp') {
      return lower;
    }
    return value;
  }
}
