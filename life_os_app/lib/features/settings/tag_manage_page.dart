import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/tag_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class TagManagePage extends StatefulWidget {
  const TagManagePage({super.key});

  @override
  State<TagManagePage> createState() => _TagManagePageState();
}

class _TagManagePageState extends State<TagManagePage> {
  ViewState<List<TagModel>> _state = ViewState.initial();
  bool _loaded = false;

  Future<void> _load() async {
    setState(() => _state = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final tags = await LifeOsScope.of(context).getTags(userId: runtime.userId);
      setState(() {
        _state = tags.isEmpty ? ViewState.empty('当前还没有标签。') : ViewState.ready(tags);
      });
    } catch (error) {
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
      title: '标签管理',
      subtitle: 'Tags',
      actions: [
        ElevatedButton(
          onPressed: () => _openTagDialog(),
          child: const Text('新建标签'),
        ),
        OutlinedButton(
          onPressed: _load,
          child: const Text('刷新'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Tags',
          title: '标签树与作用域',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在读取标签'),
            ViewStatus.data => Column(
                children: [
                  for (final tag in _state.data!)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Text(tag.emoji ?? '•'),
                      title: Text(tag.name),
                      subtitle: Text(
                        'scope: ${tag.scope ?? '-'} · group: ${tag.tagGroup ?? '-'} · level: ${tag.level ?? '-'}',
                      ),
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          Text(tag.status ?? ''),
                          IconButton(
                            onPressed: () => _openTagDialog(tag: tag),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            onPressed: () => _deleteTag(tag),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            _ => SectionMessageView(
                icon: Icons.sell_outlined,
                title: '标签数据暂不可用',
                description: _state.message ?? '请稍后重试。',
              ),
          },
        ),
      ],
    );
  }

  Future<void> _openTagDialog({TagModel? tag}) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final name = TextEditingController(text: tag?.name ?? '');
    final emoji = TextEditingController(text: tag?.emoji ?? '');
    final scope = TextEditingController(text: tag?.scope ?? 'global');
    final group = TextEditingController(text: tag?.tagGroup ?? 'custom');
    final level = TextEditingController(text: '${tag?.level ?? 1}');
    final status = TextEditingController(text: tag?.status ?? 'active');
    final sortOrder = TextEditingController(text: '${tag?.sortOrder ?? 0}');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text(tag == null ? '新建标签' : '编辑标签'),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  TextField(controller: name, decoration: const InputDecoration(labelText: '名称')),
                  TextField(controller: emoji, decoration: const InputDecoration(labelText: 'Emoji')),
                  TextField(controller: scope, decoration: const InputDecoration(labelText: 'Scope')),
                  TextField(controller: group, decoration: const InputDecoration(labelText: 'Group')),
                  TextField(controller: level, decoration: const InputDecoration(labelText: 'Level')),
                  TextField(controller: status, decoration: const InputDecoration(labelText: 'Status')),
                  TextField(controller: sortOrder, decoration: const InputDecoration(labelText: 'Sort Order')),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
              ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
            ],
          );
        },
      );
      if (confirmed != true) return;
      final payload = {
        'user_id': runtime.userId,
        'name': name.text,
        'emoji': emoji.text.isEmpty ? null : emoji.text,
        'tag_group': group.text,
        'scope': scope.text,
        'parent_tag_id': null,
        'level': int.tryParse(level.text) ?? 1,
        'status': status.text,
        'sort_order': int.tryParse(sortOrder.text) ?? 0,
      };
      if (tag == null) {
        await service.invokeRaw(method: 'create_tag', payload: payload);
      } else {
        await service.invokeRaw(
          method: 'update_tag',
          payload: {
            'tag_id': tag.id,
            'input': payload,
          },
        );
      }
      if (!mounted) return;
      await _load();
    } finally {
      name.dispose();
      emoji.dispose();
      scope.dispose();
      group.dispose();
      level.dispose();
      status.dispose();
      sortOrder.dispose();
    }
  }

  Future<void> _deleteTag(TagModel tag) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确认删除 ${tag.name} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed != true) return;
    await service.invokeRaw(
      method: 'delete_tag',
      payload: {
        'user_id': runtime.userId,
        'tag_id': tag.id,
      },
    );
    if (!mounted) return;
    await _load();
  }
}
