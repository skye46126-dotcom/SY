import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/overview_models.dart';
import '../../models/project_models.dart';
import '../../models/record_models.dart';
import '../../models/snapshot_models.dart';
import '../../models/tag_models.dart';
import '../../services/export_metadata_builders.dart';
import '../../services/image_export_service.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/apple_dashboard.dart';
import '../../shared/widgets/export_document_dialog.dart';
import '../../shared/widgets/state_views.dart';
import '../review/widgets/record_editor_dialog.dart';
import '../review/review_page.dart';
import 'today_controller.dart';

enum _TodayScope {
  today,
  week,
  month,
}

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final GlobalKey _exportBoundaryKey = GlobalKey();
  final ImageExportService _imageExportService = const ImageExportService();
  TodayController? _controller;
  bool _hasLoaded = false;
  bool _isExporting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= TodayController(LifeOsScope.of(context));
    if (_hasLoaded) {
      return;
    }
    _hasLoaded = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final runtime = LifeOsScope.runtimeOf(context);
      _controller!.load(
        userId: runtime.userId,
        anchorDate: runtime.todayDate,
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

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.state;
        final data = state.data;
        final runtime = LifeOsScope.runtimeOf(context);

        return AppleDashboardPage(
          title: '今日经营状态',
          subtitle: _formatDateLabel(runtime.todayDate),
          exportBoundaryKey: _exportBoundaryKey,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppleCircleButton(
                icon: Icons.style_outlined,
                onPressed: () =>
                    Navigator.of(context).pushNamed('/settings/poster-export'),
              ),
              const SizedBox(width: 12),
              AppleCircleButton(
                icon: _isExporting
                    ? Icons.downloading_rounded
                    : Icons.image_outlined,
                onPressed:
                    data == null || _isExporting ? null : _exportTodayDashboard,
              ),
              const SizedBox(width: 12),
              AppleCircleButton(
                icon: Icons.notifications_none_rounded,
                onPressed: () => Navigator.of(context).pushNamed('/settings'),
              ),
            ],
          ),
          controls: AppleSegmentedControl<_TodayScope>(
            value: _TodayScope.today,
            onChanged: _handleScopeChange,
            options: const [
              AppleSegmentOption(value: _TodayScope.today, label: '今天'),
              AppleSegmentOption(value: _TodayScope.week, label: '本周'),
              AppleSegmentOption(value: _TodayScope.month, label: '本月'),
            ],
          ),
          children: [
            if (state.status == ViewStatus.loading)
              const AppleDashboardCard(
                child: SectionLoadingView(label: '正在读取经营状态'),
              ),
            _TodaySummaryCard(
              overview: data?.overview,
              summary: data?.summary,
              message: state.message,
            ),
            _TodayKpiStrip(
              overview: data?.overview,
              summary: data?.summary,
            ),
            _AdaptiveColumns(
              children: [
                _TodayCashflowCard(
                  overview: data?.overview,
                  summary: data?.summary,
                  message: state.message,
                ),
                _TodayTimeStructureCard(overview: data?.overview),
              ],
            ),
            _TodayGoalProgressCard(goalProgress: data?.goalProgress),
            _AdaptiveColumns(
              children: [
                _TodayHealthCard(
                  overview: data?.overview,
                  summary: data?.summary,
                  snapshot: data?.snapshot,
                ),
                _TodayAlertsCard(alerts: data?.alerts),
              ],
            ),
            _TodayRecentRecordsCard(
              records: data?.recentRecords,
              message: state.message,
              onEdit: _editRecord,
              onCopy: _copyRecord,
              onDelete: _deleteRecord,
              onViewAll: () =>
                  Navigator.of(context).pushNamed('/day/${runtime.todayDate}'),
            ),
          ],
        );
      },
    );
  }

  void _handleScopeChange(_TodayScope next) {
    if (next == _TodayScope.today) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(
      '/review',
      arguments: next == _TodayScope.week
          ? ReviewPageRouteArgs.window('week')
          : ReviewPageRouteArgs.window('month'),
    );
  }

  Future<void> _exportTodayDashboard() async {
    final controller = _controller;
    final data = controller?.state.data;
    if (controller == null || data == null || _isExporting) {
      return;
    }

    setState(() => _isExporting = true);
    try {
      final runtime = LifeOsScope.runtimeOf(context);
      final result = await _imageExportService.exportBoundary(
        boundaryKey: _exportBoundaryKey,
        module: 'today',
        title: 'today-${runtime.todayDate}',
        metadata: buildTodayExportMetadata(
          overview: data.overview,
          summary: data.summary,
          alerts: data.alerts,
          recentRecordCount: data.recentRecords.length,
          anchorDate: runtime.todayDate,
          timezone: runtime.timezone,
          snapshot: data.snapshot,
        ),
      );
      if (!mounted) return;
      await showExportDocumentDialog(context, result);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导出今日图片文档失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _deleteRecord(RecentRecordItem record) async {
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
    _controller?.load(
      userId: runtime.userId,
      anchorDate: runtime.todayDate,
      timezone: runtime.timezone,
    );
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
      builder: (dialogContext) {
        final typedProjectOptions = projectOptions.cast<ProjectOption>();
        final typedTags = tags.cast<TagModel>();
        switch (record.kind) {
          case RecordKind.time:
            return RecordEditorDialog.time(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              timeSnapshot: TimeRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.income:
            return RecordEditorDialog.income(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              incomeSnapshot: IncomeRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.expense:
            return RecordEditorDialog.expense(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              expenseSnapshot: ExpenseRecordSnapshotModel.fromJson(
                  snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.learning:
            return RecordEditorDialog.learning(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
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
    _controller?.load(
      userId: runtime.userId,
      anchorDate: runtime.todayDate,
      timezone: runtime.timezone,
    );
  }

  Future<void> _copyRecord(RecentRecordItem record) async {
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
    if (snapshot == null) return;
    switch (record.kind) {
      case RecordKind.time:
        await service.createTimeRecord({
          'user_id': runtime.userId,
          'started_at': snapshot['started_at'],
          'ended_at': snapshot['ended_at'],
          'category_code': snapshot['category_code'],
          'efficiency_score': snapshot['efficiency_score'],
          'value_score': snapshot['value_score'],
          'state_score': snapshot['state_score'],
          'ai_assist_ratio': snapshot['ai_assist_ratio'],
          'note': snapshot['note'],
          'source': 'manual',
          'is_public_pool': false,
          'project_allocations': snapshot['project_allocations'],
          'tag_ids': snapshot['tag_ids'],
        });
      case RecordKind.income:
        await service.createIncomeRecord({
          'user_id': runtime.userId,
          'occurred_on': snapshot['occurred_on'],
          'source_name': snapshot['source_name'],
          'type_code': snapshot['type_code'],
          'amount_cents': snapshot['amount_cents'],
          'is_passive': snapshot['is_passive'],
          'ai_assist_ratio': snapshot['ai_assist_ratio'],
          'note': snapshot['note'],
          'source': 'manual',
          'is_public_pool': snapshot['is_public_pool'] ?? false,
          'project_allocations': snapshot['project_allocations'],
          'tag_ids': snapshot['tag_ids'],
        });
      case RecordKind.expense:
        await service.createExpenseRecord({
          'user_id': runtime.userId,
          'occurred_on': snapshot['occurred_on'],
          'category_code': snapshot['category_code'],
          'amount_cents': snapshot['amount_cents'],
          'ai_assist_ratio': snapshot['ai_assist_ratio'],
          'note': snapshot['note'],
          'source': 'manual',
          'project_allocations': snapshot['project_allocations'],
          'tag_ids': snapshot['tag_ids'],
        });
      case RecordKind.learning:
        await service.createLearningRecord({
          'user_id': runtime.userId,
          'occurred_on': snapshot['occurred_on'],
          'started_at': snapshot['started_at'],
          'ended_at': snapshot['ended_at'],
          'content': snapshot['content'],
          'duration_minutes': snapshot['duration_minutes'],
          'application_level_code': snapshot['application_level_code'],
          'efficiency_score': snapshot['efficiency_score'],
          'ai_assist_ratio': snapshot['ai_assist_ratio'],
          'note': snapshot['note'],
          'source': 'manual',
          'is_public_pool': snapshot['is_public_pool'] ?? false,
          'project_allocations': snapshot['project_allocations'],
          'tag_ids': snapshot['tag_ids'],
        });
    }
    if (!mounted) return;
    _controller?.load(
      userId: runtime.userId,
      anchorDate: runtime.todayDate,
      timezone: runtime.timezone,
    );
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
        if (constraints.maxWidth < 860) {
          return Column(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(height: 20),
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
              if (index < children.length - 1) const SizedBox(width: 20),
            ],
          ],
        );
      },
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({
    required this.overview,
    required this.summary,
    required this.message,
  });

  final TodayOverview? overview;
  final TodaySummaryModel? summary;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (overview == null || summary == null) {
      return AppleDashboardCard(
        child: SectionMessageView(
          icon: Icons.insights_rounded,
          title: '等待经营数据',
          description: message ?? '当前没有可展示的经营摘要。',
        ),
      );
    }

    final metrics = [
      _SummaryMetric(
        label: '收入',
        value: _currency(overview!.totalIncomeCents),
        caption: '现金结余 ${_currency(overview!.netIncomeCents)}',
      ),
      _SummaryMetric(
        label: '时长',
        value: _hours(overview!.totalTimeMinutes),
        caption:
            '工作 ${_hours(overview!.totalWorkMinutes)} · 学习 ${_hours(overview!.totalLearningMinutes)}',
      ),
      _SummaryMetric(
        label: '被动覆盖率',
        value: _ratioFromBps(summary!.passiveCoverRatioBps),
        caption: summary!.freedomCents == null
            ? '覆盖必要支出'
            : '自由度 ${_currency(summary!.freedomCents!)}',
      ),
      _SummaryMetric(
        label: '实际时薪',
        value: _hourlyRate(summary!.actualHourlyRateCents),
        caption: '目标 ${_hourlyRate(summary!.idealHourlyRateCents)}',
      ),
    ];

    return AppleDashboardCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppleIconCircle(
                icon: Icons.auto_graph_rounded,
                color: AppleDashboardPalette.primary,
                size: 42,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '核心摘要',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppleDashboardPalette.text,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      summary!.headline,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: AppleDashboardPalette.secondaryText,
                            height: 1.5,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _buildTodayPills(summary!).map((pill) {
              return ApplePill(
                label: pill.label,
                backgroundColor: pill.backgroundColor,
                foregroundColor: pill.foregroundColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 760;
              if (compact) {
                return Column(
                  children: [
                    for (var index = 0; index < metrics.length; index++) ...[
                      if (index > 0) const SizedBox(height: 12),
                      _SummaryMetricTile(metric: metrics[index]),
                    ],
                  ],
                );
              }
              return Row(
                children: [
                  for (var index = 0; index < metrics.length; index++) ...[
                    Expanded(child: _SummaryMetricTile(metric: metrics[index])),
                    if (index < metrics.length - 1) const SizedBox(width: 12),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TodayKpiStrip extends StatelessWidget {
  const _TodayKpiStrip({
    required this.overview,
    required this.summary,
  });

  final TodayOverview? overview;
  final TodaySummaryModel? summary;

  @override
  Widget build(BuildContext context) {
    final items = [
      _KpiItem(
        icon: Icons.account_balance_wallet_rounded,
        color: AppleDashboardPalette.primary,
        title: '收入',
        value:
            overview == null ? '暂无数据' : _currency(overview!.totalIncomeCents),
        caption: overview == null
            ? '等待经营数据'
            : '现金结余 ${_currency(overview!.netIncomeCents)}',
      ),
      _KpiItem(
        icon: Icons.schedule_rounded,
        color: AppleDashboardPalette.success,
        title: '时长',
        value: overview == null ? '暂无数据' : _hours(overview!.totalTimeMinutes),
        caption: overview == null
            ? '等待经营数据'
            : '工作 ${_hours(overview!.totalWorkMinutes)}',
      ),
      _KpiItem(
        icon: Icons.bolt_rounded,
        color: AppleDashboardPalette.warning,
        title: '效率',
        value: summary == null
            ? '暂无数据'
            : _hourlyRate(summary!.actualHourlyRateCents),
        caption: summary == null
            ? '等待经营数据'
            : '理想 ${_hourlyRate(summary!.idealHourlyRateCents)}',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 860;
        if (compact) {
          return Column(
            children: [
              for (var index = 0; index < items.length; index++) ...[
                if (index > 0) const SizedBox(height: 16),
                _KpiCard(item: items[index]),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: _KpiCard(item: items[index])),
              if (index < items.length - 1) const SizedBox(width: 16),
            ],
          ],
        );
      },
    );
  }
}

class _TodayCashflowCard extends StatelessWidget {
  const _TodayCashflowCard({
    required this.overview,
    required this.summary,
    required this.message,
  });

  final TodayOverview? overview;
  final TodaySummaryModel? summary;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return AppleDashboardSection(
        title: '今日现金流',
        child: SectionMessageView(
          icon: Icons.bar_chart_rounded,
          title: '现金流图表暂不可用',
          description: message ?? '等待今日现金流数据。',
        ),
      );
    }

    return AppleDashboardSection(
      title: '今日现金流',
      subtitle: '单位：元',
      child: Column(
        children: [
          _VerticalBarChart(
            bars: [
              _BarDatum(
                label: '收入',
                value: overview!.totalIncomeCents / 100,
                color: AppleDashboardPalette.primary,
                valueLabel: _currency(overview!.totalIncomeCents),
              ),
              _BarDatum(
                label: '现金支出',
                value: overview!.totalExpenseCents / 100,
                color: AppleDashboardPalette.danger,
                valueLabel: _currency(overview!.totalExpenseCents),
              ),
              _BarDatum(
                label: '现金结余',
                value: overview!.netIncomeCents.abs() / 100,
                color: overview!.netIncomeCents >= 0
                    ? AppleDashboardPalette.success
                    : AppleDashboardPalette.warning,
                valueLabel: _currency(overview!.netIncomeCents),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ApplePill(
                label: '实际时薪 ${_hourlyRate(summary?.actualHourlyRateCents)}',
                backgroundColor: const Color(0xFFF3F6FF),
                foregroundColor: AppleDashboardPalette.primary,
              ),
              ApplePill(
                label:
                    '自由度 ${summary?.freedomCents == null ? "暂无数据" : _currency(summary!.freedomCents!)}',
                backgroundColor: const Color(0xFFF4FBF7),
                foregroundColor: AppleDashboardPalette.success,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayTimeStructureCard extends StatelessWidget {
  const _TodayTimeStructureCard({
    required this.overview,
  });

  final TodayOverview? overview;

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return const AppleDashboardSection(
        title: '今日时间结构',
        child: SectionMessageView(
          icon: Icons.stacked_bar_chart_rounded,
          title: '时间结构暂不可用',
          description: '当前没有可展示的时间结构数据。',
        ),
      );
    }

    final work = overview!.totalWorkMinutes;
    final learning = overview!.totalLearningMinutes;
    final other =
        (overview!.totalTimeMinutes - work - learning).clamp(0, 1 << 30);
    final total = (work + learning + other).clamp(1, 1 << 30);

    return AppleDashboardSection(
      title: '今日时间结构',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 18,
              child: Row(
                children: [
                  if (work > 0)
                    Expanded(
                      flex: work,
                      child: Container(color: AppleDashboardPalette.primary),
                    ),
                  if (learning > 0)
                    Expanded(
                      flex: learning,
                      child: Container(color: AppleDashboardPalette.warning),
                    ),
                  if (other > 0)
                    Expanded(
                      flex: other,
                      child: Container(color: const Color(0xFF39C2BD)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _LegendRow(
            label: '工作',
            color: AppleDashboardPalette.primary,
            value:
                '${_hours(work)} · ${(work / total * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 12),
          _LegendRow(
            label: '学习',
            color: AppleDashboardPalette.warning,
            value:
                '${_hours(learning)} · ${(learning / total * 100).toStringAsFixed(1)}%',
          ),
          const SizedBox(height: 12),
          _LegendRow(
            label: '其他',
            color: const Color(0xFF39C2BD),
            value:
                '${_hours(other)} · ${(other / total * 100).toStringAsFixed(1)}%',
          ),
        ],
      ),
    );
  }
}

class _TodayGoalProgressCard extends StatelessWidget {
  const _TodayGoalProgressCard({
    required this.goalProgress,
  });

  final TodayGoalProgressModel? goalProgress;

  @override
  Widget build(BuildContext context) {
    if (goalProgress == null) {
      return const AppleDashboardSection(
        title: '今日目标进度',
        child: SectionMessageView(
          icon: Icons.flag_circle_rounded,
          title: '目标进度暂不可用',
          description: '当前没有可展示的目标数据。',
        ),
      );
    }

    return AppleDashboardSection(
      title: '今日目标进度',
      child: Column(
        children: [
          for (var index = 0; index < goalProgress!.items.length; index++) ...[
            if (index > 0) const SizedBox(height: 18),
            _GoalProgressRow(item: goalProgress!.items[index]),
          ],
        ],
      ),
    );
  }
}

class _TodayHealthCard extends StatelessWidget {
  const _TodayHealthCard({
    required this.overview,
    required this.summary,
    required this.snapshot,
  });

  final TodayOverview? overview;
  final TodaySummaryModel? summary;
  final MetricSnapshotSummaryModel? snapshot;

  @override
  Widget build(BuildContext context) {
    if (overview == null) {
      return const AppleDashboardSection(
        title: '经营健康度',
        child: SectionMessageView(
          icon: Icons.favorite_outline_rounded,
          title: '健康度暂不可用',
          description: '当前没有可展示的经营快照。',
        ),
      );
    }

    final chartBars = [
      _BarDatum(
        label: '产出收入',
        value: overview!.totalIncomeCents / 100,
        color: AppleDashboardPalette.primary,
        valueLabel: _currency(overview!.totalIncomeCents),
      ),
      _BarDatum(
        label: '成本',
        value: overview!.totalExpenseCents / 100,
        color: AppleDashboardPalette.success,
        valueLabel: _currency(overview!.totalExpenseCents),
      ),
    ];

    return AppleDashboardSection(
      title: '经营健康度',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final chart = SizedBox(
            height: 210,
            child: _VerticalBarChart(
              bars: chartBars,
              showGrid: true,
            ),
          );
          final badges = Column(
            children: [
              _HealthBadge(
                icon: Icons.trending_up_rounded,
                iconColor: AppleDashboardPalette.success,
                label: '现金结余',
                value: _currency(overview!.netIncomeCents),
                note: overview!.netIncomeCents >= 0 ? '现金流状态稳定' : '需要关注现金支出',
              ),
              const SizedBox(height: 12),
              _HealthBadge(
                icon: Icons.timelapse_rounded,
                iconColor: AppleDashboardPalette.warning,
                label: '实际时薪',
                value: _hourlyRate(summary?.actualHourlyRateCents),
                note: '理想 ${_hourlyRate(summary?.idealHourlyRateCents)}',
              ),
              const SizedBox(height: 12),
              _HealthBadge(
                icon: Icons.shield_rounded,
                iconColor: AppleDashboardPalette.primary,
                label: '被动覆盖率',
                value: _ratioFromBps(summary?.passiveCoverRatioBps),
                note: snapshot?.freedomCents == null
                    ? '覆盖必要支出'
                    : '自由度 ${_currency(snapshot!.freedomCents!)}',
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                chart,
                const SizedBox(height: 18),
                badges,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: chart),
              const SizedBox(width: 18),
              Expanded(child: badges),
            ],
          );
        },
      ),
    );
  }
}

class _TodayAlertsCard extends StatelessWidget {
  const _TodayAlertsCard({
    required this.alerts,
  });

  final TodayAlertsModel? alerts;

  @override
  Widget build(BuildContext context) {
    if (alerts == null) {
      return const AppleDashboardSection(
        title: '今日提醒',
        child: SectionMessageView(
          icon: Icons.notifications_none_rounded,
          title: '提醒暂不可用',
          description: '当前没有读取到提醒列表。',
        ),
      );
    }

    if (alerts!.items.isEmpty) {
      return AppleDashboardSection(
        title: '今日提醒',
        child: AppleListRow(
          leading: const AppleIconCircle(
            icon: Icons.check_rounded,
            color: AppleDashboardPalette.success,
          ),
          title: '今天没有经营提醒',
          subtitle: '当前没有触发异常或缺失项提醒。',
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: AppleDashboardPalette.secondaryText,
          ),
        ),
      );
    }

    return AppleDashboardSection(
      title: '今日提醒',
      child: Column(
        children: [
          for (var index = 0; index < alerts!.items.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, color: AppleDashboardPalette.border),
            AppleListRow(
              leading: AppleIconCircle(
                icon: _alertIcon(alerts!.items[index].severity),
                color: _alertColor(alerts!.items[index].severity),
              ),
              title: alerts!.items[index].title,
              subtitle: alerts!.items[index].message,
              trailing: const Icon(
                Icons.chevron_right_rounded,
                color: AppleDashboardPalette.secondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayRecentRecordsCard extends StatelessWidget {
  const _TodayRecentRecordsCard({
    required this.records,
    required this.message,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onViewAll,
  });

  final List<RecentRecordItem>? records;
  final String? message;
  final ValueChanged<RecentRecordItem> onEdit;
  final ValueChanged<RecentRecordItem> onCopy;
  final ValueChanged<RecentRecordItem> onDelete;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    if (records == null) {
      return AppleDashboardSection(
        title: '最近记录',
        child: SectionMessageView(
          icon: Icons.receipt_long_rounded,
          title: '记录列表暂不可用',
          description: message ?? '等待最近记录返回结果。',
        ),
      );
    }

    if (records!.isEmpty) {
      return const AppleDashboardSection(
        title: '最近记录',
        child: SectionMessageView(
          icon: Icons.inbox_outlined,
          title: '今天还没有记录',
          description: '可以从记录页新增时间、收入、支出或学习记录。',
        ),
      );
    }

    final items = records!.take(4).toList();
    return AppleDashboardSection(
      title: '最近记录',
      trailing: TextButton(
        onPressed: onViewAll,
        child: const Text('查看全部'),
      ),
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            if (index > 0)
              const Divider(height: 1, color: AppleDashboardPalette.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AppleIconCircle(
                    icon: _recordIcon(items[index].kind),
                    color: _recordColor(items[index].kind),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[index].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: AppleDashboardPalette.text,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${items[index].kind.label} · ${items[index].detail}',
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        items[index].occurredAt,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppleDashboardPalette.secondaryText,
                            ),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(
                          Icons.more_horiz_rounded,
                          color: AppleDashboardPalette.secondaryText,
                        ),
                        onSelected: (value) {
                          if (value == 'edit') {
                            onEdit(items[index]);
                          } else if (value == 'copy') {
                            onCopy(items[index]);
                          } else if (value == 'delete') {
                            onDelete(items[index]);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(value: 'edit', child: Text('编辑')),
                          PopupMenuItem(value: 'copy', child: Text('复制一条')),
                          PopupMenuItem(value: 'delete', child: Text('删除')),
                        ],
                      ),
                    ],
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

class _SummaryMetric {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.caption,
  });

  final String label;
  final String value;
  final String caption;
}

class _SummaryMetricTile extends StatelessWidget {
  const _SummaryMetricTile({
    required this.metric,
  });

  final _SummaryMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppleDashboardPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            metric.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            metric.value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppleDashboardPalette.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            metric.caption,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppleDashboardPalette.secondaryText,
                ),
          ),
        ],
      ),
    );
  }
}

class _KpiItem {
  const _KpiItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.value,
    required this.caption,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String value;
  final String caption;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.item,
  });

  final _KpiItem item;

  @override
  Widget build(BuildContext context) {
    return AppleDashboardCard(
      child: Row(
        children: [
          AppleIconCircle(icon: item.icon, color: item.color, size: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppleDashboardPalette.secondaryText,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppleDashboardPalette.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.caption,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppleDashboardPalette.secondaryText,
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

class _BarDatum {
  const _BarDatum({
    required this.label,
    required this.value,
    required this.color,
    required this.valueLabel,
  });

  final String label;
  final double value;
  final Color color;
  final String valueLabel;
}

class _VerticalBarChart extends StatelessWidget {
  const _VerticalBarChart({
    required this.bars,
    this.showGrid = true,
  });

  final List<_BarDatum> bars;
  final bool showGrid;

  @override
  Widget build(BuildContext context) {
    final max = bars.fold<double>(1, (current, item) {
      return item.value > current ? item.value : current;
    });

    return SizedBox(
      height: 230,
      child: Stack(
        children: [
          if (showGrid)
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  4,
                  (_) => const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFEFF2F8),
                  ),
                ),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var index = 0; index < bars.length; index++) ...[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        bars[index].valueLabel,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppleDashboardPalette.text,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 34,
                        height: 144 * (bars[index].value / max).clamp(0.0, 1.0),
                        decoration: BoxDecoration(
                          color: bars[index].color,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        bars[index].label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppleDashboardPalette.secondaryText,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                if (index < bars.length - 1) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
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

class _GoalProgressRow extends StatelessWidget {
  const _GoalProgressRow({
    required this.item,
  });

  final TodayGoalProgressItemModel item;

  @override
  Widget build(BuildContext context) {
    final progress = (item.progressRatioBps / 10000).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                item.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppleDashboardPalette.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '${item.completedValue} / ${item.targetValue} ${item.unit}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppleDashboardPalette.secondaryText,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AppleProgressBar(value: progress, height: 11),
        const SizedBox(height: 8),
        Text(
          _goalStatus(item.status),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppleDashboardPalette.secondaryText,
              ),
        ),
      ],
    );
  }
}

class _HealthBadge extends StatelessWidget {
  const _HealthBadge({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.note,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppleDashboardPalette.border),
      ),
      child: Row(
        children: [
          AppleIconCircle(icon: icon, color: iconColor, size: 38),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppleDashboardPalette.secondaryText,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppleDashboardPalette.text,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              note,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppleDashboardPalette.secondaryText,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayPillStyle {
  const _TodayPillStyle({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
}

List<_TodayPillStyle> _buildTodayPills(TodaySummaryModel summary) {
  return [
    _TodayPillStyle(
      label: _financeLabel(summary.financeStatus),
      backgroundColor: _toneBackground(summary.financeStatus),
      foregroundColor: _toneForeground(summary.financeStatus),
    ),
    _TodayPillStyle(
      label: _workLabel(summary.workStatus),
      backgroundColor: _toneBackground(summary.workStatus),
      foregroundColor: _toneForeground(summary.workStatus),
    ),
    _TodayPillStyle(
      label: _learningLabel(summary.learningStatus),
      backgroundColor: _toneBackground(summary.learningStatus),
      foregroundColor: _toneForeground(summary.learningStatus),
    ),
    _TodayPillStyle(
      label: summary.shouldReview ? '建议复盘' : '状态稳定',
      backgroundColor: summary.shouldReview
          ? const Color(0xFFFFF4E8)
          : const Color(0xFFF4FBF7),
      foregroundColor: summary.shouldReview
          ? AppleDashboardPalette.warning
          : AppleDashboardPalette.success,
    ),
  ];
}

String _formatDateLabel(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) {
    return value;
  }
  return '${date.month}月${date.day}日';
}

String _currency(int cents) => '¥${(cents / 100).toStringAsFixed(2)}';

String _hours(int minutes) => '${(minutes / 60).toStringAsFixed(1)}h';

String _hourlyRate(int? cents) =>
    cents == null ? '暂无数据' : '¥${(cents / 100).toStringAsFixed(2)}';

String _ratioFromBps(int? bps) =>
    bps == null ? '暂无数据' : '${(bps / 100).toStringAsFixed(1)}%';

String _goalStatus(String status) {
  switch (status) {
    case 'done':
      return '已达标';
    case 'missing':
      return '尚未开始';
    case 'in_progress':
      return '进行中';
    default:
      return '未设置';
  }
}

String _financeLabel(String status) {
  switch (status) {
    case 'positive':
      return '收入稳定';
    case 'negative':
      return '现金承压';
    default:
      return '现金持平';
  }
}

String _workLabel(String status) {
  switch (status) {
    case 'on_track':
      return '工作在线';
    case 'behind':
      return '工作不足';
    case 'missing':
      return '缺少工作记录';
    default:
      return '工作待观察';
  }
}

String _learningLabel(String status) {
  switch (status) {
    case 'on_track':
      return '学习在线';
    case 'behind':
      return '学习不足';
    case 'missing':
      return '缺少学习记录';
    default:
      return '学习待观察';
  }
}

Color _toneBackground(String status) {
  switch (status) {
    case 'positive':
    case 'on_track':
    case 'done':
      return const Color(0xFFF4FBF7);
    case 'negative':
    case 'critical':
    case 'missing':
      return const Color(0xFFFFF1F1);
    case 'behind':
    case 'warning':
      return const Color(0xFFFFF4E8);
    default:
      return const Color(0xFFF2F5FB);
  }
}

Color _toneForeground(String status) {
  switch (status) {
    case 'positive':
    case 'on_track':
    case 'done':
      return AppleDashboardPalette.success;
    case 'negative':
    case 'critical':
    case 'missing':
      return AppleDashboardPalette.danger;
    case 'behind':
    case 'warning':
      return AppleDashboardPalette.warning;
    default:
      return AppleDashboardPalette.secondaryText;
  }
}

IconData _alertIcon(String severity) {
  switch (severity) {
    case 'critical':
      return Icons.error_outline_rounded;
    case 'warning':
      return Icons.warning_amber_rounded;
    default:
      return Icons.info_outline_rounded;
  }
}

Color _alertColor(String severity) {
  switch (severity) {
    case 'critical':
      return AppleDashboardPalette.danger;
    case 'warning':
      return AppleDashboardPalette.warning;
    default:
      return AppleDashboardPalette.primary;
  }
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
