import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../features/export/application/export_orchestrator.dart';
import '../../features/export/domain/export_format.dart';
import '../../features/export/domain/export_range.dart';
import '../../features/export/domain/export_request.dart';
import '../../services/export_share_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class ReportExportPage extends StatefulWidget {
  const ReportExportPage({super.key});

  @override
  State<ReportExportPage> createState() => _ReportExportPageState();
}

class _ReportExportPageState extends State<ReportExportPage> {
  ExportOrchestrator? _orchestrator;
  ExportRange _range = ExportRange.today;
  ExportFormat _format = ExportFormat.markdown;
  DateTime _customStartDate = DateTime.now();
  DateTime _customEndDate = DateTime.now();
  ViewState<String> _state = ViewState.initial();
  String? _exportTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _orchestrator ??= ExportOrchestrator(service: LifeOsScope.of(context));
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '报告导出',
      subtitle: 'Readable Report Export',
      actions: [
        ElevatedButton(
          onPressed: _state.status == ViewStatus.loading ? null : _export,
          child: Text(_state.status == ViewStatus.loading ? '正在导出' : '导出'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Range',
          title: '时间范围',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final range in const [
                ExportRange.today,
                ExportRange.week,
                ExportRange.month,
                ExportRange.year,
                ExportRange.custom,
                ExportRange.all,
              ])
                ChoiceChip(
                  label: Text(_rangeLabel(range)),
                  selected: _range == range,
                  onSelected: (_) => setState(() => _range = range),
                ),
            ],
          ),
        ),
        if (_range == ExportRange.custom)
          SectionCard(
            eyebrow: 'Custom',
            title: '自定义区间',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: () => _pickCustomDate(isStart: true),
                  child: Text('开始：${_iso(_customStartDate)}'),
                ),
                OutlinedButton(
                  onPressed: () => _pickCustomDate(isStart: false),
                  child: Text('结束：${_iso(_customEndDate)}'),
                ),
              ],
            ),
          ),
        SectionCard(
          eyebrow: 'Format',
          title: '报告格式',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final format in const [
                ExportFormat.markdown,
                ExportFormat.txt,
                ExportFormat.pdf,
              ])
                ChoiceChip(
                  label: Text(_formatLabel(format)),
                  selected: _format == format,
                  onSelected: (_) => setState(() => _format = format),
                ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Content',
          title: '报告内容',
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('概览、摘要、核心经营指标、项目表现、标签信息。'),
              SizedBox(height: 12),
              Text(
                  '今日报告会合并 TodaySummary / ReviewReport；周、月、年、自定义和全部范围基于 ReviewReport 生成。'),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Result',
          title: '导出结果',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在生成报告'),
            ViewStatus.data => _ReportResultActions(
                path: _state.data ?? '',
                title: _exportTitle ?? 'SkyOS 报告',
                mimeType: _mimeType(_format),
              ),
            ViewStatus.error => SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '导出失败',
                description: _state.message ?? '请稍后重试。',
              ),
            _ => const SectionMessageView(
                icon: Icons.article_outlined,
                title: '等待导出',
                description: '选择范围和格式后执行导出。',
              ),
          },
        ),
      ],
    );
  }

  Future<void> _export() async {
    final runtime = LifeOsScope.runtimeOf(context);
    setState(() => _state = ViewState.loading());
    try {
      final result = await _orchestrator!.export(
        ExportRequest.report(
          title: 'report-${_range.key}-${runtime.todayDate}',
          format: _format,
          range: _range,
          userId: runtime.userId,
          anchorDate: runtime.todayDate,
          timezone: runtime.timezone,
          customStartDate:
              _range == ExportRange.custom ? _iso(_customStartDate) : null,
          customEndDate:
              _range == ExportRange.custom ? _iso(_customEndDate) : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _exportTitle = result.primaryArtifact.title;
        _state = ViewState.ready(result.primaryArtifact.filePath);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = ViewState.error(error.toString()));
    }
  }

  String _rangeLabel(ExportRange range) {
    switch (range) {
      case ExportRange.today:
        return '今日';
      case ExportRange.week:
        return '本周';
      case ExportRange.month:
        return '本月';
      case ExportRange.year:
        return '本年';
      case ExportRange.custom:
        return '自定义';
      case ExportRange.all:
        return '全部';
    }
  }

  Future<void> _pickCustomDate({required bool isStart}) async {
    final current = isStart ? _customStartDate : _customEndDate;
    final selected = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(1970, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isStart) {
        _customStartDate = selected;
        if (_customEndDate.isBefore(_customStartDate)) {
          _customEndDate = _customStartDate;
        }
      } else {
        _customEndDate = selected;
        if (_customStartDate.isAfter(_customEndDate)) {
          _customStartDate = _customEndDate;
        }
      }
    });
  }

  String _iso(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatLabel(ExportFormat format) {
    switch (format) {
      case ExportFormat.markdown:
        return 'Markdown';
      case ExportFormat.txt:
        return 'TXT';
      case ExportFormat.pdf:
        return 'PDF';
      default:
        return format.key;
    }
  }

  String _mimeType(ExportFormat format) {
    switch (format) {
      case ExportFormat.markdown:
        return 'text/markdown';
      case ExportFormat.txt:
        return 'text/plain';
      case ExportFormat.pdf:
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }
}

class _ReportResultActions extends StatelessWidget {
  const _ReportResultActions({
    required this.path,
    required this.title,
    required this.mimeType,
  });

  final String path;
  final String title;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(path),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: path));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已复制文件路径')),
                );
              },
              child: const Text('复制路径'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await ExportShareService(service: LifeOsScope.of(context))
                      .shareFile(
                    filePath: path,
                    title: title,
                    mimeType: mimeType,
                    text: 'SkyOS export: $title',
                  );
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('打开分享面板失败：$error')),
                  );
                }
              },
              child: const Text('分享'),
            ),
          ],
        ),
      ],
    );
  }
}
