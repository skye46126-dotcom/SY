import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/review_models.dart';
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
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _anchorDateController = TextEditingController();
  final List<_ChatMessage> _messages = [];
  ReviewWindowKind _selectedKind = ReviewWindowKind.day;
  ViewState<String> _sendState = ViewState.initial();
  ViewState<String> _configState = ViewState.initial();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    final runtime = LifeOsScope.runtimeOf(context);
    _anchorDateController.text = runtime.todayDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadConfig();
    });
  }

  @override
  void dispose() {
    _questionController.dispose();
    _anchorDateController.dispose();
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
        _configState = config == null
            ? ViewState.empty('没有激活的 AI 配置')
            : ViewState.ready(
                '${config.provider} · ${config.model ?? '-'}',
              );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _configState = ViewState.error(error.toString()));
    }
  }

  Future<void> _send() async {
    final question = _questionController.text.trim();
    if (question.isEmpty || _sendState.status == ViewStatus.loading) {
      return;
    }
    final runtime = LifeOsScope.runtimeOf(context);
    final payload = _reviewPayload(runtime.userId, runtime.timezone, question);
    setState(() {
      _messages.add(_ChatMessage(role: _ChatRole.user, text: question));
      _sendState = ViewState.loading();
      _questionController.clear();
    });
    try {
      final result = await LifeOsScope.of(context).invokeRaw(
        method: 'chat_review',
        payload: payload,
      );
      final data = (result as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage(
            role: _ChatRole.assistant,
            text: data['answer']?.toString() ?? '',
          ),
        );
        _sendState = ViewState.initial();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _sendState = ViewState.error(error.toString()));
    }
  }

  Map<String, Object?> _reviewPayload(
    String userId,
    String timezone,
    String question,
  ) {
    final anchorDate = _anchorDateController.text.trim();
    return {
      'user_id': userId,
      'question': question,
      'kind': _selectedKind.name,
      'anchor_date': anchorDate,
      'start_date': anchorDate,
      'end_date': anchorDate,
      'timezone': timezone,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isSending = _sendState.status == ViewStatus.loading;
    return ModulePage(
      title: 'AI Chat',
      subtitle: 'Review Assistant',
      actions: [
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pushNamed('/settings/ai-services'),
          child: const Text('管理配置'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Review Context',
          title: '复盘范围',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (_configState.status) {
                ViewStatus.loading =>
                  const SectionLoadingView(label: '正在读取 AI 配置'),
                ViewStatus.data => Text('当前模型：${_configState.data}'),
                ViewStatus.error => SectionMessageView(
                    icon: Icons.error_outline_rounded,
                    title: 'AI 配置读取失败',
                    description: _configState.message ?? '请稍后重试。',
                  ),
                _ => SectionMessageView(
                    icon: Icons.tune_rounded,
                    title: '没有激活的 AI 配置',
                    description: _configState.message ?? '请先创建并激活配置。',
                  ),
              },
              const SizedBox(height: 14),
              TextField(
                controller: _anchorDateController,
                decoration: const InputDecoration(labelText: '锚点日期 YYYY-MM-DD'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  _WindowChip(
                    label: '日',
                    value: ReviewWindowKind.day,
                    selected: _selectedKind,
                    onSelected: _selectKind,
                  ),
                  _WindowChip(
                    label: '周',
                    value: ReviewWindowKind.week,
                    selected: _selectedKind,
                    onSelected: _selectKind,
                  ),
                  _WindowChip(
                    label: '月',
                    value: ReviewWindowKind.month,
                    selected: _selectedKind,
                    onSelected: _selectKind,
                  ),
                  _WindowChip(
                    label: '年',
                    value: ReviewWindowKind.year,
                    selected: _selectedKind,
                    onSelected: _selectKind,
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Conversation',
          title: '复盘对话',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_messages.isEmpty)
                const SectionMessageView(
                  icon: Icons.auto_awesome_rounded,
                  title: '开始复盘提问',
                  description: '可以问今天哪里低效、项目投入是否合理、支出是否异常或下一步优先级。',
                )
              else
                for (final message in _messages) ...[
                  _ChatBubble(message: message),
                  const SizedBox(height: 10),
                ],
              if (isSending) ...[
                const _ChatThinkingBubble(),
                const SizedBox(height: 10),
              ],
              if (_sendState.status == ViewStatus.error) ...[
                SectionMessageView(
                  icon: Icons.error_outline_rounded,
                  title: '发送失败',
                  description: _sendState.message ?? '请稍后重试。',
                ),
                const SizedBox(height: 10),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _questionController,
                      minLines: 1,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: '输入复盘问题',
                        hintText: '例如：这周我最大的时间浪费在哪里？',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: isSending ? null : _send,
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('发送'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _selectKind(ReviewWindowKind kind) {
    setState(() => _selectedKind = kind);
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final ReviewWindowKind value;
  final ReviewWindowKind selected;
  final ValueChanged<ReviewWindowKind> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected == value,
      onSelected: (_) => onSelected(value),
    );
  }
}

enum _ChatRole { user, assistant }

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  final _ChatRole role;
  final String text;
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _ChatRole.user;
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isUser
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.white.withValues(alpha: 0.52),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isUser
                  ? colorScheme.primary.withValues(alpha: 0.22)
                  : Colors.white.withValues(alpha: 0.58),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(message.text),
          ),
        ),
      ),
    );
  }
}

class _ChatThinkingBubble extends StatefulWidget {
  const _ChatThinkingBubble();

  @override
  State<_ChatThinkingBubble> createState() => _ChatThinkingBubbleState();
}

class _ChatThinkingBubbleState extends State<_ChatThinkingBubble> {
  static const _messages = [
    '正在读取复盘数据',
    '正在调用 LLM 分析',
    '正在整理回答',
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _messages.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.52),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 240),
                child: Text(
                  _messages[_index],
                  key: ValueKey(_index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
