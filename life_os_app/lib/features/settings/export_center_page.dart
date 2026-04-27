import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/project_models.dart';
import '../../models/sync_models.dart';
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
    required this.projects,
    required this.exportedDocuments,
  });

  final String exportDirectoryPath;
  final BackupResultModel? latestBackup;
  final List<ProjectOverview> projects;
  final List<ExportedImageDocument> exportedDocuments;
}

class ExportCenterPage extends StatefulWidget {
  const ExportCenterPage({super.key});

  @override
  State<ExportCenterPage> createState() => _ExportCenterPageState();
}

class _ExportCenterPageState extends State<ExportCenterPage> {
  final ImageExportService _imageExportService = const ImageExportService();
  ViewState<ExportCenterData> _state = ViewState.initial();
  ViewState<BackupResultModel> _backupActionState = ViewState.initial();
  String? _selectedProjectId;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
          await _imageExportService.preferredExportDirectoryPath();
      final latestBackup = await service.getLatestBackup(
        userId: runtime.userId,
        backupType: 'manual',
      );
      final projects = await service.getProjects(userId: runtime.userId);
      final exportedDocuments =
          await _imageExportService.listExportedDocuments(limit: 60);
      if (!mounted) return;
      setState(() {
        _selectedProjectId = _resolveProjectSelection(
          current: _selectedProjectId,
          projects: projects,
        );
        _state = ViewState.ready(
          ExportCenterData(
            exportDirectoryPath: exportDirectoryPath,
            latestBackup: latestBackup,
            projects: projects,
            exportedDocuments: exportedDocuments,
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
    final runtime = LifeOsScope.runtimeOf(context);
    final selectedProject = data?.projects
        .where((item) => item.id == _selectedProjectId)
        .cast<ProjectOverview?>()
        .firstWhere((item) => item != null, orElse: () => null);

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
                      '导出模块现在分成三条链：数据库备份、可读归档、状态图片文档。当前已经把图片文档导出做成统一模块，并与数据库备份并列收拢到这个入口。',
                      style: Theme.of(context).textTheme.bodyLarge,
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
                            title: '图片文档',
                            icon: Icons.image_outlined,
                            description: '导出经营页面视觉文档，并附带同名 JSON 元数据。',
                          ),
                          const _ExportTrackCard(
                            title: '可读归档',
                            icon: Icons.article_outlined,
                            description:
                                '下一阶段补 Markdown / PDF 报告，让图片与文本归档形成完整输出。',
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
          eyebrow: 'Image Docs',
          title: '已接入的图片文档导出',
          child: _state.status == ViewStatus.loading
              ? const SectionLoadingView(label: '正在读取图片导出入口')
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
                          '这些页面已经接入统一的图片导出服务。进入页面后，可以直接在页面顶部触发导出，产出 `png + json metadata`。',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth < 920;
                            final cards = [
                              _ExportModuleCard(
                                title: '今日经营状态',
                                icon: Icons.today_rounded,
                                description: '导出现金流、健康度、目标进度与最近记录。',
                                note: 'Today 页面已支持直接导出。',
                                primaryLabel: '打开 Today',
                                onPrimaryTap: () =>
                                    Navigator.of(context).pushNamed('/today'),
                              ),
                              _ExportModuleCard(
                                title: '周期复盘',
                                icon: Icons.auto_graph_rounded,
                                description: '导出周期趋势、AI 效率、项目复盘与历史流水。',
                                note: 'Review 页面已支持直接导出。',
                                primaryLabel: '打开 Review',
                                onPrimaryTap: () =>
                                    Navigator.of(context).pushNamed('/review'),
                              ),
                              _ExportModuleCard(
                                title: '成本管理',
                                icon: Icons.account_balance_wallet_outlined,
                                description: '导出月基线、时薪比较、周期规则与 CAPEX 状态。',
                                note: 'Cost 页面已接入统一导出边界。',
                                primaryLabel: '打开 Cost',
                                onPrimaryTap: () => Navigator.of(context)
                                    .pushNamed('/cost-management'),
                              ),
                              _ExportModuleCard(
                                title: '项目详情',
                                icon: Icons.folder_open_rounded,
                                description: '导出项目经营判断、全成本 ROI 与最近月度快照。',
                                note: selectedProject == null
                                    ? '先选择一个项目，再进入详情页导出。'
                                    : '当前目标：${selectedProject.name}',
                                primaryLabel: '打开项目详情',
                                onPrimaryTap: selectedProject == null
                                    ? null
                                    : () => Navigator.of(context).pushNamed(
                                        '/projects/${selectedProject.id}'),
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedProjectId,
                                  isExpanded: true,
                                  decoration: const InputDecoration(
                                    labelText: '导出目标项目',
                                  ),
                                  items: [
                                    for (final item
                                        in data?.projects ?? const [])
                                      DropdownMenuItem<String>(
                                        value: item.id,
                                        child: Text(item.name),
                                      ),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedProjectId = value);
                                  },
                                ),
                              ),
                              _ExportModuleCard(
                                title: '日详情',
                                icon: Icons.calendar_month_rounded,
                                description: '导出指定日期的流水明细与记录结构。',
                                note: '当前默认打开今天的明细页后导出。',
                                primaryLabel: '打开今日明细',
                                onPrimaryTap: () => Navigator.of(context)
                                    .pushNamed('/day/${runtime.todayDate}'),
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
          title: '图片文档归档',
          child: _state.status == ViewStatus.loading
              ? const SectionLoadingView(label: '正在读取导出归档')
              : _state.status == ViewStatus.error
                  ? SectionMessageView(
                      icon: Icons.folder_off_outlined,
                      title: '导出归档暂不可用',
                      description: _state.message ?? '请稍后重试。',
                    )
                  : data == null || data.exportedDocuments.isEmpty
                      ? const SectionMessageView(
                          icon: Icons.image_not_supported_outlined,
                          title: '还没有图片导出记录',
                          description:
                              '从 Today、Review、Project、Cost 或 Day Detail 页面导出后，这里会自动出现历史文档。',
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _moduleSummaryPills(
                                data.exportedDocuments,
                              ),
                            ),
                            const SizedBox(height: 16),
                            for (final item in data.exportedDocuments.take(20))
                              Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.42),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.58),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  title: Text(item.title),
                                  subtitle: Text(
                                    '${_moduleLabel(item.module)} · ${_formatDateTime(item.exportedAt)}',
                                  ),
                                  trailing: Wrap(
                                    spacing: 8,
                                    children: [
                                      TextButton(
                                        onPressed: () =>
                                            _openExportPreview(item),
                                        child: const Text('预览'),
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
      final result = await LifeOsScope.of(context).createBackup(
        userId: runtime.userId,
        backupType: 'manual',
      );
      if (!mounted) return;
      setState(() => _backupActionState = ViewState.ready(result));
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _backupActionState = ViewState.error(error.toString()));
    }
  }

  Future<void> _openExportPreview(ExportedImageDocument document) async {
    await showExportDocumentDialog(
      context,
      document,
      onDelete: () => _deleteExportedDocument(document, showDialogAfter: false),
    );
  }

  Future<void> _deleteExportedDocument(
    ExportedImageDocument document, {
    bool showDialogAfter = true,
  }) async {
    try {
      await _imageExportService.deleteExportedDocument(document);
      if (!mounted) return;
      if (showDialogAfter) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已删除导出：${document.fileName}')),
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

  String? _resolveProjectSelection({
    required String? current,
    required List<ProjectOverview> projects,
  }) {
    if (projects.isEmpty) return null;
    if (current != null && projects.any((item) => item.id == current)) {
      return current;
    }
    return projects.first.id;
  }

  String _fileSize(int sizeBytes) {
    if (sizeBytes <= 0) return '0 B';
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  List<Widget> _moduleSummaryPills(List<ExportedImageDocument> documents) {
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
      default:
        return module;
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
    this.child,
    this.onPrimaryTap,
  });

  final String title;
  final IconData icon;
  final String description;
  final String note;
  final String primaryLabel;
  final Widget? child;
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
          if (child != null) ...[
            const SizedBox(height: 14),
            child!,
          ],
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
