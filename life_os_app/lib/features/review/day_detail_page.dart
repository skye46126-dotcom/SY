import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/project_models.dart';
import '../../models/record_models.dart';
import '../../models/tag_models.dart';
import '../../services/export_metadata_builders.dart';
import '../../services/image_export_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/export_document_dialog.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';
import 'widgets/record_editor_dialog.dart';

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({
    super.key,
    required this.anchorDate,
  });

  final String anchorDate;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  final GlobalKey _exportBoundaryKey = GlobalKey();
  final ImageExportService _imageExportService = const ImageExportService();
  ViewState<List<RecentRecordItem>> _state = ViewState.initial();
  bool _loaded = false;
  bool _isExporting = false;

  Future<void> _load() async {
    setState(() {
      _state = ViewState.loading();
    });
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final records = await LifeOsScope.of(context).getRecordsForDate(
        userId: runtime.userId,
        date: widget.anchorDate,
        timezone: runtime.timezone,
      );
      if (!mounted) return;
      setState(() {
        _state = records.isEmpty
            ? ViewState.empty('当天没有记录。')
            : ViewState.ready(records);
      });
    } on UnimplementedError {
      if (!mounted) return;
      setState(() {
        _state = ViewState.unavailable('按日明细接口尚未接入 Rust。');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = ViewState.error(error.toString());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '日详情',
      subtitle: widget.anchorDate,
      exportBoundaryKey: _exportBoundaryKey,
      actions: [
        OutlinedButton(
          onPressed:
              _state.hasData && !_isExporting ? _exportDayDetailDocument : null,
          child: Text(_isExporting ? '正在导出' : '导出图片文档'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pushNamed('/capture'),
          child: const Text('新增时间记录'),
        ),
      ],
      children: [
        if (_state.status == ViewStatus.loading)
          const SectionLoadingView(label: '正在读取当日记录'),
        SectionCard(
          eyebrow: 'Records',
          title: '当日流水',
          child: _state.hasData
              ? Column(
                  children: [
                    for (final record in _state.data!)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(record.title),
                        subtitle: Text(record.detail),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _editRecord(record);
                              case 'delete':
                                _deleteRecord(record);
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
                      ),
                  ],
                )
              : SectionMessageView(
                  icon: Icons.calendar_month_outlined,
                  title: '当日明细暂不可用',
                  description: _state.message ?? '请稍后重试。',
                ),
        ),
      ],
    );
  }

  Future<void> _exportDayDetailDocument() async {
    final records = _state.data;
    if (records == null || _isExporting) {
      return;
    }
    setState(() => _isExporting = true);
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final result = await _imageExportService.exportBoundary(
        boundaryKey: _exportBoundaryKey,
        module: 'day_detail',
        title: 'day-detail-${widget.anchorDate}',
        metadata: buildDayDetailExportMetadata(
          anchorDate: widget.anchorDate,
          timezone: runtime.timezone,
          records: records,
        ),
      );
      if (!mounted) return;
      await showExportDocumentDialog(context, result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出日详情图片文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _deleteRecord(RecentRecordItem record) async {
    final runtime = LifeOsScope.runtimeOf(context);
    await LifeOsScope.of(context).invokeRaw(
      method: 'delete_record',
      payload: {
        'user_id': runtime.userId,
        'record_id': record.recordId,
        'kind': record.kind.name,
      },
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _editRecord(RecentRecordItem record) async {
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
      context: Navigator.of(context, rootNavigator: true).context,
      builder: (context) {
        final typedProjectOptions = projectOptions.cast<ProjectOption>();
        final typedTags = tags.cast<TagModel>();
        switch (record.kind) {
          case RecordKind.time:
            return RecordEditorDialog.time(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: widget.anchorDate,
              timeSnapshot: TimeRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.income:
            return RecordEditorDialog.income(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: widget.anchorDate,
              incomeSnapshot: IncomeRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.expense:
            return RecordEditorDialog.expense(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: widget.anchorDate,
              expenseSnapshot: ExpenseRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.learning:
            return RecordEditorDialog.learning(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: widget.anchorDate,
              learningSnapshot: LearningRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
        }
      },
    );
    if (result == null) return;
    await service.invokeRaw(method: result.method, payload: result.payload);
    if (!mounted) return;
    await _load();
  }
}
