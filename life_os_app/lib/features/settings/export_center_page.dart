import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app.dart';
import '../../features/export/application/export_orchestrator.dart';
import '../../features/export/domain/export_format.dart';
import '../../features/export/domain/export_history_item.dart';
import '../../features/export/domain/export_request.dart';
import '../../features/export/domain/export_type.dart';
import '../../features/export/infrastructure/export_archive_service.dart';
import '../../models/sync_models.dart';
import '../../services/export_share_service.dart';
import '../../services/image_export_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/export_document_dialog.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';

class ExportCenterData {
  const ExportCenterData({
    required this.exportDirectoryPath,
    required this.latestBackup,
    required this.exportHistory,
  });

  final String exportDirectoryPath;
  final BackupResultModel? latestBackup;
  final List<ExportHistoryItem> exportHistory;
}

class ExportCenterPage extends StatefulWidget {
  const ExportCenterPage({super.key});

  @override
  State<ExportCenterPage> createState() => _ExportCenterPageState();
}

class _ExportCenterPageState extends State<ExportCenterPage> {
  final ExportArchiveService _archiveService = const ExportArchiveService();
  ExportOrchestrator? _exportOrchestrator;
  ViewState<ExportCenterData> _state = ViewState.initial();
  ViewState<BackupResultModel> _backupActionState = ViewState.initial();
  String _historyQuery = '';
  ExportType? _historyTypeFilter;
  ExportFormat? _historyFormatFilter;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _exportOrchestrator ??=
        ExportOrchestrator(service: LifeOsScope.of(context));
    if (_loaded) return;
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _load();
    });
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final service = LifeOsScope.of(context);
      final exportDirectoryPath =
          await _archiveService.preferredExportRootPath();
      final latestBackup = await service.getLatestBackup(
        userId: runtime.userId,
        backupType: 'manual',
      );
      final exportHistory = await _archiveService.listHistory(limit: 100);
      if (!mounted) return;
      setState(() {
        _state = ViewState.ready(
          ExportCenterData(
            exportDirectoryPath: exportDirectoryPath,
            latestBackup: latestBackup,
            exportHistory: exportHistory,
          ),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _state = ViewState.error(error.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _state.data;
    final historyItems = _filteredHistory(data?.exportHistory ?? const []);

    return ModulePage(
      title: '导出中心',
      subtitle: 'Export Center',
      actions: [
        OutlinedButton(
          onPressed: _state.status == ViewStatus.loading ? null : _load,
          child: const Text('刷新状态'),
        ),
        ElevatedButton(
          onPressed: _backupActionState.status == ViewStatus.loading
              ? null
              : _createBackup,
          child: Text(
            _backupActionState.status == ViewStatus.loading
                ? '正在创建备份'
                : '立即备份数据库',
          ),
        ),
      ],
      children: [
        SectionCard(
          eyebrow: 'Overview',
          title: '导出结构',
          child: _state.status == ViewStatus.loading
              ? const SectionLoadingView(label: '正在整理导出能力')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '导出模块现在分成三条链：数据库备份、可读归档、状态海报。业务页面不再放置截图或图片导出按钮，相关能力统一从这里进入。',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF5F89FF),
                                      Color(0xFF1D49C6),
                                    ],
                                  ),
                                ),
                                child: const Icon(
                                  Icons.style_outlined,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '状态海报导出',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '走独立模板链，不复用业务页面截图。支持今日 / 本周 / 本月、两套模板和三档隐私模式。',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: const [
                              _Badge(label: '1080×1350 PNG'),
                              _Badge(label: '公开/半公开/私人复盘'),
                              _Badge(label: '海报型 / 极简卡片'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () => Navigator.of(context)
                                .pushNamed('/settings/poster-export'),
                            child: const Text('打开海报导出'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxWidth < 900;
                        final cards = [
                          const _ExportTrackCard(
                            title: '数据备份',
                            icon: Icons.backup_outlined,
                            description: '导出完整数据库副本，用于恢复、迁移与审计。',
                          ),
                          const _ExportTrackCard(
                            title: '状态海报',
                            icon: Icons.image_outlined,
                            description: '使用独立模板导出状态图片，并附带同名 JSON 元数据。',
                          ),
                          const _ExportTrackCard(
                            title: '可读归档',
                            icon: Icons.article_outlined,
                            description:
                                '导出 Markdown / TXT / PDF 可读报告，用于复盘和归档。',
                          ),
                        ];
                        if (compact) {
                          return Column(
                            children: [
                              for (var i = 0; i < cards.length; i++) ...[
                                if (i > 0) const SizedBox(height: 12),
                                cards[i],
                              ],
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cards.length; i++) ...[
                              Expanded(child: cards[i]),
                              if (i < cards.length - 1)
                                const SizedBox(width: 12),
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
        ),
        SectionCard(
          eyebrow: 'Exports',
          title: '导出入口',
          child: _state.status == ViewStatus.loading
              ? const SectionLoadingView(label: '正在读取导出入口')
              : _state.status == ViewStatus.error
                  ? SectionMessageView(
                      icon: Icons.image_not_supported_outlined,
                      title: '导出入口暂不可用',
                      description: _state.message ?? '请稍后重试。',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '图片、报告和数据备份统一从设置页发起；业务页面只保留记录、查看和编辑入口。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 920;
                            final cards = [
                              _ExportModuleCard(
                                title: '数据包导出',
                                icon: Icons.inventory_2_outlined,
                                description:
                                    '导出 JSON / CSV / ZIP 数据包，适合迁移、分析和结构化归档。',
                                note: '使用 export_seed_data 生成原始种子数据。',
                                primaryLabel: '打开数据包导出',
                                onPrimaryTap: () => Navigator.of(context)
                                    .pushNamed('/settings/data-package-export'),
                              ),
                              _ExportModuleCard(
                                title: '报告导出',
                                icon: Icons.article_outlined,
                                description:
                                    '导出 Markdown / TXT / PDF 报告，适合周期复盘和阅读归档。',
                                note: '基于 TodaySummary / ReviewReport 生成。',
                                primaryLabel: '打开报告导出',
                                onPrimaryTap: () => Navigator.of(context)
                                    .pushNamed('/settings/report-export'),
                              ),
                              _ExportModuleCard(
                                title: '状态海报',
                                icon: Icons.style_outlined,
                                description: '独立模板渲染，不复用页面截图，用于社交分享和博客展示。',
                                note: '使用海报数据层、隐私策略和固定海报尺寸。',
                                primaryLabel: '打开海报导出',
                                onPrimaryTap: () => Navigator.of(context)
                                    .pushNamed('/settings/poster-export'),
                              ),
                            ];
                            if (compact) {
                              return Column(
                                children: [
                                  for (var i = 0; i < cards.length; i++) ...[
                                    if (i > 0) const SizedBox(height: 12),
                                    cards[i],
                                  ],
                                ],
                              );
                            }
                            return Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: cards
                                  .map(
                                    (card) => SizedBox(
                                      width: (constraints.maxWidth - 12) / 2,
                                      child: card,
                                    ),
                                  )
                                  .toList(),
                            );
                          },
                        ),
                      ],
                    ),
        ),
        SectionCard(
          eyebrow: 'History',
          title: '统一导出归档',
          child: _state.status == ViewStatus.loading
              ? const SectionLoadingView(label: '正在读取导出归档')
              : _state.status == ViewStatus.error
                  ? SectionMessageView(
                      icon: Icons.folder_off_outlined,
                      title: '导出归档暂不可用',
                      description: _state.message ?? '请稍后重试。',
                    )
                  : data == null || data.exportHistory.isEmpty
                      ? const SectionMessageView(
                          icon: Icons.folder_open_outlined,
                          title: '还没有导出记录',
                          description: '数据包、报告、页面文档和海报导出完成后，都会出现在这里。',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _HistoryFilterBar(
                              query: _historyQuery,
                              typeFilter: _historyTypeFilter,
                              formatFilter: _historyFormatFilter,
                              onQueryChanged: (value) {
                                setState(() => _historyQuery = value);
                              },
                              onTypeChanged: (value) {
                                setState(() => _historyTypeFilter = value);
                              },
                              onFormatChanged: (value) {
                                setState(() => _historyFormatFilter = value);
                              },
                            ),
                            const SizedBox(height: 14),
                            _HistoryStatsRow(
                              allItems: data.exportHistory,
                              filteredItems: historyItems,
                              typeLabel: _typeLabel,
                              formatLabel: _formatLabel,
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _moduleSummaryPills(
                                historyItems,
                              ),
                            ),
                            const SizedBox(height: 16),
                            if (historyItems.isEmpty)
                              const SectionMessageView(
                                icon: Icons.search_off_rounded,
                                title: '没有匹配的导出记录',
                                description: '调整搜索关键词、类型或格式筛选后再查看。',
                              )
                            else
                              for (final item in historyItems.take(40))
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.42),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.58),
                                    ),
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    title: Text(item.title),
                                    subtitle: Text(
                                      '${_moduleLabel(item.module)} · ${_formatLabel(item.format)} · ${_formatDateTime(item.createdAt)}',
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton(
                                          onPressed: () =>
                                              _openExportPreview(item),
                                          child:
                                              Text(_previewActionLabel(item)),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              _deleteExportedDocument(item),
                                          child: const Text('删除'),
                                        ),
                                      ],
                                    ),
                                    onTap: () => _openExportPreview(item),
                                  ),
                                ),
                          ],
                        ),
        ),
        SectionCard(
          eyebrow: 'Archive',
          title: '数据库备份与归档状态',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_backupActionState.status == ViewStatus.data)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InfoBanner(
                    icon: Icons.check_circle_outline_rounded,
                    title: '最新备份已生成',
                    description: _backupActionState.data!.filePath,
                  ),
                ),
              if (_backupActionState.status == ViewStatus.error)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _InfoBanner(
                    icon: Icons.error_outline_rounded,
                    title: '备份创建失败',
                    description: _backupActionState.message ?? '请稍后重试。',
                    danger: true,
                  ),
                ),
              if (data?.latestBackup == null)
                const SectionMessageView(
                  icon: Icons.history_toggle_off_rounded,
                  title: '还没有本地备份',
                  description: '可以直接在这里创建数据库备份，或进入备份与恢复页查看详细历史。',
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '最近一次手动备份',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    SelectableText(data!.latestBackup!.filePath),
                    const SizedBox(height: 8),
                    Text(
                      '创建时间：${data.latestBackup!.createdAt} · ${_fileSize(data.latestBackup!.fileSizeBytes)}',
                    ),
                  ],
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: _backupActionState.status == ViewStatus.loading
                        ? null
                        : _createBackup,
                    child: const Text('创建本地备份'),
                  ),
                  OutlinedButton(
                    onPressed: () =>
                        Navigator.of(context).pushNamed('/settings/backup'),
                    child: const Text('打开备份与恢复'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionCard(
          eyebrow: 'Format',
          title: '文件结构与落盘规则',
          child: _state.status == ViewStatus.loading
              ? const SectionLoadingView(label: '正在读取导出目录')
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('默认导出目录'),
                    const SizedBox(height: 8),
                    SelectableText(
                      data?.exportDirectoryPath ?? '暂无数据',
                    ),
                    const SizedBox(height: 16),
                    const _FormatLine(
                      title: 'PNG 图片',
                      description: '保存当前页面的可视化经营文档。',
                    ),
                    const SizedBox(height: 10),
                    const _FormatLine(
                      title: 'JSON / CSV / ZIP',
                      description: '保存原始结构化数据种子和数据包。',
                    ),
                    const SizedBox(height: 10),
                    const _FormatLine(
                      title: 'Markdown / TXT / PDF',
                      description: '保存可读报告，用于复盘、阅读和归档。',
                    ),
                    const SizedBox(height: 10),
                    const _FormatLine(
                      title: 'JSON 元数据',
                      description: '与图片同名，记录页面窗口、核心指标和导出时间。',
                    ),
                    const SizedBox(height: 10),
                    const _FormatLine(
                      title: '模块目录',
                      description:
                          '按 `today / review / cost / project` 分目录落盘，便于归档与后续批量处理。',
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _createBackup() async {
    setState(() => _backupActionState = ViewState.loading());
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final exportResult = await _exportOrchestrator!.export(
        ExportRequest.backup(
          title: 'backup-manual',
          userId: runtime.userId,
          backupType: 'manual',
        ),
      );
      final artifact = exportResult.primaryArtifact;
      final result = BackupResultModel(
        id: artifact.id,
        backupType: 'manual',
        filePath: artifact.filePath,
        fileSizeBytes:
            (artifact.metadata.toJson()['file_size_bytes'] as num?)?.toInt() ??
                0,
        checksum: artifact.metadata.toJson()['checksum'] as String?,
        success: (artifact.metadata.toJson()['success'] as bool?) ?? true,
        errorMessage: artifact.metadata.toJson()['error_message'] as String?,
        createdAt: artifact.createdAt.toIso8601String(),
      );
      if (!mounted) return;
      setState(() => _backupActionState = ViewState.ready(result));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _backupActionState = ViewState.error(error.toString()));
    }
  }

  Future<void> _openExportPreview(ExportHistoryItem document) async {
    if (document.previewPath != null) {
      await showExportDocumentDialog(
        context,
        _historyItemToImageDocument(document),
        onDelete: () =>
            _deleteExportedDocument(document, showDialogAfter: false),
      );
      return;
    }
    if (_canPreviewAsText(document.format)) {
      await _openTextExportPreview(document);
      return;
    }
    if (!mounted) return;
    final file = File(document.filePath);
    final size = await file.exists() ? await file.length() : 0;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(document.title),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('类型：${document.type.key} · ${document.format.key}'),
              const SizedBox(height: 8),
              Text('大小：${_fileSize(size)}'),
              const SizedBox(height: 12),
              const Text('文件路径'),
              const SizedBox(height: 6),
              SelectableText(document.filePath),
              if (document.metadataPath.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('元数据路径'),
                const SizedBox(height: 6),
                SelectableText(document.metadataPath),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyExportPath(dialogContext, document.filePath),
            child: const Text('复制路径'),
          ),
          TextButton(
            onPressed: () => _shareHistoryItem(dialogContext, document),
            child: const Text('分享'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTextExportPreview(ExportHistoryItem document) async {
    final file = File(document.filePath);
    final exists = await file.exists();
    final size = exists ? await file.length() : 0;
    final content =
        exists ? await file.readAsString() : '文件不存在：${document.filePath}';
    const maxPreviewChars = 120000;
    final clipped = content.length > maxPreviewChars;
    final preview = clipped
        ? '${content.substring(0, maxPreviewChars)}\n\n...预览已截断'
        : content;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(document.title),
        content: SizedBox(
          width: 760,
          height: 620,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_typeLabel(document.type)} · ${_formatLabel(document.format)} · ${_fileSize(size)}',
              ),
              const SizedBox(height: 8),
              SelectableText(document.filePath),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      preview,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyExportPath(dialogContext, document.filePath),
            child: const Text('复制路径'),
          ),
          TextButton(
            onPressed: () => _shareHistoryItem(dialogContext, document),
            child: const Text('分享'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExportPath(BuildContext context, String filePath) async {
    await Clipboard.setData(ClipboardData(text: filePath));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已复制文件路径')),
    );
  }

  Future<void> _shareHistoryItem(
    BuildContext context,
    ExportHistoryItem item,
  ) async {
    try {
      await ExportShareService(service: LifeOsScope.of(this.context)).shareFile(
        filePath: item.filePath,
        title: item.title,
        mimeType: _mimeType(item.format),
        text: 'SkyOS export: ${item.title}',
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开分享面板失败：$error')),
      );
    }
  }

  Future<void> _deleteExportedDocument(
    ExportHistoryItem document, {
    bool showDialogAfter = true,
  }) async {
    try {
      await _archiveService.deleteHistoryItem(document);
      if (!mounted) return;
      if (showDialogAfter) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '已删除导出：${document.filePath.split(Platform.pathSeparator).last}'),
          ),
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除导出失败：$error')),
      );
    }
  }

  String _fileSize(int sizeBytes) {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  ExportedImageDocument _historyItemToImageDocument(ExportHistoryItem item) {
    return ExportedImageDocument(
      module: item.module,
      title: item.title,
      exportedAt: item.createdAt,
      directoryPath: File(item.filePath).parent.path,
      imagePath: item.previewPath ?? item.filePath,
      metadataPath: item.metadataPath,
      metadata: Map<String, dynamic>.from(item.metadata.toJson()),
    );
  }

  List<ExportHistoryItem> _filteredHistory(List<ExportHistoryItem> items) {
    final query = _historyQuery.trim().toLowerCase();
    return items.where((item) {
      if (_historyTypeFilter != null && item.type != _historyTypeFilter) {
        return false;
      }
      if (_historyFormatFilter != null && item.format != _historyFormatFilter) {
        return false;
      }
      if (query.isEmpty) return true;
      final haystack = [
        item.title,
        item.module,
        item.type.key,
        item.format.key,
        item.filePath,
      ].join(' ').toLowerCase();
      return haystack.contains(query);
    }).toList();
  }

  bool _canPreviewAsText(ExportFormat format) {
    switch (format) {
      case ExportFormat.json:
      case ExportFormat.csv:
      case ExportFormat.markdown:
      case ExportFormat.txt:
      case ExportFormat.svg:
        return true;
      case ExportFormat.sqlite:
      case ExportFormat.zip:
      case ExportFormat.pdf:
      case ExportFormat.png:
        return false;
    }
  }

  String _previewActionLabel(ExportHistoryItem item) {
    if (item.previewPath != null || _canPreviewAsText(item.format)) {
      return '预览';
    }
    return '详情';
  }

  List<Widget> _moduleSummaryPills(List<ExportHistoryItem> documents) {
    final counts = <String, int>{};
    for (final item in documents) {
      counts.update(item.module, (value) => value + 1, ifAbsent: () => 1);
    }
    final keys = counts.keys.toList()..sort();
    return [
      for (final key in keys)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
          ),
          child: Text('${_moduleLabel(key)} · ${counts[key]}'),
        ),
    ];
  }

  String _moduleLabel(String module) {
    switch (module) {
      case 'today':
        return 'Today';
      case 'review':
        return 'Review';
      case 'project':
        return 'Project';
      case 'cost':
        return 'Cost';
      case 'day_detail':
        return 'Day Detail';
      case 'poster':
        return 'Poster';
      case 'data_package':
        return 'Data Package';
      case 'report':
        return 'Report';
      case 'backup':
        return 'Backup';
      default:
        return module;
    }
  }

  String _typeLabel(ExportType type) {
    switch (type) {
      case ExportType.backup:
        return '备份';
      case ExportType.dataPackage:
        return '数据包';
      case ExportType.report:
        return '报告';
      case ExportType.snapshot:
        return '页面文档';
      case ExportType.poster:
        return '海报';
    }
  }

  String _formatLabel(ExportFormat format) {
    switch (format) {
      case ExportFormat.sqlite:
        return 'SQLite';
      case ExportFormat.json:
        return 'JSON';
      case ExportFormat.csv:
        return 'CSV';
      case ExportFormat.zip:
        return 'ZIP';
      case ExportFormat.markdown:
        return 'Markdown';
      case ExportFormat.txt:
        return 'TXT';
      case ExportFormat.pdf:
        return 'PDF';
      case ExportFormat.png:
        return 'PNG';
      case ExportFormat.svg:
        return 'SVG';
    }
  }

  String _mimeType(ExportFormat format) {
    switch (format) {
      case ExportFormat.sqlite:
        return 'application/vnd.sqlite3';
      case ExportFormat.json:
        return 'application/json';
      case ExportFormat.csv:
        return 'text/csv';
      case ExportFormat.zip:
        return 'application/zip';
      case ExportFormat.markdown:
        return 'text/markdown';
      case ExportFormat.txt:
        return 'text/plain';
      case ExportFormat.pdf:
        return 'application/pdf';
      case ExportFormat.png:
        return 'image/png';
      case ExportFormat.svg:
        return 'image/svg+xml';
    }
  }

  String _formatDateTime(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute';
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.query,
    required this.typeFilter,
    required this.formatFilter,
    required this.onQueryChanged,
    required this.onTypeChanged,
    required this.onFormatChanged,
  });

  final String query;
  final ExportType? typeFilter;
  final ExportFormat? formatFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ExportType?> onTypeChanged;
  final ValueChanged<ExportFormat?> onFormatChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final search = TextField(
          decoration: const InputDecoration(
            labelText: '搜索历史',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: onQueryChanged,
        );
        final filters = Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            DropdownButton<ExportType?>(
              value: typeFilter,
              hint: const Text('全部类型'),
              items: const [
                DropdownMenuItem<ExportType?>(
                  value: null,
                  child: Text('全部类型'),
                ),
                DropdownMenuItem(
                  value: ExportType.dataPackage,
                  child: Text('数据包'),
                ),
                DropdownMenuItem(
                  value: ExportType.report,
                  child: Text('报告'),
                ),
                DropdownMenuItem(
                  value: ExportType.poster,
                  child: Text('海报'),
                ),
                DropdownMenuItem(
                  value: ExportType.snapshot,
                  child: Text('页面文档'),
                ),
                DropdownMenuItem(
                  value: ExportType.backup,
                  child: Text('备份'),
                ),
              ],
              onChanged: onTypeChanged,
            ),
            DropdownButton<ExportFormat?>(
              value: formatFilter,
              hint: const Text('全部格式'),
              items: const [
                DropdownMenuItem<ExportFormat?>(
                  value: null,
                  child: Text('全部格式'),
                ),
                DropdownMenuItem(value: ExportFormat.png, child: Text('PNG')),
                DropdownMenuItem(value: ExportFormat.svg, child: Text('SVG')),
                DropdownMenuItem(value: ExportFormat.pdf, child: Text('PDF')),
                DropdownMenuItem(
                    value: ExportFormat.markdown, child: Text('Markdown')),
                DropdownMenuItem(value: ExportFormat.txt, child: Text('TXT')),
                DropdownMenuItem(value: ExportFormat.json, child: Text('JSON')),
                DropdownMenuItem(value: ExportFormat.csv, child: Text('CSV')),
                DropdownMenuItem(value: ExportFormat.zip, child: Text('ZIP')),
                DropdownMenuItem(
                    value: ExportFormat.sqlite, child: Text('SQLite')),
              ],
              onChanged: onFormatChanged,
            ),
          ],
        );
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              search,
              const SizedBox(height: 12),
              filters,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: search),
            const SizedBox(width: 16),
            filters,
          ],
        );
      },
    );
  }
}

