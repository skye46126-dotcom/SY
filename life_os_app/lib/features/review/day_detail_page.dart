import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../features/export/application/export_orchestrator.dart';
import '../../features/export/domain/export_artifact.dart';
import '../../features/export/domain/export_range.dart';
import '../../features/export/domain/export_request.dart';
import '../../models/project_models.dart';
import '../../models/record_models.dart';
import '../../models/tag_models.dart';
import '../../services/export_metadata_builders.dart';
import '../../services/image_export_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/export_document_dialog.dart';
import '../../shared/widgets/glass_panel.dart';
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
  ExportOrchestrator? _exportOrchestrator;
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
    _exportOrchestrator ??=
        ExportOrchestrator(service: LifeOsScope.of(context));
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
    final records = _state.data ?? const <RecentRecordItem>[];
    return ModulePage(
      title: '日详情',
      subtitle: widget.anchorDate,
      exportBoundaryKey: _exportBoundaryKey,
      children: [
        _DayActionRow(
          isExporting: _isExporting,
          canExport: _state.hasData,
          onExport: _exportDayDetailDocument,
          onAddRecord: () => Navigator.of(context).pushNamed('/capture'),
        ),
        if (_state.status == ViewStatus.loading)
          const SectionLoadingView(label: '正在读取当日记录'),
        if (_state.hasData) ...[
          _DaySummaryHero(
            anchorDate: widget.anchorDate,
            records: records,
          ),
          SectionCard(
            eyebrow: 'Records',
            title: '当日流水',
            child: Column(
              children: [
                for (var index = 0; index < records.length; index++) ...[
                  if (index > 0) const SizedBox(height: 12),
                  _DayRecordCard(
                    record: records[index],
                    onEdit: () => _editRecord(records[index]),
                    onDelete: () => _deleteRecord(records[index]),
                  ),
                ],
              ],
            ),
          ),
        ] else if (_state.status != ViewStatus.loading)
          SectionCard(
            eyebrow: 'Records',
            title: '当日流水',
            child: SectionMessageView(
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
      final exportResult = await _exportOrchestrator!.export(
        ExportRequest.snapshot(
          title: 'day-detail-${widget.anchorDate}',
          module: 'day_detail',
          range: ExportRange.today,
          boundaryKey: _exportBoundaryKey,
          metadata: buildDayDetailExportMetadata(
            anchorDate: widget.anchorDate,
            timezone: runtime.timezone,
            records: records,
          ),
        ),
      );
      final artifact = exportResult.primaryArtifact;
      if (!mounted) return;
      await showExportDocumentDialog(
          context, _artifactToImageDocument(artifact));
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

  ExportedImageDocument _artifactToImageDocument(ExportArtifact artifact) {
    return ExportedImageDocument(
      module: artifact.module,
      title: artifact.title,
      exportedAt: artifact.createdAt,
      directoryPath: File(artifact.filePath).parent.path,
      imagePath: artifact.filePath,
      metadataPath: artifact.metadataPath,
      metadata: Map<String, dynamic>.from(artifact.metadata.toJson()),
    );
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

    final typedProjectOptions = projectOptions.cast<ProjectOption>();
    final typedTags = tags.cast<TagModel>();
    final dialog = switch (record.kind) {
      RecordKind.time => RecordEditorDialog.time(
          recordId: record.recordId,
          userId: runtime.userId,
          anchorDate: widget.anchorDate,
          timeSnapshot: TimeRecordSnapshotModel.fromJson(
              snapshot.cast<String, dynamic>()),
          projectOptions: typedProjectOptions,
          tags: typedTags,
        ),
      RecordKind.income => RecordEditorDialog.income(
          recordId: record.recordId,
          userId: runtime.userId,
          anchorDate: widget.anchorDate,
          incomeSnapshot: IncomeRecordSnapshotModel.fromJson(
              snapshot.cast<String, dynamic>()),
          projectOptions: typedProjectOptions,
          tags: typedTags,
        ),
      RecordKind.expense => RecordEditorDialog.expense(
          recordId: record.recordId,
          userId: runtime.userId,
          anchorDate: widget.anchorDate,
          expenseSnapshot: ExpenseRecordSnapshotModel.fromJson(
              snapshot.cast<String, dynamic>()),
          projectOptions: typedProjectOptions,
          tags: typedTags,
        ),
    };
    final result = await RecordEditorDialog.show(context, dialog: dialog);
    if (result == null) return;
    await service.invokeRaw(method: result.method, payload: result.payload);
    if (!mounted) return;
    await _load();
  }
}

class _DayActionRow extends StatelessWidget {
  const _DayActionRow({
    required this.isExporting,
    required this.canExport,
    required this.onExport,
    required this.onAddRecord,
  });

  final bool isExporting;
  final bool canExport;
  final VoidCallback onExport;
  final VoidCallback onAddRecord;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        OutlinedButton(
          onPressed: canExport && !isExporting ? onExport : null,
          child: Text(isExporting ? '正在导出' : '导出图片文档'),
        ),
        ElevatedButton(
          onPressed: onAddRecord,
          child: const Text('新增时间记录'),
        ),
      ],
    );
  }
}

