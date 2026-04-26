import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/project_models.dart';
import '../../models/record_models.dart';
import '../../models/snapshot_models.dart';
import '../../models/tag_models.dart';
import '../../services/app_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';
import '../review/widgets/record_editor_dialog.dart';

class ProjectDetailController extends ChangeNotifier {
  ProjectDetailController(this._service);

  final AppService _service;
  ViewState<ProjectDetail> state = ViewState.initial();

  Future<void> load({
    required String userId,
    required String projectId,
    required String timezone,
  }) async {
    state = ViewState.loading();
    notifyListeners();
    try {
      final detail = await _service.getProjectDetail(
        userId: userId,
        projectId: projectId,
        timezone: timezone,
      );
      if (detail == null) {
        state = ViewState.empty('项目不存在或没有返回详情。');
      } else {
        state = ViewState.ready(detail);
      }
    } on UnimplementedError {
      state = ViewState.unavailable('项目详情接口尚未接入 Rust。');
    } catch (error) {
      state = ViewState.error(error.toString());
    }
    notifyListeners();
  }
}

class ProjectDetailPage extends StatefulWidget {
  const ProjectDetailPage({
    super.key,
    required this.projectId,
  });

  final String projectId;

  @override
  State<ProjectDetailPage> createState() => _ProjectDetailPageState();
}

class _ProjectDetailPageState extends State<ProjectDetailPage> {
  ProjectDetailController? _controller;
  ViewState<ProjectMetricSnapshotSummaryModel?> _snapshotState = ViewState.initial();
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ProjectDetailController(LifeOsScope.of(context));
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller!.load(
        userId: LifeOsScope.runtimeOf(context).userId,
        projectId: widget.projectId,
        timezone: LifeOsScope.runtimeOf(context).timezone,
      );
      _loadSnapshot();
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

