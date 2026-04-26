import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/config_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class DimensionManagePage extends StatefulWidget {
  const DimensionManagePage({super.key});

  @override
  State<DimensionManagePage> createState() => _DimensionManagePageState();
}

class _DimensionManagePageState extends State<DimensionManagePage> {
  final Map<String, ViewState<List<DimensionOptionModel>>> _states = {
    for (final kind in _dimensionKinds.keys) kind: ViewState.initial(),
  };
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadAll());
  }

  Future<void> _loadAll() async {
    for (final kind in _dimensionKinds.keys) {
      await _loadKind(kind);
    }
  }

  Future<void> _loadKind(String kind) async {
    setState(() => _states[kind] = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final response = await LifeOsScope.of(context).invokeRaw(
        method: 'list_dimension_options',
        payload: {
          'user_id': runtime.userId,
          'kind': kind,
          'include_inactive': true,
        },
      );
      final items = ((response as List?) ?? const [])
          .whereType<Map>()
          .map((item) => DimensionOptionModel.fromJson(item.cast<String, dynamic>()))
          .toList();
      if (!mounted) {
        return;
      }
      setState(() => _states[kind] = ViewState.ready(items));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _states[kind] = ViewState.error(error.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '维度管理',
      subtitle: 'Dimension Management',
      actions: [
        OutlinedButton(
          onPressed: _loadAll,
          child: const Text('刷新全部'),
        ),
      ],
      children: [
        for (final entry in _dimensionKinds.entries)
          SectionCard(
            eyebrow: 'Dimension',
            title: entry.value,
            child: _buildKindSection(entry.key),
          ),
      ],
    );
  }

  Widget _buildKindSection(String kind) {
    final state = _states[kind] ?? ViewState.initial();
    return switch (state.status) {
      ViewStatus.loading => const SectionLoadingView(label: '正在读取维度项'),
      ViewStatus.data => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => _openEditor(kind: kind),
                child: const Text('新增维度项'),
              ),
            ),
            const SizedBox(height: 12),
            for (final item in state.data!)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(item.displayName),
                subtitle: Text('${item.code} · ${item.isActive ? '启用' : '停用'}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    if (item.isSystem)
                      const Chip(label: Text('系统')),
                    TextButton(
                      onPressed: () => _openEditor(kind: kind, existing: item),
                      child: const Text('编辑'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      _ => SectionMessageView(
          icon: Icons.tune_rounded,
          title: '维度数据暂不可用',
          description: state.message ?? '请稍后重试。',
        ),
    };
  }

  Future<void> _openEditor({
    required String kind,
    DimensionOptionModel? existing,
  }) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final code = TextEditingController(text: existing?.code ?? '');
    final displayName = TextEditingController(text: existing?.displayName ?? '');
    final active = ValueNotifier<bool>(existing?.isActive ?? true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(existing == null ? '新增维度项' : '编辑维度项'),
          content: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: code,
                  enabled: existing == null,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    helperText: '使用英文小写和下划线，例如 project 或 necessary。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: displayName,
                  decoration: const InputDecoration(labelText: '显示名称'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: active.value,
                  onChanged: (value) {
                    active.value = value;
                    setState(() {});
                  },
                  title: const Text('启用'),
                ),
              ],
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
      if (confirmed != true) {
        return;
      }
      await service.invokeRaw(
        method: 'save_dimension_option',
        payload: {
          'user_id': runtime.userId,
          'kind': kind,
          'input': {
            'code': code.text,
            'display_name': displayName.text,
            'is_active': active.value,
          },
        },
      );
      if (!mounted) {
        return;
      }
      await _loadKind(kind);
    } finally {
      code.dispose();
      displayName.dispose();
      active.dispose();
    }
  }
}

const Map<String, String> _dimensionKinds = {
  'time_category': '时间类别',
  'income_type': '收入类型',
  'expense_category': '支出类别',
  'learning_level': '学习等级',
  'project_status': '项目状态',
};