class _DaySummaryHero extends StatelessWidget {
  const _DaySummaryHero({
    required this.anchorDate,
    required this.records,
  });

  final String anchorDate;
  final List<RecentRecordItem> records;

  @override
  Widget build(BuildContext context) {
    int countFor(RecordKind kind) =>
        records.where((item) => item.kind == kind).length;
    final latest =
        records.isEmpty ? '' : _formatOccurredAt(records.first.occurredAt);
    final earliest =
        records.isEmpty ? '' : _formatOccurredAt(records.last.occurredAt);
    final timeSpan = latest.isEmpty && earliest.isEmpty
        ? ''
        : latest == earliest
            ? latest
            : '$earliest - $latest';

    return GlassPanel(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Records',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 10),
          Text(
            '当日流水',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 30,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '共 ${records.length} 条记录${timeSpan.isEmpty ? '' : ' · 时间窗口 $timeSpan'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _SummaryPill(
                label: '日期 $anchorDate',
                color: const Color(0xFF475569),
              ),
              _SummaryPill(
                label: '时间 ${countFor(RecordKind.time)}',
                color: _kindColor(RecordKind.time),
              ),
              _SummaryPill(
                label: '收入 ${countFor(RecordKind.income)}',
                color: _kindColor(RecordKind.income),
              ),
              _SummaryPill(
                label: '支出 ${countFor(RecordKind.expense)}',
                color: _kindColor(RecordKind.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayRecordCard extends StatelessWidget {
  const _DayRecordCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
  });

  final RecentRecordItem record;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final kindColor = _kindColor(record.kind);
    final detail = record.detail.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SummaryPill(
                      label: _kindLabel(record.kind),
                      color: kindColor,
                    ),
                    _SummaryPill(
                      label: _formatOccurredAt(record.occurredAt),
                      color: const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      onEdit();
                    case 'delete':
                      onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _displayTitle(record),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 22,
                ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ] else ...[
            const SizedBox(height: 8),
            Text(
              _kindEmptyDetail(record.kind),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ),
    );
  }
}

String _displayTitle(RecentRecordItem record) {
  final title = record.title.trim();
  if (title.isEmpty) {
    return '${_kindLabel(record.kind)}记录';
  }
  return title;
}

String _kindLabel(RecordKind kind) {
  return switch (kind) {
    RecordKind.time => '时间',
    RecordKind.income => '收入',
    RecordKind.expense => '支出',
  };
}

String _kindEmptyDetail(RecordKind kind) {
  return switch (kind) {
    RecordKind.time => '没有补充备注',
    RecordKind.income => '没有补充来源说明',
    RecordKind.expense => '没有补充支出说明',
  };
}

Color _kindColor(RecordKind kind) {
  return switch (kind) {
    RecordKind.time => const Color(0xFF2563EB),
    RecordKind.income => const Color(0xFF059669),
    RecordKind.expense => const Color(0xFFDC2626),
  };
}

String _formatOccurredAt(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '未标注时间';
  }
  if (!trimmed.contains('T') &&
      trimmed.length == 10 &&
      trimmed[4] == '-' &&
      trimmed[7] == '-') {
    return trimmed.substring(5);
  }
  final parsed = DateTime.tryParse(trimmed);
  if (parsed != null) {
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
  if (trimmed.length >= 16 && trimmed.contains('T')) {
    final segments = trimmed.split('T');
    if (segments.length == 2 && segments[1].length >= 5) {
      return segments[1].substring(0, 5);
    }
  }
  return trimmed;
}
