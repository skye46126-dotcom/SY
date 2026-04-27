import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/record_models.dart';
import '../../models/review_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/more_action_menu.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/period_navigator.dart';
import '../../shared/widgets/segmented_control.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';
import 'review_controller.dart';
import 'widgets/review_history_section.dart';
import 'widgets/review_project_performance_section.dart';
import 'widgets/review_quality_section.dart';
import 'widgets/review_summary_section.dart';
import 'widgets/review_tag_analysis_section.dart';
import 'widgets/review_time_allocation_section.dart';
import 'widgets/review_trend_section.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  ReviewController? _controller;
  bool _loaded = false;
  String _historyFilter = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ReviewController(LifeOsScope.of(context));
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
        final snapshot = pageData?.snapshot;
        final activeWindow = pageData?.report.window;

        return ModulePage(
          title: '周期复盘',
          subtitle: 'Review',
          actions: [
            MoreActionMenu(
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
                  label: 'AI Chat',
                  icon: Icons.auto_awesome_rounded,
                  onPressed: () => Navigator.of(context).pushNamed('/ai-chat'),
                ),
                const MoreActionMenuItem(
                  label: '重新生成报告',
                  icon: Icons.refresh_rounded,
                  enabled: false,
                ),
                const MoreActionMenuItem(
                  label: '导出报告',
                  icon: Icons.ios_share_rounded,
                  enabled: false,
                ),
              ],
            ),
          ],
          children: [
            SegmentedControl<ReviewWindowKind>(
              value: controller.selectedKind == ReviewWindowKind.range
                  ? null
                  : controller.selectedKind,
              onChanged: (kind) => controller.changeWindow(
                kind,
                runtime.userId,
                runtime.timezone,
              ),
              options: [
                for (final kind in ReviewWindowKind.values.take(4))
                  SegmentedControlOption(
                    value: kind,
                    label: _windowLabel(kind),
                  ),
              ],
            ),
            PeriodNavigator(
              currentLabel: activeWindow?.periodName ?? '当前周期',
              onPrevious: () => controller.shiftPeriod(
                -1,
                runtime.userId,
                runtime.timezone,
              ),
              onToday: () => controller.jumpToToday(
                runtime.userId,
                runtime.timezone,
              ),
              onNext: () => controller.shiftPeriod(
                1,
                runtime.userId,
                runtime.timezone,
              ),
            ),
            if (controller.state.status == ViewStatus.loading)
              const SectionLoadingView(label: '正在读取复盘报告'),
            if (activeWindow != null)
              SectionCard(
                eyebrow: 'Window',
                title: '当前复盘窗口',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('当前: ${activeWindow.periodName}'),
                    const SizedBox(height: 8),
                    Text(
                      '对比: ${activeWindow.previousStartDate} - ${activeWindow.previousEndDate}',
                    ),
                  ],
                ),
              ),
            ReviewSummarySection(
              report: report,
              snapshot: snapshot,
              message: controller.state.message,
            ),
            ReviewTrendSection(report: report, snapshot: snapshot),
            ReviewTimeAllocationSection(report: report),
            ReviewQualitySection(report: report),
            ReviewProjectPerformanceSection(
              title: '值得继续投入的项目',
              projects: report?.topProjects ?? const [],
              onProjectTap: _openProject,
            ),
            ReviewProjectPerformanceSection(
              title: '需要警惕的项目',
              projects: report?.sinkholeProjects ?? const [],
              onProjectTap: _openProject,
            ),
            ReviewTagAnalysisSection(
              title: '时间标签分析',
              metrics: report?.timeTagMetrics ?? const [],
              onTap: (metric) => _openTagDetail(
                context,
                scope: 'time',
                tagName: metric.tagName,
                report: report!,
              ),
            ),
            ReviewTagAnalysisSection(
              title: '支出标签分析',
              metrics: report?.expenseTagMetrics ?? const [],
              onTap: (metric) => _openTagDetail(
                context,
                scope: 'expense',
                tagName: metric.tagName,
                report: report!,
              ),
            ),
            SectionCard(
              eyebrow: 'History Filter',
              title: '历史筛选',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const ['all', 'events', 'income', 'history'])
                    ChoiceChip(
                      label: Text(_historyLabel(item)),
                      selected: _historyFilter == item,
                      onSelected: (_) => setState(() => _historyFilter = item),
                    ),
                ],
              ),
            ),
            ReviewHistorySection(
              title: '历史流水',
              items: report == null ? const [] : _historyItems(report),
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
    final now = DateTime.now();
    final start = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: controller.anchorDate,
    );
    if (start == null || !context.mounted) return;
    final end = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDate: start,
    );
    if (end == null) return;
    await controller.setCustomRange(start, end, userId, timezone);
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
    final runtime = LifeOsScope.runtimeOf(context);
    final records = await LifeOsScope.of(context).getTagDetailRecords(
      userId: runtime.userId,
      scope: scope,
      tagName: tagName,
      startDate: report.window.startDate,
      endDate: report.window.endDate,
      timezone: runtime.timezone,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
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

  String _windowLabel(ReviewWindowKind kind) {
    switch (kind) {
      case ReviewWindowKind.day:
        return '日';
      case ReviewWindowKind.week:
        return '周';
      case ReviewWindowKind.month:
        return '月';
      case ReviewWindowKind.year:
        return '年';
      case ReviewWindowKind.range:
        return '自定义';
    }
  }

  String _historyLabel(String value) {
    switch (value) {
      case 'events':
        return '关键事件';
      case 'income':
        return '收入历史';
      case 'history':
        return '全部流水';
      default:
        return '综合';
    }
  }

  List<RecentRecordItem> _historyItems(ReviewReport report) {
    switch (_historyFilter) {
      case 'events':
        return report.keyEvents;
      case 'income':
        return report.incomeHistory;
      case 'history':
        return report.historyRecords;
      default:
        return [
          ...report.keyEvents,
          ...report.incomeHistory,
          ...report.historyRecords,
        ];
    }
  }
}
