import 'package:flutter/material.dart';

import '../../../shared/view_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class AiCaptureSection extends StatelessWidget {
  const AiCaptureSection({
    super.key,
    required this.aiState,
    required this.inputController,
    required this.onParsePressed,
    required this.onCommitPressed,
  });

  final ViewState<Map<String, Object?>> aiState;
  final TextEditingController inputController;
  final VoidCallback onParsePressed;
  final VoidCallback onCommitPressed;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'AI Capture',
      title: '自然语言录入',
      trailing: ElevatedButton(
        onPressed: onParsePressed,
        child: const Text('解析草稿'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: inputController,
            minLines: 6,
            maxLines: 8,
            decoration: InputDecoration(
              labelText: '输入自然语言',
              hintText: '这里直接输入原始描述，解析结果必须经过确认后才能入库。',
            ),
          ),
          const SizedBox(height: 16),
          switch (aiState.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在请求 AI 解析'),
            ViewStatus.data => _DraftPreview(
                draft: aiState.data!,
                onCommitPressed: onCommitPressed,
              ),
            ViewStatus.empty => SectionMessageView(
                icon: Icons.drafts_rounded,
                title: '没有生成草稿',
                description: aiState.message ?? 'AI 返回为空。',
              ),
            ViewStatus.unavailable => SectionMessageView(
                icon: Icons.link_off_rounded,
                title: 'AI 接口未接入',
                description: aiState.message ?? '等待 Rust AI service 接入。',
              ),
            ViewStatus.error => SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '解析失败',
                description: aiState.message ?? '请稍后重试。',
              ),
            _ => const SectionMessageView(
                icon: Icons.auto_awesome_rounded,
                title: '先输入，再确认',
                description: '这里保留 AI 草稿确认流，不填任何示例草稿。',
              ),
          },
        ],
      ),
    );
  }
}

class _DraftPreview extends StatelessWidget {
  const _DraftPreview({
    required this.draft,
    required this.onCommitPressed,
  });

  final Map<String, Object?> draft;
  final VoidCallback onCommitPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('AI 草稿', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final entry in draft.entries) ...[
            Text('${entry.key}: ${entry.value ?? ''}'),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: null,
                child: const Text('修改'),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: onCommitPressed,
                child: const Text('确认入库'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
