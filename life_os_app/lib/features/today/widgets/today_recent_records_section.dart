import 'package:flutter/material.dart';

import '../../../models/record_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class TodayRecentRecordsSection extends StatelessWidget {
  const TodayRecentRecordsSection({
    super.key,
    required this.records,
    required this.message,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
  });

  final List<RecentRecordItem>? records;
  final String? message;
  final ValueChanged<RecentRecordItem> onEdit;
  final ValueChanged<RecentRecordItem> onCopy;
  final ValueChanged<RecentRecordItem> onDelete;

  @override
  Widget build(BuildContext context) {
    if (records == null) {
      return SectionCard(
        eyebrow: 'Recent Records',
        title: '最近记录',
        child: SectionMessageView(
          icon: Icons.receipt_long_rounded,
          title: '记录列表已就位',
          description: message ?? '等待 getRecentRecords 返回结果。',
        ),
      );
    }

    if (records!.isEmpty) {
      return const SectionCard(
        eyebrow: 'Recent Records',
        title: '最近记录',
        child: SectionMessageView(
          icon: Icons.inbox_outlined,
          title: '今天还没有记录',
          description: '可以从 Capture 页面新增时间、收入、支出或学习记录。',
        ),
      );
    }

    return SectionCard(
      eyebrow: 'Recent Records',
      title: '最近记录',
      child: Column(
        children: [
          for (final record in records!) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.42),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Chip(label: Text(record.kind.label)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(record.title, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 4),
                        Text(record.detail, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit(record);
                        case 'copy':
                          onCopy(record);
                        case 'delete':
                          onDelete(record);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('编辑')),
                      PopupMenuItem(value: 'copy', child: Text('复制一条')),
                      PopupMenuItem(value: 'delete', child: Text('删除')),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        record.occurredAt,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
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
