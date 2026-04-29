import 'dart:io';

import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../features/export/application/export_orchestrator.dart';
import '../../features/export/domain/export_artifact.dart';
import '../../features/export/domain/export_range.dart';
import '../../features/export/domain/export_request.dart';
import '../../models/record_models.dart';
import '../../models/review_models.dart';
import '../../services/export_metadata_builders.dart';
import '../../services/image_export_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/apple_dashboard.dart';
import '../../shared/widgets/export_document_dialog.dart';
import '../../shared/widgets/more_action_menu.dart';
import '../../shared/widgets/state_views.dart';
import 'review_controller.dart';

class ReviewPageRouteArgs {
  const ReviewPageRouteArgs.window(this.windowKind);

  final String windowKind;
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    this.initialKind = ReviewWindowKind.day,
  });

  final ReviewWindowKind initialKind;

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  final GlobalKey _exportBoundaryKey = GlobalKey();
  ExportOrchestrator? _exportOrchestrator;
  ReviewController? _controller;
  bool _loaded = false;
  bool _isExporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ReviewController(LifeOsScope.of(context))
      ..selectedKind = widget.initialKind;
    _exportOrchestrator ??=
        ExportOrchestrator(service: LifeOsScope.of(context));
    if (_loaded) {
      return;
    }
    _loaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final runtime = LifeOsScope.runtimeOf(context);
      _controller!.load(
        userId: runtime.userId,
        timezone: runtime.timezone,
      );
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

    final runtime = LifeOsScope.runtimeOf(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final pageData = controller.state.data;
        final report = pageData?.report;

        return AppleDashboardPage(
          title: '周期复盘',
          subtitle: _windowSubtitle(report?.window, controller.selectedKind),
          exportBoundaryKey: _exportBoundaryKey,
          trailing: MoreActionMenu(
            items: [
              MoreActionMenuItem(
                label: '自定义区间',
                icon: Icons.date_range_rounded,
                onPressed: () => _pickCustomRange(
                  context,
                  controller,
                  runtime.userId,
                  runtime.timezone,
                ),
              ),
              MoreActionMenuItem(
                label: '项目列表',
                icon: Icons.folder_open_rounded,
                onPressed: () => Navigator.of(context).pushNamed('/projects'),
              ),
              MoreActionMenuItem(
                label: '状态海报',
                icon: Icons.style_outlined,
                onPressed: () =>
                    Navigator.of(context).pushNamed('/settings/poster-export'),
              ),
              MoreActionMenuItem(
                label: '导出中心',
                icon: Icons.inventory_2_outlined,
                onPressed: () =>
                    Navigator.of(context).pushNamed('/settings/export-center'),
              ),
              MoreActionMenuItem(
                label: _isExporting ? '正在导出' : '导出图片文档',
                icon: _isExporting
                    ? Icons.downloading_rounded
                    : Icons.image_outlined,
                enabled: !_isExporting && report != null,
                onPressed: report == null || _isExporting
                    ? null
                    : _exportReviewDashboard,
              ),
              MoreActionMenuItem(
                label: 'AI Chat',
                icon: Icons.auto_awesome_rounded,
                onPressed: () => Navigator.of(context).pushNamed('/ai-chat'),
              ),
            ],
          ),
          controls: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppleSegmentedControl<ReviewWindowKind>(
                value: controller.selectedKind == ReviewWindowKind.range
                    ? ReviewWindowKind.week
                    : controller.selectedKind,
                onChanged: (kind) => controller.changeWindow(
                  kind,
                  runtime.userId,
                  runtime.timezone,
                ),
                options: const [
                  AppleSegmentOption(value: ReviewWindowKind.day, label: '日'),
                  AppleSegmentOption(value: ReviewWindowKind.week, label: '周'),
                  AppleSegmentOption(value: ReviewWindowKind.month, label: '月'),
                  AppleSegmentOption(value: ReviewWindowKind.year, label: '年'),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallActionButton(
                      icon: Icons.chevron_left_rounded,
                      label: '上期',
                      onPressed: () => controller.shiftPeriod(
                        -1,
                        runtime.userId,
                        runtime.timezone,
                      ),
                    ),
                    _SmallActionButton(
                      icon: Icons.today_rounded,
                      label: '今天',
                      onPressed: () => controller.jumpToToday(
                        runtime.userId,
                        runtime.timezone,
                      ),
                    ),
                    _SmallActionButton(
                      icon: Icons.chevron_right_rounded,
                      label: '下期',
                      onPressed: () => controller.shiftPeriod(
                        1,
                        runtime.userId,
                        runtime.timezone,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            if (controller.state.status == ViewStatus.loading)
              const AppleDashboardCard(
                child: SectionLoadingView(label: '正在读取周期报告'),
              ),
            _ReviewCoreSummaryCard(
              report: report,
              message: controller.state.message,
            ),
            _ReviewOverviewCard(report: report),
            _ReviewNotesCard(report: report),
            _AdaptiveColumns(
              children: [
                _ReviewTrendCard(report: report),
                _ReviewTimeAnalysisCard(
                  report: report,
                  onTagTap: report == null
                      ? null
                      : (metric) => _openTagDetail(
                            context,
                            scope: 'time',
                            tagName: metric.tagName,
                            report: report,
                          ),
                ),
              ],
            ),
            _AdaptiveColumns(
              children: [
                _ReviewAiEfficiencyCard(report: report),
                _ReviewProjectCard(
                  report: report,
                  onProjectTap: _openProject,
                ),
              ],
            ),
            _ReviewHistoryCard(
              items: report == null ? const [] : _historyItems(report),
              onViewAll: report == null
                  ? null
                  : () => _showHistorySheet(context, _historyItems(report)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickCustomRange(
    BuildContext context,
    ReviewController controller,
    String userId,
    String timezone,
  ) async {
    if (!context.mounted) return;
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final now = DateTime.now();
    final start = await showDatePicker(
      context: rootContext,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: controller.anchorDate,
    );
    if (start == null || !context.mounted) return;
    final end = await showDatePicker(
      context: rootContext,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: start,
    );
    if (end == null) return;
    await controller.setCustomRange(start, end, userId, timezone);
  }

  Future<void> _exportReviewDashboard() async {
    final controller = _controller;
    final data = controller?.state.data;
    if (controller == null || data == null || _isExporting) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      final report = data.report;
      final exportResult = await _exportOrchestrator!.export(
        ExportRequest.snapshot(
          title:
              'review-${data.selectedKind.name}-${report.window.startDate}-${report.window.endDate}',
          module: 'review',
          range: _mapRange(data.selectedKind),
          boundaryKey: _exportBoundaryKey,
          metadata: buildReviewExportMetadata(
            report: report,
            windowKind: data.selectedKind,
            anchorDate: data.anchorDate,
            snapshot: data.snapshot,
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
        SnackBar(content: Text('导出复盘图片文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  ExportRange _mapRange(ReviewWindowKind kind) {
    switch (kind) {
      case ReviewWindowKind.day:
        return ExportRange.today;
      case ReviewWindowKind.week:
        return ExportRange.week;
      case ReviewWindowKind.month:
        return ExportRange.month;
      case ReviewWindowKind.year:
        return ExportRange.year;
      case ReviewWindowKind.range:
        return ExportRange.custom;
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

  void _openProject(String projectId) {
    Navigator.of(context).pushNamed('/projects/$projectId');
  }

  Future<void> _openTagDetail(
    BuildContext context, {
    required String scope,
    required String tagName,
    required ReviewReport report,
  }) async {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final runtime = LifeOsScope.runtimeOf(rootContext);
    final records = await LifeOsScope.of(rootContext).getTagDetailRecords(
      userId: runtime.userId,
      scope: scope,
      tagName: tagName,
      startDate: report.window.startDate,
      endDate: report.window.endDate,
      timezone: runtime.timezone,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: rootContext,
      builder: (dialogContext) => AlertDialog(
        title: Text('$tagName 明细'),
        content: SizedBox(
          width: 520,
          child: records.isEmpty
              ? const Text('没有明细记录')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final item in records)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.title),
                        subtitle: Text(item.detail),
                        trailing: Text(item.occurredAt),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _showHistorySheet(
    BuildContext context,
    List<RecentRecordItem> items,
  ) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    return showModalBottomSheet<void>(
      context: rootContext,
      useRootNavigator: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: AppleDashboardPalette.background,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '历史流水',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppleDashboardPalette.text,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 14),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: AppleDashboardPalette.border,
                  ),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return AppleListRow(
                      leading: AppleIconCircle(
                        icon: _recordIcon(item.kind),
                        color: _recordColor(item.kind),
                      ),
                      title: item.title,
                      subtitle: '${item.kind.label} · ${item.detail}',
                      trailing: Text(
                        item.occurredAt,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppleDashboardPalette.secondaryText,
                            ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<RecentRecordItem> _historyItems(ReviewReport report) {
    final seen = <String>{};
    final items = <RecentRecordItem>[
      ...report.keyEvents,
      ...report.incomeHistory,
      ...report.historyRecords,
    ];
    return items.where((item) => seen.add(item.recordId)).toList();
  }
}

class _AdaptiveColumns extends StatelessWidget {
  const _AdaptiveColumns({
    required this.children,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: 14),
                children[index],
              ],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < children.length; index++) ...[
              Expanded(child: children[index]),
              if (index < children.length - 1) const SizedBox(width: 14),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewCoreSummaryCard extends StatelessWidget {
  const _ReviewCoreSummaryCard({
    required this.report,
    required this.message,
  });

  final ReviewReport? report;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return AppleDashboardCard(
        child: SectionMessageView(
          icon: Icons.summarize_rounded,
          title: '周期总结暂不可用',
          description: message ?? '等待周期报告数据。',
        ),
      );
    }

    return AppleDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppleIconCircle(
                icon: Icons.text_snippet_rounded,
                color: AppleDashboardPalette.primary,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_windowTitle(report!.window.kind)}总结',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppleDashboardPalette.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _reviewSummary(report!),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                  fontSize: 15,
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: _reviewPills(report!).map((pill) {
              return ApplePill(
                label: pill.label,
                backgroundColor: pill.background,
                foregroundColor: pill.foreground,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ReviewOverviewCard extends StatelessWidget {
  const _ReviewOverviewCard({
    required this.report,
  });

  final ReviewReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const AppleDashboardSection(
        title: '周期总览',
        child: SectionMessageView(
          icon: Icons.grid_view_rounded,
          title: '总览数据暂不可用',
          description: '当前没有可展示的核心指标。',
        ),
      );
    }

    final currentNet = report!.totalIncomeCents - report!.totalExpenseCents;
    final previousNet =
        report!.previousIncomeCents - report!.previousExpenseCents;
    final previousHourly = report!.previousWorkMinutes > 0
        ? (report!.previousIncomeCents * 60) ~/ report!.previousWorkMinutes
        : null;
    final currentHourly = report!.actualHourlyRateCents;

    final items = [
      _OverviewMetric(
        label: '收入',
        value: _currency(report!.totalIncomeCents),
        change: _ratioLabel(report!.incomeChangeRatio),
        positive: (report!.incomeChangeRatio ?? 0) >= 0,
      ),
      _OverviewMetric(
        label: '经营支出',
        value: _currency(report!.totalExpenseCents),
        change: _ratioLabel(report!.expenseChangeRatio),
        positive: (report!.expenseChangeRatio ?? 0) <= 0,
      ),
      _OverviewMetric(
        label: '经营结余',
        value: _currency(currentNet),
        change: _deltaRatio(currentNet, previousNet),
        positive: currentNet >= previousNet,
      ),
      _OverviewMetric(
        label: '工作时长',
        value: _hours(report!.totalWorkMinutes),
        change: _ratioLabel(report!.workChangeRatio),
        positive: (report!.workChangeRatio ?? 0) >= 0,
      ),
      _OverviewMetric(
        label: 'AI占比',
        value: _ratio(report!.aiAssistRate),
        change: '本期参与稳定',
        positive: true,
      ),
      _OverviewMetric(
        label: '效率（元/h）',
        value: _hourlyRate(currentHourly),
        change: _deltaRatio(currentHourly, previousHourly),
        positive: (currentHourly ?? 0) >= (previousHourly ?? 0),
      ),
    ];

    return AppleDashboardSection(
      title: '周期总览',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppleDashboardPalette.secondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            '较上期变化',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                ),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 340 ? 2 : 3;
          final tileWidth =
              (constraints.maxWidth - (columns - 1) * 10) / columns;
          return Wrap(
            spacing: 10,
            runSpacing: 10,
            children: items
                .map((item) => SizedBox(
                      width: tileWidth,
                      child: _OverviewMetricTile(item: item),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _ReviewNotesCard extends StatelessWidget {
  const _ReviewNotesCard({required this.report});

  final ReviewReport? report;

  @override
  Widget build(BuildContext context) {
    final notes = report?.reviewNotes ?? const <ReviewNoteModel>[];
    if (notes.isEmpty) {
      return const SizedBox.shrink();
    }
    return AppleDashboardSection(
      title: '复盘素材',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in notes.take(6)) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ApplePill(
                  label: _reviewNoteTypeLabel(note.noteType),
                  backgroundColor: const Color(0xFFE2E8F0),
                  foregroundColor: AppleDashboardPalette.secondaryText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppleDashboardPalette.text,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        note.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppleDashboardPalette.secondaryText,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (note != notes.take(6).last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ReviewTrendCard extends StatelessWidget {
  const _ReviewTrendCard({
    required this.report,
  });

  final ReviewReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const AppleDashboardSection(
        title: '趋势分析',
        child: SectionMessageView(
          icon: Icons.show_chart_rounded,
          title: '趋势暂不可用',
          description: '等待本期与上期的趋势对比。',
        ),
      );
    }

    final currentNet = report!.totalIncomeCents - report!.totalExpenseCents;
    final previousNet =
        report!.previousIncomeCents - report!.previousExpenseCents;

    return AppleDashboardSection(
      title: '趋势分析',
      subtitle: '本期 vs 上期',
      child: Column(
        children: [
          _CompareMetricRow(
            label: '收入',
            currentLabel: _currency(report!.totalIncomeCents),
            previousLabel: _currency(report!.previousIncomeCents),
            currentValue: report!.totalIncomeCents.abs().toDouble(),
            previousValue: report!.previousIncomeCents.abs().toDouble(),
            color: AppleDashboardPalette.primary,
            deltaLabel: _ratioLabel(report!.incomeChangeRatio),
            positive: (report!.incomeChangeRatio ?? 0) >= 0,
          ),
          const SizedBox(height: 14),
          _CompareMetricRow(
            label: '经营支出',
            currentLabel: _currency(report!.totalExpenseCents),
            previousLabel: _currency(report!.previousExpenseCents),
            currentValue: report!.totalExpenseCents.abs().toDouble(),
            previousValue: report!.previousExpenseCents.abs().toDouble(),
            color: AppleDashboardPalette.danger,
            deltaLabel: _ratioLabel(report!.expenseChangeRatio),
            positive: (report!.expenseChangeRatio ?? 0) <= 0,
          ),
          const SizedBox(height: 14),
          _CompareMetricRow(
            label: '经营结余',
            currentLabel: _currency(currentNet),
            previousLabel: _currency(previousNet),
            currentValue: currentNet.abs().toDouble(),
            previousValue: previousNet.abs().toDouble(),
            color: currentNet >= 0
                ? AppleDashboardPalette.success
                : AppleDashboardPalette.warning,
            deltaLabel: _deltaRatio(currentNet, previousNet),
            positive: currentNet >= previousNet,
          ),
          const SizedBox(height: 14),
          _CompareMetricRow(
            label: 'AI占比',
            currentLabel: _ratio(report!.aiAssistRate),
            previousLabel: '上期未提供',
            currentValue: (report!.aiAssistRate ?? 0) * 100,
            previousValue: 0,
            color: AppleDashboardPalette.primary,
            deltaLabel: '当前口径',
            positive: true,
            showPreviousBar: false,
          ),
          const SizedBox(height: 14),
          _CompareMetricRow(
            label: '工作时长',
            currentLabel: _hours(report!.totalWorkMinutes),
            previousLabel: _hours(report!.previousWorkMinutes),
            currentValue: report!.totalWorkMinutes.toDouble(),
            previousValue: report!.previousWorkMinutes.toDouble(),
            color: const Color(0xFF39C2BD),
            deltaLabel: _ratioLabel(report!.workChangeRatio),
            positive: (report!.workChangeRatio ?? 0) >= 0,
          ),
        ],
      ),
    );
  }
}

class _ReviewTimeAnalysisCard extends StatelessWidget {
  const _ReviewTimeAnalysisCard({
    required this.report,
    required this.onTagTap,
  });

  final ReviewReport? report;
  final ValueChanged<ReviewTagMetric>? onTagTap;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const AppleDashboardSection(
        title: '时间分析',
        child: SectionMessageView(
          icon: Icons.stacked_bar_chart_rounded,
          title: '时间分析暂不可用',
          description: '当前没有可展示的时间结构数据。',
        ),
      );
    }

    final allocations = report!.timeAllocations.take(3).toList();
    final total =
        allocations.fold<double>(0, (sum, item) => sum + item.percentage);
    final other = total < 100 ? 100 - total : 0;
    final tags = report!.timeTagMetrics.take(3).toList();

    return AppleDashboardSection(
      title: '时间分析',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 16,
              child: Row(
                children: [
                  for (final item in allocations)
                    Expanded(
                      flex: (item.percentage * 10).round().clamp(1, 1000),
                      child: Container(color: _timeColor(item.categoryName)),
                    ),
                  if (other > 0)
                    Expanded(
                      flex: (other * 10).round(),
                      child: Container(color: const Color(0xFFE7ECF4)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < allocations.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            _LegendRow(
              label: allocations[index].categoryName,
              color: _timeColor(allocations[index].categoryName),
              value:
                  '${_hours(allocations[index].minutes)} · ${allocations[index].percentage.toStringAsFixed(1)}%',
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              '时间标签 TOP 3',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppleDashboardPalette.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 9),
            for (var index = 0; index < tags.length; index++) ...[
              if (index > 0) const SizedBox(height: 10),
              _TagRow(
                metric: tags[index],
                color: _tagColor(index),
                onTap: onTagTap == null ? null : () => onTagTap!(tags[index]),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ReviewAiEfficiencyCard extends StatelessWidget {
  const _ReviewAiEfficiencyCard({
    required this.report,
  });

  final ReviewReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const AppleDashboardSection(
        title: 'AI 与效率',
        child: SectionMessageView(
          icon: Icons.bolt_rounded,
          title: 'AI 与效率暂不可用',
          description: '当前没有可展示的效率质量数据。',
        ),
      );
    }

    final netIncome = report!.totalIncomeCents - report!.totalExpenseCents;
    final unitIncomeHours = netIncome > 0
        ? (report!.totalWorkMinutes / 60) / (netIncome / 10000)
        : null;

    return AppleDashboardSection(
      title: 'AI 与效率',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _QualityMetricRow(
            label: 'AI占比',
            value: report!.aiAssistRate ?? 0,
            displayValue: _ratio(report!.aiAssistRate),
            color: AppleDashboardPalette.primary,
          ),
          const SizedBox(height: 11),
          _QualityMetricRow(
            label: '工作效率（元/h）',
            value: _normalizeEfficiency(
                report!.actualHourlyRateCents, report!.idealHourlyRateCents),
            displayValue: _hourlyRate(report!.actualHourlyRateCents),
            color: AppleDashboardPalette.primary,
            hint: _deltaRatio(
                report!.actualHourlyRateCents, report!.idealHourlyRateCents),
          ),
          const SizedBox(height: 11),
          _QualityMetricRow(
            label: '学习效率',
            value: ((report!.learningEfficiencyAvg ?? 0) / 10).clamp(0.0, 1.0),
            displayValue: report!.learningEfficiencyAvg == null
                ? '暂无数据'
                : '${report!.learningEfficiencyAvg!.toStringAsFixed(1)} / 10',
            color: const Color(0xFF39C2BD),
            hint: report!.learningEfficiencyAvg == null ? null : '学习节奏稳定',
          ),
          const SizedBox(height: 11),
          _QualityMetricRow(
            label: '单位收入耗时',
            value: unitIncomeHours == null
                ? 0
                : (1 / unitIncomeHours).clamp(0.0, 1.0),
            displayValue: unitIncomeHours == null
                ? '暂无数据'
                : '${unitIncomeHours.toStringAsFixed(1)} h / ¥100',
            color: AppleDashboardPalette.success,
            hint: unitIncomeHours == null ? null : '按经营结余折算',
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFD),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppleDashboardPalette.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppleIconCircle(
                  icon: Icons.lightbulb_outline_rounded,
                  color: AppleDashboardPalette.success,
                  size: 36,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _aiSuggestion(report!),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppleDashboardPalette.secondaryText,
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewProjectCard extends StatelessWidget {
  const _ReviewProjectCard({
    required this.report,
    required this.onProjectTap,
  });

  final ReviewReport? report;
  final ValueChanged<String> onProjectTap;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const AppleDashboardSection(
        title: '项目复盘',
        child: SectionMessageView(
          icon: Icons.work_outline_rounded,
          title: '项目复盘暂不可用',
          description: '当前没有可展示的项目数据。',
        ),
      );
    }

    final topProjects = report!.topProjects.take(2).toList();
    final riskProjects = report!.sinkholeProjects.take(2).toList();

    return AppleDashboardSection(
      title: '项目复盘',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProjectGroup(
            title: '值得继续投入',
            items: topProjects,
            positive: true,
            onProjectTap: onProjectTap,
          ),
          const SizedBox(height: 14),
          _ProjectGroup(
            title: '需要警惕',
            items: riskProjects,
            positive: false,
            onProjectTap: onProjectTap,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/projects'),
              child: const Text('查看全部项目'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewHistoryCard extends StatelessWidget {
  const _ReviewHistoryCard({
    required this.items,
    required this.onViewAll,
  });

  final List<RecentRecordItem> items;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppleDashboardSection(
        title: '历史流水',
        child: SectionMessageView(
          icon: Icons.history_rounded,
          title: '暂无历史数据',
          description: '当前周期没有可展示的历史记录。',
        ),
      );
    }

    final visibleItems = items.take(3).toList();
    return AppleDashboardSection(
      title: '历史流水',
      trailing: TextButton(
        onPressed: onViewAll,
        child: const Text('查看全部'),
      ),
      child: Column(
        children: [
          for (var index = 0; index < visibleItems.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, color: AppleDashboardPalette.border),
            AppleListRow(
              leading: AppleIconCircle(
                icon: _recordIcon(visibleItems[index].kind),
                color: _recordColor(visibleItems[index].kind),
              ),
              title: visibleItems[index].title,
              subtitle:
                  '${visibleItems[index].kind.label} · ${visibleItems[index].detail}',
              trailing: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    visibleItems[index].occurredAt,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppleDashboardPalette.secondaryText,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(label),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        foregroundColor: AppleDashboardPalette.secondaryText,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: const BorderSide(color: AppleDashboardPalette.border),
        ),
      ),
    );
  }
}

class _OverviewMetric {
  const _OverviewMetric({
    required this.label,
    required this.value,
    required this.change,
    required this.positive,
  });

  final String label;
  final String value;
  final String change;
  final bool positive;
}

class _OverviewMetricTile extends StatelessWidget {
  const _OverviewMetricTile({
    required this.item,
  });

  final _OverviewMetric item;

  @override
  Widget build(BuildContext context) {
    final tone = item.positive
        ? AppleDashboardPalette.success
        : AppleDashboardPalette.danger;
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppleDashboardPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppleDashboardPalette.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            item.change,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tone,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _CompareMetricRow extends StatelessWidget {
  const _CompareMetricRow({
    required this.label,
    required this.currentLabel,
    required this.previousLabel,
    required this.currentValue,
    required this.previousValue,
    required this.color,
    required this.deltaLabel,
    required this.positive,
    this.showPreviousBar = true,
  });

  final String label;
  final String currentLabel;
  final String previousLabel;
  final double currentValue;
  final double previousValue;
  final Color color;
  final String deltaLabel;
  final bool positive;
  final bool showPreviousBar;

  @override
  Widget build(BuildContext context) {
    final maxValue =
        [currentValue, previousValue, 1.0].reduce((a, b) => a > b ? a : b);
    final tone =
        positive ? AppleDashboardPalette.success : AppleDashboardPalette.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppleDashboardPalette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Text(
              deltaLabel,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _ComparisonBarLine(
          label: '本期',
          valueLabel: currentLabel,
          ratio: currentValue / maxValue,
          color: color,
        ),
        if (showPreviousBar) ...[
          const SizedBox(height: 8),
          _ComparisonBarLine(
            label: '上期',
            valueLabel: previousLabel,
            ratio: previousValue / maxValue,
            color: const Color(0xFFD8DEE8),
            valueColor: AppleDashboardPalette.secondaryText,
          ),
        ],
      ],
    );
  }
}

class _ComparisonBarLine extends StatelessWidget {
  const _ComparisonBarLine({
    required this.label,
    required this.valueLabel,
    required this.ratio,
    required this.color,
    this.valueColor = AppleDashboardPalette.text,
  });

  final String label;
  final String valueLabel;
  final double ratio;
  final Color color;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 30,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppleProgressBar(
            value: ratio,
            color: color,
            height: 10,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            valueLabel,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.label,
    required this.color,
    required this.value,
  });

  final String label;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppleDashboardPalette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppleDashboardPalette.secondaryText,
              ),
        ),
      ],
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.metric,
    required this.color,
    required this.onTap,
  });

  final ReviewTagMetric metric;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                metric.tagName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppleDashboardPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '${_hours(metric.value)} · ${metric.percentage.toStringAsFixed(1)}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppleDashboardPalette.secondaryText,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AppleProgressBar(
          value: metric.percentage / 100,
          color: color,
          height: 9,
        ),
      ],
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: row,
    );
  }
}

class _QualityMetricRow extends StatelessWidget {
  const _QualityMetricRow({
    required this.label,
    required this.value,
    required this.displayValue,
    required this.color,
    this.hint,
  });

  final String label;
  final double value;
  final String displayValue;
  final Color color;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppleDashboardPalette.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              displayValue,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppleDashboardPalette.text,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (hint != null) ...[
              const SizedBox(width: 8),
              Text(
                hint!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppleDashboardPalette.secondaryText,
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        AppleProgressBar(
            value: value.clamp(0.0, 1.0), color: color, height: 10),
      ],
    );
  }
}

class _ProjectGroup extends StatelessWidget {
  const _ProjectGroup({
    required this.title,
    required this.items,
    required this.positive,
    required this.onProjectTap,
  });

  final String title;
  final List<ProjectProgressItem> items;
  final bool positive;
  final ValueChanged<String> onProjectTap;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppleDashboardPalette.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            '暂无项目数据',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppleDashboardPalette.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        for (var index = 0; index < items.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => onProjectTap(items[index].projectId),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFD),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppleDashboardPalette.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].projectName,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppleDashboardPalette.text,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '收入 ${_currency(items[index].incomeEarnedCents)} · 时间 ${_hours(items[index].timeSpentMinutes)} · Time cost ${_currency(items[index].timeCostCents)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppleDashboardPalette.secondaryText,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${items[index].operatingRoiPerc >= 0 ? '+' : ''}${items[index].operatingRoiPerc.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: items[index].operatingRoiPerc >= 0
                              ? AppleDashboardPalette.success
                              : AppleDashboardPalette.danger,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PillStyle {
  const _PillStyle({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}

String _windowSubtitle(ReviewWindow? window, ReviewWindowKind selectedKind) {
  if (window == null) {
    return _windowTitle(selectedKind);
  }
  return '${_windowTitle(window.kind)} · ${_formatRange(window.startDate, window.endDate)}';
}

String _windowTitle(ReviewWindowKind kind) {
  switch (kind) {
    case ReviewWindowKind.day:
      return '本日';
    case ReviewWindowKind.week:
      return '本周';
    case ReviewWindowKind.month:
      return '本月';
    case ReviewWindowKind.year:
      return '本年';
    case ReviewWindowKind.range:
      return '自定义';
  }
}

String _formatRange(String start, String end) {
  final startDate = DateTime.tryParse(start);
  final endDate = DateTime.tryParse(end);
  if (startDate == null || endDate == null) {
    return '$start - $end';
  }
  return '${startDate.month}月${startDate.day}日 - ${endDate.month}月${endDate.day}日';
}

String _reviewSummary(ReviewReport report) {
  final netIncome = report.totalIncomeCents - report.totalExpenseCents;
  final buffer = StringBuffer();
  if (netIncome >= 0) {
    buffer.write('本周期经营结余保持正向，');
  } else {
    buffer.write('本周期经营结余承压，');
  }
  if ((report.aiAssistRate ?? 0) >= 0.35) {
    buffer.write('AI 参与度稳定，');
  } else {
    buffer.write('AI 参与度仍有提升空间，');
  }
  if ((report.workChangeRatio ?? 0) < 0) {
    buffer.write('但工作时长低于上期。');
  } else {
    buffer.write('工作时长维持在可接受区间。');
  }
  if ((report.passiveCoverRatio ?? 0) >= 1) {
    buffer.write(' 被动收入对必要支出的覆盖相对健康。');
  } else {
    buffer.write(' 下一周期建议继续提升深度工作与经营结余表现。');
  }
  return buffer.toString();
}

List<_PillStyle> _reviewPills(ReviewReport report) {
  final netIncome = report.totalIncomeCents - report.totalExpenseCents;
  return [
    _PillStyle(
      label: netIncome >= 0 ? '经营稳定' : '经营承压',
      background:
          netIncome >= 0 ? const Color(0xFFF4FBF7) : const Color(0xFFFFF1F1),
      foreground: netIncome >= 0
          ? AppleDashboardPalette.success
          : AppleDashboardPalette.danger,
    ),
    _PillStyle(
      label: (report.aiAssistRate ?? 0) >= 0.35 ? 'AI参与中等' : 'AI参与偏低',
      background: const Color(0xFFF3F6FF),
      foreground: AppleDashboardPalette.primary,
    ),
    _PillStyle(
      label: (report.workChangeRatio ?? 0) >= 0 ? '时间在线' : '时间不足',
      background: (report.workChangeRatio ?? 0) >= 0
          ? const Color(0xFFF4FBF7)
          : const Color(0xFFFFF4E8),
      foreground: (report.workChangeRatio ?? 0) >= 0
          ? AppleDashboardPalette.success
          : AppleDashboardPalette.warning,
    ),
    if ((report.passiveCoverRatio ?? 0) >= 1)
      const _PillStyle(
        label: '被动覆盖稳定',
        background: Color(0xFFF4FBF7),
        foreground: AppleDashboardPalette.success,
      ),
  ];
}

double _normalizeEfficiency(int? actual, int? ideal) {
  if (actual == null || ideal == null || ideal <= 0) {
    return 0;
  }
  return (actual / ideal).clamp(0.0, 1.0);
}

String _currency(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

String _hours(int minutes) => '${(minutes / 60).toStringAsFixed(1)} h';

String _hourlyRate(int? cents) =>
    cents == null ? '暂无数据' : '¥${(cents / 100).toStringAsFixed(2)}';

String _ratio(double? value) =>
    value == null ? '暂无数据' : '${(value * 100).toStringAsFixed(1)}%';

String _ratioLabel(double? value) {
  if (value == null) {
    return '暂无变化';
  }
  final prefix = value > 0 ? '+' : '';
  return '$prefix${(value * 100).toStringAsFixed(1)}%';
}

String _reviewNoteTypeLabel(String value) {
  switch (value) {
    case 'reflection':
      return '反思';
    case 'feeling':
      return '感受';
    case 'plan':
      return '计划';
    case 'idea':
      return '灵感';
    case 'context':
      return '上下文';
    case 'ai_usage':
      return 'AI 使用';
    case 'risk':
      return '风险';
    case 'summary':
      return '总结';
    default:
      return '复盘';
  }
}

String _deltaRatio(int? current, int? previous) {
  if (current == null || previous == null) {
    return '暂无变化';
  }
  if (previous == 0) {
    return current == 0 ? '0.0%' : '新增';
  }
  final ratio = (current - previous) / previous.abs();
  final prefix = ratio > 0 ? '+' : '';
  return '$prefix${(ratio * 100).toStringAsFixed(1)}%';
}

Color _timeColor(String label) {
  if (label.contains('工作')) {
    return AppleDashboardPalette.primary;
  }
  if (label.contains('学习')) {
    return AppleDashboardPalette.warning;
  }
  return const Color(0xFF39C2BD);
}

Color _tagColor(int index) {
  switch (index) {
    case 0:
      return AppleDashboardPalette.primary;
    case 1:
      return AppleDashboardPalette.warning;
    default:
      return AppleDashboardPalette.success;
  }
}

String _aiSuggestion(ReviewReport report) {
  if ((report.aiAssistRate ?? 0) >= 0.4 &&
      (report.workEfficiencyAvg ?? 0) >= 7) {
    return 'AI 参与稳定，当前可以继续把辅助流程集中到高价值任务，进一步提高产出密度。';
  }
  if ((report.aiAssistRate ?? 0) < 0.25) {
    return 'AI 参与度偏低，可以优先在重复整理、结构化总结和复盘环节提高协作比例。';
  }
  return 'AI 参与稳定，但仍可提升高价值任务占比，让工具更多服务于深度工作。';
}

IconData _recordIcon(RecordKind kind) {
  switch (kind) {
    case RecordKind.time:
      return Icons.work_history_rounded;
    case RecordKind.income:
      return Icons.account_balance_wallet_rounded;
    case RecordKind.expense:
      return Icons.receipt_long_rounded;
    case RecordKind.learning:
      return Icons.menu_book_rounded;
  }
}

Color _recordColor(RecordKind kind) {
  switch (kind) {
    case RecordKind.time:
      return AppleDashboardPalette.primary;
    case RecordKind.income:
      return AppleDashboardPalette.success;
    case RecordKind.expense:
      return AppleDashboardPalette.danger;
    case RecordKind.learning:
      return AppleDashboardPalette.warning;
  }
}
