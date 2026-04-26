import 'package:flutter/material.dart';

import '../../app/app.dart';
import '../../models/project_models.dart';
import '../../models/record_models.dart';
import '../../models/tag_models.dart';
import '../../shared/view_state.dart';
import '../../shared/widgets/module_page.dart';
import '../../shared/widgets/state_views.dart';
import '../review/widgets/record_editor_dialog.dart';
import 'today_controller.dart';
import 'widgets/today_goal_progress_section.dart';
import 'widgets/today_alerts_section.dart';
import 'widgets/today_metrics_section.dart';
import 'widgets/today_recent_records_section.dart';
import 'widgets/today_snapshot_section.dart';
import 'widgets/today_status_hero.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  TodayController? _controller;
  bool _hasLoaded = false;

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

        return ModulePage(
          title: '今日经营状态',
          subtitle: 'Today',
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/settings'),
              child: const Text('设置'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pushNamed('/capture'),
              child: const Text('记录'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pushNamed('/review'),
              child: const Text('日复盘'),
            ),
          ],
          children: [
            if (state.status == ViewStatus.loading)
              const SectionLoadingView(label: '正在读取 Today 数据'),
            TodayStatusHero(
              overview: data?.overview,
              snapshot: data?.snapshot,
              summary: data?.summary,
              statusMessage: state.message,
              unavailableMessage:
                  state.status == ViewStatus.unavailable ? state.message : null,
            ),
            TodayMetricsSection(
              overview: data?.overview,
              summary: data?.summary,
              message: state.message,
            ),
            TodayGoalProgressSection(goalProgress: data?.goalProgress),
            TodayAlertsSection(alerts: data?.alerts),
            TodayRecentRecordsSection(
              records: data?.recentRecords,
              message: state.message,
              onEdit: _editRecord,
              onCopy: _copyRecord,
              onDelete: _deleteRecord,
            ),
            TodaySnapshotSection(snapshot: data?.snapshot),
          ],
        );
      },
    );
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
      context: context,
      builder: (context) {
        final typedProjectOptions = projectOptions.cast<ProjectOption>();
        final typedTags = tags.cast<TagModel>();
        switch (record.kind) {
          case RecordKind.time:
            return RecordEditorDialog.time(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              timeSnapshot: TimeRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.income:
            return RecordEditorDialog.income(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              incomeSnapshot: IncomeRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.expense:
            return RecordEditorDialog.expense(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              expenseSnapshot: ExpenseRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
              projectOptions: typedProjectOptions,
              tags: typedTags,
            );
          case RecordKind.learning:
            return RecordEditorDialog.learning(
              recordId: record.recordId,
              userId: runtime.userId,
              anchorDate: runtime.todayDate,
              learningSnapshot: LearningRecordSnapshotModel.fromJson(snapshot.cast<String, dynamic>()),
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
