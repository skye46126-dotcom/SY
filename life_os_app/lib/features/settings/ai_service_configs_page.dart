import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/ai_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/safe_pop.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

const _customModelValue = '__custom_model__';

const _aiProviderPresets = [
  _AiProviderPreset(
    value: 'deepseek',
    label: 'DeepSeek',
    defaultBaseUrl: 'https://api.deepseek.com',
    defaultModel: 'deepseek-chat',
    models: [
      'deepseek-chat',
      'deepseek-reasoner',
    ],
  ),
  _AiProviderPreset(
    value: 'siliconflow',
    label: 'SiliconFlow',
    defaultBaseUrl: 'https://api.siliconflow.cn/v1',
    defaultModel: 'deepseek-ai/DeepSeek-V3',
    models: [
      'deepseek-ai/DeepSeek-V3',
      'Qwen/Qwen2.5-72B-Instruct',
      'Qwen/Qwen3-235B-A22B',
      'THUDM/GLM-4-9B-0414',
    ],
  ),
  _AiProviderPreset(
    value: 'custom',
    label: 'OpenAI 兼容',
    defaultBaseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    models: [
      'gpt-4o-mini',
      'gpt-4o',
      'gpt-4.1-mini',
      'gpt-4.1',
      'o4-mini',
      'deepseek-chat',
      'qwen-plus',
    ],
  ),
];

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
        _state = items.isEmpty
            ? ViewState.empty('暂无 AI 配置。')
            : ViewState.ready(items);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
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
                      title: Text(
                        '${_providerLabelFor(item.provider)} · ${item.model ?? '-'}',
                      ),
                      subtitle: Text(
                        item.baseUrl ?? '-',
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
                            const PopupMenuItem(
                                value: 'activate', child: Text('设为激活')),
                          const PopupMenuItem(value: 'edit', child: Text('编辑')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('删除')),
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
          'parser_mode': 'Llm',
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
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final runtime = LifeOsScope.runtimeOf(rootContext);
    final service = LifeOsScope.of(rootContext);
    var selectedProvider = _providerPresetFor(existing?.provider).value;
    var providerPreset = _providerPresetFor(selectedProvider);
    final baseUrl = TextEditingController(
      text: existing?.baseUrl ?? providerPreset.defaultBaseUrl ?? '',
    );
    final model = TextEditingController(
      text: existing?.model ?? providerPreset.defaultModel,
    );
    var selectedModelOption = providerPreset.models.contains(model.text)
        ? model.text
        : _customModelValue;
    final apiKey = TextEditingController(text: existing?.apiKeyEncrypted ?? '');
    final temperature = TextEditingController(
        text: existing?.temperatureMilli?.toString() ?? '');
    final systemPrompt =
        TextEditingController(text: existing?.systemPrompt ?? '');
    bool isActive = existing?.isActive ?? true;
    ViewState<String> testState = ViewState.initial();

    Map<String, Object?> inputPayload() => {
          'user_id': runtime.userId,
          'provider': selectedProvider,
          'base_url': baseUrl.text.trim().isEmpty ? null : baseUrl.text.trim(),
          'api_key_encrypted':
              apiKey.text.trim().isEmpty ? null : apiKey.text.trim(),
          'model': model.text.trim().isEmpty ? null : model.text.trim(),
          'system_prompt':
              systemPrompt.text.trim().isEmpty ? null : systemPrompt.text,
          'parser_mode': 'Llm',
          'temperature_milli': int.tryParse(temperature.text.trim()),
          'is_active': isActive,
        };

    try {
      final confirmed = await showDialog<bool>(
        context: rootContext,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContentContext, setDialogState) => AlertDialog(
              title: Text(existing == null ? '新增 AI 配置' : '编辑 AI 配置'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: selectedProvider,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Provider'),
                      items: [
                        for (final preset in _aiProviderPresets)
                          DropdownMenuItem(
                            value: preset.value,
                            child: Text(preset.label),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedProvider = value;
                          providerPreset = _providerPresetFor(value);
                          baseUrl.text = providerPreset.defaultBaseUrl ?? '';
                          model.text = providerPreset.defaultModel;
                          selectedModelOption = providerPreset.defaultModel;
                        });
                      },
                    ),
                    TextField(
                        controller: baseUrl,
                        decoration:
                            const InputDecoration(labelText: 'Base URL')),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        'model-$selectedProvider-$selectedModelOption',
                      ),
                      initialValue: selectedModelOption,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Model'),
                      items: [
                        for (final option in providerPreset.models)
                          DropdownMenuItem(
                            value: option,
                            child: Text(option),
                          ),
                        const DropdownMenuItem(
                          value: _customModelValue,
                          child: Text('自定义模型'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() {
                          selectedModelOption = value;
                          if (value != _customModelValue) {
                            model.text = value;
                          }
                        });
                      },
                    ),
                    if (selectedModelOption == _customModelValue)
                      TextField(
                          controller: model,
                          decoration:
                              const InputDecoration(labelText: '自定义模型')),
                    TextField(
                        controller: apiKey,
                        decoration:
                            const InputDecoration(labelText: 'API Key')),
                    TextField(
                        controller: temperature,
                        decoration: const InputDecoration(
                            labelText: 'Temperature Milli')),
                    TextField(
                        controller: systemPrompt,
                        decoration:
                            const InputDecoration(labelText: 'System Prompt'),
                        maxLines: 4),
                    SwitchListTile(
                      value: isActive,
                      onChanged: (value) =>
                          setDialogState(() => isActive = value),
                      title: const Text('激活'),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: testState.status == ViewStatus.loading
                            ? null
                            : () async {
                                setDialogState(
                                  () => testState = ViewState.loading(),
                                );
                                try {
                                  final result = await service.invokeRaw(
                                    method: 'test_ai_service_config',
                                    payload: {'input': inputPayload()},
                                  );
                                  final data = (result as Map?)
                                          ?.cast<String, dynamic>() ??
                                      const {};
                                  final modelName =
                                      data['model']?.toString() ?? model.text;
                                  setDialogState(
                                    () => testState =
                                        ViewState.ready('连接成功 · $modelName'),
                                  );
                                } catch (error) {
                                  setDialogState(
                                    () => testState =
                                        ViewState.error(error.toString()),
                                  );
                                }
                              },
                        icon: testState.status == ViewStatus.loading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.network_check_rounded),
                        label: const Text('检测连接'),
                      ),
                    ),
                    if (testState.status != ViewStatus.initial) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          testState.status == ViewStatus.loading
                              ? '正在检测当前配置'
                              : testState.message ?? testState.data ?? '',
                          style: Theme.of(dialogContext)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: testState.status == ViewStatus.error
                                    ? Theme.of(dialogContext).colorScheme.error
                                    : null,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => safePop(dialogContext, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => safePop(dialogContext, true),
                  child: const Text('保存'),
                ),
              ],
            ),
          );
        },
      );
      if (confirmed != true) return;
      await service.invokeRaw(
        method: existing == null
            ? 'create_ai_service_config'
            : 'update_ai_service_config',
        payload: {
          if (existing != null) 'config_id': existing.id,
          'input': inputPayload(),
        },
      );
      if (!mounted) return;
      await _load();
    } finally {
      baseUrl.dispose();
      model.dispose();
      apiKey.dispose();
      temperature.dispose();
      systemPrompt.dispose();
    }
  }

  _AiProviderPreset _providerPresetFor(String? value) {
    final normalized = value?.trim().toLowerCase();
    for (final preset in _aiProviderPresets) {
      if (preset.value == normalized) return preset;
    }
    return _aiProviderPresets.first;
  }

  String _providerLabelFor(String value) => _providerPresetFor(value).label;
}

class _AiProviderPreset {
  const _AiProviderPreset({
    required this.value,
    required this.label,
    required this.defaultModel,
    required this.models,
    this.defaultBaseUrl,
  });

  final String value;
  final String label;
  final String? defaultBaseUrl;
  final String defaultModel;
  final List<String> models;
}