class _HistoryStatsRow extends StatelessWidget {
  const _HistoryStatsRow({
    required this.allItems,
    required this.filteredItems,
    required this.typeLabel,
    required this.formatLabel,
  });

  final List<ExportHistoryItem> allItems;
  final List<ExportHistoryItem> filteredItems;
  final String Function(ExportType type) typeLabel;
  final String Function(ExportFormat format) formatLabel;

  @override
  Widget build(BuildContext context) {
    final typeCounts = <ExportType, int>{};
    final formatCounts = <ExportFormat, int>{};
    for (final item in filteredItems) {
      typeCounts.update(item.type, (value) => value + 1, ifAbsent: () => 1);
      formatCounts.update(item.format, (value) => value + 1, ifAbsent: () => 1);
    }
    final typeEntries = typeCounts.entries.toList()
      ..sort((a, b) => typeLabel(a.key).compareTo(typeLabel(b.key)));
    final formatEntries = formatCounts.entries.toList()
      ..sort((a, b) => formatLabel(a.key).compareTo(formatLabel(b.key)));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _Badge(label: '匹配 ${filteredItems.length} / ${allItems.length}'),
        for (final entry in typeEntries)
          _Badge(label: '${typeLabel(entry.key)} ${entry.value}'),
        for (final entry in formatEntries)
          _Badge(label: '${formatLabel(entry.key)} ${entry.value}'),
      ],
    );
  }
}

class _ExportTrackCard extends StatelessWidget {
  const _ExportTrackCard({
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _ExportModuleCard extends StatelessWidget {
  const _ExportModuleCard({
    required this.title,
    required this.icon,
    required this.description,
    required this.note,
    required this.primaryLabel,
    this.onPrimaryTap,
  });

  final String title;
  final IconData icon;
  final String description;
  final String note;
  final String primaryLabel;
  final VoidCallback? onPrimaryTap;

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
          Icon(icon),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Text(note, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onPrimaryTap,
              child: Text(primaryLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormatLine extends StatelessWidget {
  const _FormatLine({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(top: 7),
          decoration: const BoxDecoration(
            color: Color(0xFF2363FF),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$title：',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: description),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD9E3FF)),
      ),
      child: Text(label),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.title,
    required this.description,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFF1F1) : const Color(0xFFF4FBF7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: danger ? const Color(0xFFFFD4D4) : const Color(0xFFD9F2E2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
