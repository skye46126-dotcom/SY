import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../features/export/application/export_orchestrator.dart';
import '../../features/export/domain/export_format.dart';
import '../../features/export/domain/export_request.dart';
import '../../services/export_share_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class DataPackageExportPage extends StatefulWidget {
  const DataPackageExportPage({super.key});

  @override
  State<DataPackageExportPage> createState() => _DataPackageExportPageState();
}

class _DataPackageExportPageState extends State<DataPackageExportPage> {
  ExportOrchestrator? _orchestrator;
  bool _loadedPreview = false;
  ExportFormat _format = ExportFormat.json;
  ViewState<String> _state = ViewState.initial();
  ViewState<Map<String, int>> _previewState = ViewState.initial();
  String? _primaryExportPath;
  String? _primaryExportTitle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _orchestrator ??= ExportOrchestrator(service: LifeOsScope.of(context));
    if (_loadedPreview) return;
    _loadedPreview = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadPreview();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModulePage(
      title: '数据包导出',
      subtitle: 'Data Package Export',
      actions: [
        ElevatedButton(
          onPressed: _state.status == ViewStatus.loading ? null : _export,
          child: Text(_state.status == ViewStatus.loading ? '正在导出' : '导出'),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Format',
          title: '导出格式',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final format in const [
                ExportFormat.json,
                ExportFormat.csv,
                ExportFormat.zip,
              ])
                ChoiceChip(
                  label: Text(_label(format)),
                  selected: _format == format,
                  onSelected: (_) => setState(() => _format = format),
                ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Scope',
          title: '当前数据集',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('当前用户：${LifeOsScope.runtimeOf(context).userId}'),
              const SizedBox(height: 12),
              const Text('会导出当前用户下的全部数据；设置页导入的 mock 数据如果写入当前用户，也会包含在这里。'),
              const SizedBox(height: 12),
              switch (_previewState.status) {
                ViewStatus.loading => const SectionLoadingView(
                    label: '正在检查可导出数据',
                  ),
                ViewStatus.data => _TableCountPreview(
                    counts: _previewState.data ?? const {},
                  ),
                ViewStatus.error => SectionMessageView(
                    icon: Icons.error_outline_rounded,
                    title: '数据预览失败',
                    description: _previewState.message ?? '请稍后重试。',
                  ),
                _ => const SectionMessageView(
                    icon: Icons.inventory_2_outlined,
                    title: '等待检查数据',
                    description: '进入页面后会读取当前用户可导出的表行数。',
                  ),
              },
              const SizedBox(height: 12),
              const Text('JSON: 单文件'),
              const Text('CSV: 多表 CSV'),
              const Text('ZIP: JSON + CSV + manifest'),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Result',
          title: '导出结果',
          child: switch (_state.status) {
            ViewStatus.loading => const SectionLoadingView(label: '正在生成数据包'),
            ViewStatus.data => _ExportResultActions(
                paths: _state.data ?? '',
                primaryPath: _primaryExportPath,
                title: _primaryExportTitle ?? 'SkyOS 数据包',
                mimeType: _mimeType(_format),
              ),
            ViewStatus.error => SectionMessageView(
                icon: Icons.error_outline_rounded,
                title: '导出失败',
                description: _state.message ?? '请稍后重试。',
              ),
            _ => const SectionMessageView(
                icon: Icons.inventory_2_outlined,
                title: '等待导出',
                description: '选择格式后执行导出。',
              ),
          },
        ),
      ],
    );
  }

  Future<void> _loadPreview() async {
    final runtime = LifeOsScope.runtimeOf(context);
    setState(() => _previewState = ViewState.loading());
    try {
      final counts =
          await _orchestrator!.previewDataPackage(userId: runtime.userId);
      if (!mounted) return;
      setState(() => _previewState = ViewState.ready(counts));
    } catch (error) {
      if (!mounted) return;
      setState(() => _previewState = ViewState.error(error.toString()));
    }
  }

  Future<void> _export() async {
    final runtime = LifeOsScope.runtimeOf(context);
    setState(() => _state = ViewState.loading());
    try {
      final result = await _orchestrator!.export(
        ExportRequest.dataPackage(
          title: 'data-package-${runtime.todayDate}',
          format: _format,
          userId: runtime.userId,
        ),
      );
      if (!mounted) return;
      final paths = result.artifacts.map((item) => item.filePath).join('\n');
      setState(() {
        _primaryExportPath = result.primaryArtifact.filePath;
        _primaryExportTitle = result.primaryArtifact.title;
        _state = ViewState.ready(paths);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = ViewState.error(error.toString()));
    }
  }

  String _label(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.zip:
        return 'ZIP';
      default:
        return format.key;
    }
  }

  String _mimeType(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
        return 'application/json';
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.zip:
        return 'application/zip';
      default:
        return 'application/octet-stream';
    }
  }
}

class _ExportResultActions extends StatelessWidget {
  const _ExportResultActions({
    required this.paths,
    required this.primaryPath,
    required this.title,
    required this.mimeType,
  });

  final String paths;
  final String? primaryPath;
  final String title;
  final String mimeType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(paths),
        if (primaryPath != null) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: primaryPath!));
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
                      filePath: primaryPath!,
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
      ],
    );
  }
}

class _TableCountPreview extends StatelessWidget {
  const _TableCountPreview({
    required this.counts,
  });

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final entries = counts.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final total = entries.fold<int>(0, (sum, item) => sum + item.value);
    if (entries.isEmpty || total == 0) {
      return const SectionMessageView(
        icon: Icons.data_array_rounded,
        title: '当前用户暂无表数据',
        description: '请确认 mock 数据已经导入当前用户，或先在设置页生成/导入数据。',
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _DataCountChip(label: '总行数', count: total),
        for (final item in entries)
          if (item.value > 0)
            _DataCountChip(label: item.key, count: item.value),
      ],
    );
  }
}

class _DataCountChip extends StatelessWidget {
  const _DataCountChip({
    required this.label,
    required this.count,
  });

  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text('$label · $count'),
      visualDensity: VisualDensity.compact,
    );
  }
}
