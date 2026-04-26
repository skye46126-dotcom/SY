import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/ai_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class AiChatPage extends StatefulWidget {
  const AiChatPage({super.key});

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends State<AiChatPage> {
  final TextEditingController _rawInputController = TextEditingController();
  final TextEditingController _contextDateController = TextEditingController();
  String _parserMode = 'auto';
  bool _autoCreateTags = false;
  ViewState<AiServiceConfigModel?> _configState = ViewState.initial();
  ViewState<AiParseResultModel> _parseState = ViewState.initial();
  ViewState<AiCommitResultModel> _commitState = ViewState.initial();
  List<AiParseDraftModel> _editableDrafts = const [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final runtime = LifeOsScope.runtimeOf(context);
    _contextDateController.text = runtime.todayDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadConfig();
    });
  }

  @override
  void dispose() {
    _rawInputController.dispose();
    _contextDateController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _configState = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final config = await LifeOsScope.of(context).getActiveAiServiceConfig(
        userId: runtime.userId,
      );
      if (!mounted) return;
      setState(() {
        _configState = ViewState.ready(config);
        if (config != null) {
          _parserMode = _normalizeParserMode(config.parserMode);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _configState = ViewState.error(error.toString()));
    }
  }

  Future<void> _parse() async {
    final runtime = LifeOsScope.runtimeOf(context);
    setState(() => _parseState = ViewState.loading());
    try {
      final result = await LifeOsScope.of(context).parseAiCapture(
        userId: runtime.userId,
        rawInput: _rawInputController.text,
        parserMode: _parserMode,
      );
      if (!mounted) return;
      if (result == null) {
        setState(() => _parseState = ViewState.empty('AI 没有返回解析结果。'));
        return;
      }
      setState(() {
        final parsed = AiParseResultModel.fromJson(result.cast<String, dynamic>());
        _editableDrafts = parsed.items;
        _parseState = ViewState.ready(parsed);
        _commitState = ViewState.initial();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _parseState = ViewState.error(error.toString()));
    }
  }

  Future<void> _commit() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final parsed = _parseState.data;
    if (parsed == null || _editableDrafts.isEmpty) {
      return;
    }
    setState(() => _commitState = ViewState.loading());
    try {
      final result = await LifeOsScope.of(context).invokeRaw(
        method: 'commit_ai_drafts',
        payload: {
          'user_id': runtime.userId,
          'request_id': parsed.requestId,
          'context_date': _contextDateController.text,
          'drafts': _editableDrafts.map((item) => item.toJson()).toList(),
          'options': {
            'source': 'external',
            'auto_create_tags': _autoCreateTags,
            'strict_reference_resolution': false,
          },
        },
      );
      if (!mounted) return;
      setState(() {
        _commitState = ViewState.ready(
          AiCommitResultModel.fromJson((result as Map).cast<String, dynamic>()),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _commitState = ViewState.error(error.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: 'AI Chat',
      subtitle: 'Review Assistant',
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed('/settings/ai-services'),
          child: const Text('管理配置'),
        ),
        ElevatedButton(
          onPressed: _parse,
          child: const Text('解析草稿'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'AI Config',
          title: '当前激活配置',
          child: switch (_configState.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取 AI 配置'),
            ViewStatus.data when _configState.data != null => Text(
                '${_configState.data!.provider} · ${_configState.data!.model ?? '-'} · parser=$_parserMode',
              ),
            _ => SectionMessageView(
                icon: Icons.tune_rounded,
                title: '没有激活的 AI 配置',
                description: _configState.message ?? '请先在设置中创建并激活配置。',
              ),
          },
        ),
        SectionCard(
          eyebrow: 'Prompt',
          title: '输入与解析选项',
          child: Column(
            children: [
              TextField(
                controller: _contextDateController,
                decoration: const InputDecoration(labelText: '上下文日期 YYYY-MM-DD'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final mode in const ['auto', 'rule', 'llm', 'vcp'])
                    ChoiceChip(
                      label: Text(mode),
                      selected: _parserMode == mode,
                      onSelected: (_) => setState(() => _parserMode = mode),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                value: _autoCreateTags,
                onChanged: (value) => setState(() => _autoCreateTags = value),
                title: const Text('提交时自动创建标签'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _rawInputController,
                minLines: 8,
                maxLines: 12,
                decoration: const InputDecoration(
                  labelText: '输入自然语言',
                  hintText: '例如：今天下午做了 2 小时深度工作，项目是 SkyeOS，效率 8，AI 占比 30%',
                ),
              ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Parsed Drafts',
          title: '解析结果',
          trailing: ElevatedButton(
            onPressed: _parseState.hasData && _parseState.data!.items.isNotEmpty ? _commit : null,
            child: const Text('确认入库'),
          ),
          child: switch (_parseState.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在解析草稿'),
            ViewStatus.data => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('parser: ${_parseState.data!.parserUsed}'),
                  if (_parseState.data!.warnings.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final warning in _parseState.data!.warnings)
                      Text('warning: $warning'),
                  ],
                  const SizedBox(height: 16),
                  for (final item in _parseState.data!.items)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${item.kind} · confidence ${(item.confidence * 100).toStringAsFixed(1)}%'),
                          const SizedBox(height: 8),
                          for (final entry in item.payload.entries)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text('${entry.key}: ${entry.value}'),
                            ),
                          if (item.warning != null) ...[
                            const SizedBox(height: 8),
                            Text('warning: ${item.warning}'),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: () => _editDraft(item),
                                child: const Text('修改草稿'),
                              ),
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: () => _removeDraft(item.draftId),
                                child: const Text('移除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ViewStatus.empty => SectionMessageView(
                icon: Icons.auto_awesome_rounded,
                title: '没有可提交草稿',
                description: _parseState.message ?? '请调整输入后重试。',
              ),
            ViewStatus.error => SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '解析失败',
                description: _parseState.message ?? '请稍后重试。',
              ),
            _ => const SectionMessageView(
                icon: Icons.auto_awesome_rounded,
                title: '等待解析',
                description: '输入内容后点击“解析草稿”。',
              ),
          },
        ),
        SectionCard(
          eyebrow: 'Commit Result',
          title: '入库结果',
          child: switch (_commitState.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在提交草稿'),
            ViewStatus.data => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_commitState.data!.committed.isNotEmpty) ...[
                    Text('成功提交 ${_commitState.data!.committed.length} 条'),
                    const SizedBox(height: 8),
                    for (final item in _commitState.data!.committed)
                      Text('${item.kind} · ${item.recordId} · ${item.occurredAt}'),
                  ],
                  if (_commitState.data!.failures.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('失败 ${_commitState.data!.failures.length} 条'),
                    const SizedBox(height: 8),
                    for (final item in _commitState.data!.failures)
                      Text('${item.kind} · ${item.message}'),
                  ],
                  if (_commitState.data!.warnings.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final warning in _commitState.data!.warnings)
                      Text('warning: $warning'),
                  ],
                ],
              ),
            ViewStatus.error => SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '提交失败',
                description: _commitState.message ?? '请稍后重试。',
              ),
            _ => const SectionMessageView(
                icon: Icons.checklist_rounded,
                title: '等待提交',
                description: '解析出草稿后，可以在这里确认入库结果。',
              ),
          },
        ),
      ],
    );
  }

  String _normalizeParserMode(String value) {
    switch (value.toLowerCase()) {
      case 'auto':
      case 'rule':
      case 'llm':
      case 'vcp':
        return value.toLowerCase();
      default:
        return 'auto';
    }
  }

  Future<void> _editDraft(AiParseDraftModel draft) async {
    final kind = TextEditingController(text: draft.kind);
    final confidence = TextEditingController(
      text: (draft.confidence * 100).toStringAsFixed(1),
    );
    final warning = TextEditingController(text: draft.warning ?? '');
    final payloadControllers = {
      for (final entry in draft.payload.entries)
        entry.key: TextEditingController(text: entry.value),
    };
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('修改 AI 草稿'),
          content: SizedBox(
            width: 720,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: kind, decoration: const InputDecoration(labelText: 'Kind')),
                  TextField(controller: confidence, decoration: const InputDecoration(labelText: 'Confidence %')),
                  TextField(controller: warning, decoration: const InputDecoration(labelText: 'Warning')),
                  const SizedBox(height: 12),
                  for (final entry in payloadControllers.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(labelText: entry.key),
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('保存'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final updated = draft.copyWith(
        kind: kind.text.trim(),
        confidence: ((double.tryParse(confidence.text.trim()) ?? 0) / 100).clamp(0, 1),
        warning: warning.text.trim().isEmpty ? null : warning.text.trim(),
        payload: {
          for (final entry in payloadControllers.entries)
            entry.key: entry.value.text,
        },
      );
      setState(() {
        _editableDrafts = _editableDrafts
            .map((item) => item.draftId == draft.draftId ? updated : item)
            .toList();
        if (_parseState.hasData) {
          _parseState = ViewState.ready(
            AiParseResultModel(
              requestId: _parseState.data!.requestId,
              items: _editableDrafts,
              warnings: _parseState.data!.warnings,
              parserUsed: _parseState.data!.parserUsed,
            ),
          );
        }
      });
    } finally {
      kind.dispose();
      confidence.dispose();
      warning.dispose();
      for (final controller in payloadControllers.values) {
        controller.dispose();
      }
    }
  }

  void _removeDraft(String draftId) {
    setState(() {
      _editableDrafts = _editableDrafts.where((item) => item.draftId != draftId).toList();
      if (_parseState.hasData) {
        _parseState = ViewState.ready(
          AiParseResultModel(
            requestId: _parseState.data!.requestId,
            items: _editableDrafts,
            warnings: _parseState.data!.warnings,
            parserUsed: _parseState.data!.parserUsed,
          ),
        );
      }
    });
  }
}