    final detail = controller.state.data;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ModulePage(
          title: '项目详情',
          subtitle: 'Project Detail',
          actions: [
            ElevatedButton(
              onPressed: () => _openProjectEditDialog(detail),
              child: const Text('完整编辑'),
            ),
            ElevatedButton(
              onPressed: () => _openProjectStateDialog(detail),
              child: const Text('更新状态'),
            ),
            OutlinedButton(
              onPressed: () => _deleteProject(),
              child: const Text('删除项目'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('返回'),
            ),
          ],
          children: [
            if (controller.state.status == ViewStatus.loading)
              const SectionLoadingView(label: '正在读取项目详情'),
            SectionCard(
              eyebrow: 'Decision',
              title: '项目判断卡',
              child: detail == null
                  ? SectionMessageView(
                      icon: Icons.insights_rounded,
                      title: '等待项目经营分析',
                      description: controller.state.message ??
                          '这里保留“值不值得继续做”的判断卡，不填任何样例结论。',
                    )
                  : Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        Text('项目: ${detail.name}'),
                        Text('状态: ${detail.statusCode}'),
                        Text('评估: ${detail.evaluationStatus}'),
                        Text('ROI: ${detail.roiPerc.toStringAsFixed(2)}%'),
                        Text('经营 ROI: ${detail.operatingRoiPerc.toStringAsFixed(2)}%'),
                      ],
                    ),
            ),
            SectionCard(
              eyebrow: 'Metrics',
              title: '项目经营指标',
              child: detail == null
                  ? const SectionMessageView(
                      icon: Icons.calculate_rounded,
                      title: '指标区域已建立',
                      description: '等待 ProjectDetail 返回收入、成本、利润和 break-even 指标。',
                    )
                  : Wrap(
                      spacing: 18,
                      runSpacing: 12,
                      children: [
                        Text('收入: ¥${(detail.totalIncomeCents / 100).toStringAsFixed(2)}'),
                        Text('支出: ¥${(detail.totalExpenseCents / 100).toStringAsFixed(2)}'),
                        Text('总成本: ¥${(detail.totalCostCents / 100).toStringAsFixed(2)}'),
                        Text('利润: ¥${(detail.profitCents / 100).toStringAsFixed(2)}'),
                        Text('时长: ${detail.totalTimeMinutes} 分钟'),
                        Text('学习: ${detail.totalLearningMinutes} 分钟'),
                      ],
                    ),
            ),
            SectionCard(
              eyebrow: 'Snapshot',
              title: '最近月度项目快照',
              child: switch (_snapshotState.status) {
                ViewStatus.loading => const SectionLoadingView(label: '正在读取项目快照'),
                ViewStatus.data when _snapshotState.data != null => Wrap(
                    spacing: 18,
                    runSpacing: 12,
                    children: [
                      Text('快照收入: ¥${(_snapshotState.data!.incomeCents / 100).toStringAsFixed(2)}'),
                      Text('快照总成本: ¥${(_snapshotState.data!.totalCostCents / 100).toStringAsFixed(2)}'),
                      Text('快照利润: ¥${(_snapshotState.data!.profitCents / 100).toStringAsFixed(2)}'),
                      Text('快照投入: ${_snapshotState.data!.investedMinutes} 分钟'),
                      Text('快照 ROI: ${(_snapshotState.data!.roiRatio * 100).toStringAsFixed(2)}%'),
                    ],
                  ),
                _ => SectionMessageView(
                    icon: Icons.analytics_outlined,
                    title: '项目快照暂不可用',
                    description: _snapshotState.message ?? '请稍后重试。',
                  ),
              },
            ),
            SectionCard(
              eyebrow: 'Recent Records',
              title: '项目最近记录',
              child: detail == null || detail.recentRecords.isEmpty
                  ? const SectionMessageView(
                      icon: Icons.receipt_outlined,
                      title: '没有项目记录',
                      description: '项目详情页已为最近记录区域预留结构。',
                    )
                  : Column(
                      children: [
                        for (final record in detail.recentRecords)
                          ListTile(
                            title: Text(record.title),
                            subtitle: Text(record.detail),
                            trailing: PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    _editRecentRecord(record);
                                  case 'delete':
                                    _deleteRecentRecord(record);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(value: 'delete', child: Text('删除')),
                              ],
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(record.occurredAt),
                              ),
                            ),
                            contentPadding: EdgeInsets.zero,
                          ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSnapshot() async {
    setState(() => _snapshotState = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final service = LifeOsScope.of(context);
      final latest = await service.getLatestSnapshot(
        userId: runtime.userId,
        windowType: 'month',
      );
      if (latest == null) {
        setState(() => _snapshotState = ViewState.empty('暂无项目快照。'));
        return;
      }
      final projectSnapshots = await service.listProjectSnapshots(
        userId: runtime.userId,
        metricSnapshotId: latest.id,
      );
      final item = projectSnapshots.where((entry) => entry.projectId == widget.projectId).cast<ProjectMetricSnapshotSummaryModel?>().firstWhere(
            (entry) => entry != null,
            orElse: () => null,
          );
      setState(() {
        _snapshotState = item == null
            ? ViewState.empty('当前项目在最近快照中没有数据。')
            : ViewState.ready(item);
      });
    } catch (error) {
      setState(() => _snapshotState = ViewState.error(error.toString()));
    }
  }

  Future<void> _openProjectStateDialog(ProjectDetail? detail) async {
    if (detail == null) return;
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final status = TextEditingController(text: detail.statusCode);
    final score = TextEditingController(text: '${detail.score ?? ''}');
    final note = TextEditingController(text: detail.note ?? '');
    final endedOn = TextEditingController(text: detail.endedOn ?? '');
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('更新项目状态'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: status, decoration: const InputDecoration(labelText: '状态')),
              TextField(controller: score, decoration: const InputDecoration(labelText: '评分')),
              TextField(controller: endedOn, decoration: const InputDecoration(labelText: '结束日期')),
              TextField(controller: note, decoration: const InputDecoration(labelText: '备注')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('保存')),
          ],
        ),
      );
      if (confirmed != true) return;
      await service.invokeRaw(
        method: 'update_project_state',
        payload: {
          'project_id': detail.id,
          'user_id': runtime.userId,
          'status_code': status.text,
          'score': int.tryParse(score.text),
          'note': note.text.isEmpty ? null : note.text,
          'ended_on': endedOn.text.isEmpty ? null : endedOn.text,
        },
      );
      if (!mounted) return;
      _controller!.load(
        userId: runtime.userId,
        projectId: widget.projectId,
        timezone: runtime.timezone,
      );
    } finally {
      status.dispose();
      score.dispose();
      note.dispose();
      endedOn.dispose();
    }
  }

  Future<void> _openProjectEditDialog(ProjectDetail? detail) async {
    if (detail == null) return;
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final tags = await service.getTags(userId: runtime.userId);
    if (!mounted) return;
    final name = TextEditingController(text: detail.name);
    final statusCode = TextEditingController(text: detail.statusCode);
    final startedOn = TextEditingController(text: detail.startedOn);
    final endedOn = TextEditingController(text: detail.endedOn ?? '');
    final score = TextEditingController(text: detail.score?.toString() ?? '');
    final aiEnableRatio = TextEditingController();
    final note = TextEditingController(text: detail.note ?? '');
    final selectedTagIds = detail.tagIds.toSet();
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('完整编辑项目'),
              content: SizedBox(
                width: 720,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: name, decoration: const InputDecoration(labelText: '项目名称')),
                      TextField(controller: statusCode, decoration: const InputDecoration(labelText: '状态')),
                      TextField(controller: startedOn, decoration: const InputDecoration(labelText: '开始日期')),
                      TextField(controller: endedOn, decoration: const InputDecoration(labelText: '结束日期')),
                      TextField(controller: score, decoration: const InputDecoration(labelText: '评分')),
                      TextField(controller: aiEnableRatio, decoration: const InputDecoration(labelText: 'AI 启用比例')),
                      TextField(controller: note, decoration: const InputDecoration(labelText: '备注'), maxLines: 3),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final tag in tags)
                            FilterChip(
                              label: Text('${tag.emoji ?? ''} ${tag.name}'),
                              selected: selectedTagIds.contains(tag.id),
                              onSelected: (_) {
                                setState(() {
                                  if (selectedTagIds.contains(tag.id)) {
                                    selectedTagIds.remove(tag.id);
                                  } else {
                                    selectedTagIds.add(tag.id);
                                  }
                                });
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
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
        method: 'update_project_record',
        payload: {
          'project_id': detail.id,
          'input': {
            'user_id': runtime.userId,
            'name': name.text,
            'status_code': statusCode.text,
            'started_on': startedOn.text,
            'ended_on': endedOn.text.isEmpty ? null : endedOn.text,
            'ai_enable_ratio': int.tryParse(aiEnableRatio.text),
            'score': int.tryParse(score.text),
            'note': note.text.isEmpty ? null : note.text,
            'tag_ids': selectedTagIds.toList(),
          },
        },
      );
      if (!mounted) return;
      _controller!.load(
        userId: runtime.userId,
        projectId: widget.projectId,
        timezone: runtime.timezone,
      );
    } finally {
      name.dispose();
      statusCode.dispose();
      startedOn.dispose();
      endedOn.dispose();
      score.dispose();
      aiEnableRatio.dispose();
      note.dispose();
    }
  }

  Future<void> _deleteProject() async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'delete_project',
      payload: {
        'user_id': runtime.userId,
        'project_id': widget.projectId,
      },
    );
    if (!mounted) return;
    Navigator.of(context).maybePop();
  }

  Future<void> _deleteRecentRecord(RecentRecordItem record) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    await service.invokeRaw(
      method: 'delete_record',
      payload: {
        'user_id': runtime.userId,
        'record_id': record.recordId,
        'kind': record.kind.name,
      },
    );
    if (!mounted) return;
    _controller!.load(
      userId: runtime.userId,
      projectId: widget.projectId,
      timezone: runtime.timezone,
    );
  }

  Future<void> _editRecentRecord(RecentRecordItem record) async {
    final runtime = LifeOsScope.runtimeOf(context);
    final service = LifeOsScope.of(context);
    final method = switch (record.kind) {
      RecordKind.time => 'get_time_record_snapshot',
      RecordKind.income => 'get_income_record_snapshot',
      RecordKind.expense => 'get_expense_record_snapshot',
      RecordKind.learning => 'get_learning_record_snapshot',
    };
    final snapshot = await service.invokeRaw(
      method: method,
      payload: {
        'user_id': runtime.userId,
        'record_id': record.recordId,
      },
    );
    if (snapshot == null || !mounted) return;
    final projectOptions = await service.getProjectOptions(
      userId: runtime.userId,
      includeDone: true,
    );
    final tags = await service.getTags(userId: runtime.userId);
    if (!mounted) return;
    final result = await showDialog<RecordEditorResult>(
      context: context,
      builder: (context) {
        final typedProjectOptions = projectOptions.cast<ProjectOption>();
        final typedTags = tags.cast<TagModel>();
        switch (record.kind) {
          case RecordKind.time:
            return RecordEditorDialog.time(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: detailAnchorDate(),
              timeSnapshot: TimeRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.income:
            return RecordEditorDialog.income(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: detailAnchorDate(),
              incomeSnapshot: IncomeRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.expense:
            return RecordEditorDialog.expense(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: detailAnchorDate(),
              expenseSnapshot: ExpenseRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.learning:
            return RecordEditorDialog.learning(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: detailAnchorDate(),
              learningSnapshot: LearningRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
        }
      },
    );
    if (result == null) return;
    await service.invokeRaw(method: result.method, payload: result.payload);
    if (!mounted) return;
    _controller!.load(
      userId: runtime.userId,
      projectId: widget.projectId,
      timezone: runtime.timezone,
    );
  }

  String detailAnchorDate() {
    final value = _controller?.state.data?.analysisStartDate;
    if (value != null && value.isNotEmpty) return value;
    return DateTime.now().toIso8601String().split('T').first;
  }
}
