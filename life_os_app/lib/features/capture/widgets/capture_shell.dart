import 'package:flutter/material.dart';

import '../../../shared/view_state.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/segmented_control.dart';
import '../capture_controller.dart';

enum CaptureWorkspaceTab {
  compose,
  review,
  cache,
}

class CaptureShell extends StatelessWidget {
  const CaptureShell({
    super.key,
    required this.selectedType,
    required this.aiState,
    required this.activeTab,
    required this.onTabChanged,
    required this.composeChild,
    required this.reviewChild,
    required this.cacheChild,
    required this.quickCaptureBufferCount,
  });

  final CaptureType selectedType;
  final ViewState<Map<String, Object?>> aiState;
  final CaptureWorkspaceTab activeTab;
  final ValueChanged<CaptureWorkspaceTab> onTabChanged;
  final Widget composeChild;
  final Widget reviewChild;
  final Widget cacheChild;
  final int quickCaptureBufferCount;

  @override
  Widget build(BuildContext context) {
    final stats = CaptureReviewStats.fromState(aiState);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          eyebrow: 'Workspace',
          title: switch (activeTab) {
            CaptureWorkspaceTab.compose => '录入工作台',
            CaptureWorkspaceTab.review => '审核中心',
            CaptureWorkspaceTab.cache => '缓存池',
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedControl<CaptureWorkspaceTab>(
                value: activeTab,
                onChanged: onTabChanged,
                options: [
                  const SegmentedControlOption(
                    value: CaptureWorkspaceTab.compose,
                    label: '录入',
                  ),
                  SegmentedControlOption(
                    value: CaptureWorkspaceTab.review,
                    label: stats.reviewTabLabel,
                  ),
                  SegmentedControlOption(
                    value: CaptureWorkspaceTab.cache,
                    label: quickCaptureBufferCount > 0
                        ? '缓存 $quickCaptureBufferCount'
                        : '缓存',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    label: '当前类型 ${selectedType.label}',
                    color: const Color(0xFF2563EB),
                  ),
                  if (stats.isParsing)
                    const _InfoPill(
                      label: 'AI 正在解析',
                      color: Color(0xFF7C3AED),
                    ),
                  if (stats.readyCount > 0)
                    _InfoPill(
                      label: '可入库 ${stats.readyCount}',
                      color: const Color(0xFF059669),
                    ),
                  if (stats.needsReviewCount > 0)
                    _InfoPill(
                      label: '需确认 ${stats.needsReviewCount}',
                      color: const Color(0xFFD97706),
                    ),
                  if (stats.blockedCount > 0)
                    _InfoPill(
                      label: '阻塞 ${stats.blockedCount}',
                      color: const Color(0xFFDC2626),
                    ),
                  if (stats.noteCount > 0)
                    _InfoPill(
                      label: '复盘素材 ${stats.noteCount}',
                      color: const Color(0xFF64748B),
                    ),
                  if (quickCaptureBufferCount > 0)
                    _InfoPill(
                      label: '缓存池 $quickCaptureBufferCount',
                      color: const Color(0xFF0F766E),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                switch (activeTab) {
                  CaptureWorkspaceTab.compose =>
                    '先完成手动录入或输入原始记录；触发 AI 后进入审核区处理草稿。',
                  CaptureWorkspaceTab.review =>
                    '审核区默认展示摘要，只有需要修正时再进入字段编辑，避免长表单直接铺开。',
                  CaptureWorkspaceTab.cache => '缓存池适合连续收纳碎片输入，凑够后一次整理进入审核区。',
                },
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: KeyedSubtree(
            key: ValueKey(activeTab),
            child: switch (activeTab) {
              CaptureWorkspaceTab.compose => composeChild,
              CaptureWorkspaceTab.review => reviewChild,
              CaptureWorkspaceTab.cache => cacheChild,
            },
          ),
        ),
      ],
    );
  }
}

class CaptureReviewStats {
  const CaptureReviewStats({
    required this.isParsing,
    required this.readyCount,
    required this.needsReviewCount,
    required this.blockedCount,
    required this.noteCount,
  });

  final bool isParsing;
  final int readyCount;
  final int needsReviewCount;
  final int blockedCount;
  final int noteCount;

  String get reviewTabLabel {
    final pending = needsReviewCount + blockedCount;
    if (pending > 0) {
      return '审核 $pending';
    }
    if (readyCount > 0) {
      return '审核 $readyCount';
    }
    return '审核';
  }

  factory CaptureReviewStats.fromState(ViewState<Map<String, Object?>> state) {
    if (state.status != ViewStatus.data || state.data == null) {
      return CaptureReviewStats(
        isParsing: state.status == ViewStatus.loading,
        readyCount: 0,
        needsReviewCount: 0,
        blockedCount: 0,
        noteCount: 0,
      );
    }
    final envelope = state.data!;
    final items = ((envelope['items'] as List?) ?? const [])
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>());
    var ready = 0;
    var needsReview = 0;
    var blocked = 0;
    for (final item in items) {
      final kind = item['kind']?.toString();
      if (!{
        'time_record',
        'income_record',
        'expense_record',
      }.contains(kind)) {
        continue;
      }
      final validation =
          ((item['validation'] as Map?) ?? const {}).cast<String, Object?>();
      final status = validation['status']?.toString();
      if (status == 'commit_ready') {
        ready += 1;
      } else if (status == 'needs_review') {
        needsReview += 1;
      } else if (status == 'blocked') {
        blocked += 1;
      }
    }
    final notes = ((envelope['review_notes'] as List?) ?? const [])
        .whereType<Map>()
        .where(
          (item) => (item['visibility']?.toString() ?? 'compact') != 'hidden',
        )
        .length;
    return CaptureReviewStats(
      isParsing: false,
      readyCount: ready,
      needsReviewCount: needsReview,
      blockedCount: blocked,
      noteCount: notes,
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
