import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/record_models.dart';
import '../../models/review_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/section_card.dart';
import '../../shared/widgets/state_views.dart';
import 'review_controller.dart';
import 'widgets/review_summary_section.dart';
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

    final pageData = controller.state.data;
    final report = pageData?.report;
    final snapshot = pageData?.snapshot;
    final activeWindow = pageData?.report.window;
    final runtime = LifeOsScope.runtimeOf(context);

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return ModulePage(
          title: '周期复盘',
          subtitle: 'Review',
          actions: [
            for (final kind in ReviewWindowKind.values.take(4))
              ChoiceChip(
                label: Text(_windowLabel(kind)),
                selected: controller.selectedKind == kind,
                onSelected: (_) => controller.changeWindow(
                  kind,
                  LifeOsScope.runtimeOf(context).userId,
                  LifeOsScope.runtimeOf(context).timezone,
                ),
              ),
            OutlinedButton(
              onPressed: () => controller.shiftPeriod(
                -1,
                runtime.userId,
                runtime.timezone,
              ),
              child: const Text('上一周期'),
            ),
            OutlinedButton(
              onPressed: () => controller.shiftPeriod(
                1,
                runtime.userId,
                runtime.timezone,
              ),
              child: const Text('下一周期'),
            ),
            OutlinedButton(
              onPressed: () => controller.jumpToToday(
                runtime.userId,
                runtime.timezone,
              ),
              child: const Text('今天'),
            ),
            OutlinedButton(
              onPressed: () => _pickCustomRange(
                context,
                controller,
                runtime.userId,
                runtime.timezone,
              ),
              child: const Text('自定义区间'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/ai-chat'),
              child: const Text('AI Chat'),
            ),
          ],
          children: [
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
            SectionCard(
              eyebrow: 'Deep Dive',
              title: '项目 ROI / 下沉项目 / 历史流水',
              child: report == null
                  ? SectionMessageView(
                      icon: Icons.analytics_outlined,
                      title: '下钻区已建立',
                      description: controller.state.message ??
                          '这里承接 top projects、sinkhole projects、关键事件和历史流水。',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MetricGroup(
                          title: 'Top Projects',
                          items: [
                            for (final item in report.topProjects)
                              '${item.projectName} · ROI ${(item.operatingRoiPerc).toStringAsFixed(2)}%',
                          ],
                          onItemTap: (index) => _openProject(report.topProjects[index].projectId),
                        ),
                        const SizedBox(height: 16),
                        _MetricGroup(
                          title: 'Sinkhole Projects',
                          items: [
                            for (final item in report.sinkholeProjects)
                              '${item.projectName} · ROI ${(item.operatingRoiPerc).toStringAsFixed(2)}%',
                          ],
                          onItemTap: (index) =>
                              _openProject(report.sinkholeProjects[index].projectId),
                        ),
                        const SizedBox(height: 16),
                        _MetricGroup(
                          title: '时间分配',
                          items: [
                            for (final item in report.timeAllocations)
                              '${item.categoryName} · ${item.minutes} 分钟 · ${item.percentage.toStringAsFixed(1)}%',
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MetricGroup(
                          title: '关键事件',
                          items: [
                            for (final item in report.keyEvents)
                              '${item.title} · ${item.occurredAt}',
                          ],
                        ),
                        const SizedBox(height: 16),
                        _MetricGroup(
                          title: '收入历史',
                          items: [
                            for (final item in report.incomeHistory)
                              '${item.title} · ${item.occurredAt}',
                          ],
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final item in const ['all', 'events', 'income', 'history'])
                              ChoiceChip(
                                label: Text(_historyLabel(item)),
                                selected: _historyFilter == item,
                                onSelected: (_) => setState(() => _historyFilter = item),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _MetricGroup(
                          title: '历史流水',
                          items: [
                            for (final item in _historyItems(report))
                              '${item.title} · ${item.occurredAt}',
                          ],
                        ),
                        const SizedBox(height: 16),
                        _TagMetricSection(
                          title: '时间标签分析',
                          metrics: report.timeTagMetrics,
                          onTap: (metric) => _openTagDetail(
                            context,
                            scope: 'time',
                            tagName: metric.tagName,
                            report: report,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _TagMetricSection(
                          title: '支出标签分析',
                          metrics: report.expenseTagMetrics,
                          onTap: (metric) => _openTagDetail(
                            context,
                            scope: 'expense',
                            tagName: metric.tagName,
                            report: report,
                          ),
                        ),
                      ],
                    ),
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

class _MetricGroup extends StatelessWidget {
  const _MetricGroup({
    required this.title,
    required this.items,
    this.onItemTap,
  });

  final String title;
  final List<String> items;
  final ValueChanged<int>? onItemTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const Text('暂无数据')
        else
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: onItemTap == null ? null : () => onItemTap!(index),
                child: Text(items[index], style: Theme.of(context).textTheme.bodyMedium),
              ),
            ),
      ],
    );
  }
}

class _TagMetricSection extends StatelessWidget {
  const _TagMetricSection({
    required this.title,
    required this.metrics,
    required this.onTap,
  });

  final String title;
  final List<ReviewTagMetric> metrics;
  final ValueChanged<ReviewTagMetric> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final metric in metrics)
              ActionChip(
                label: Text(
                  '${metric.emoji ?? ''} ${metric.tagName} ${(metric.percentage).toStringAsFixed(1)}%',
                ),
                onPressed: () => onTap(metric),
              ),
          ],
        ),
      ],
    );
  }
}
