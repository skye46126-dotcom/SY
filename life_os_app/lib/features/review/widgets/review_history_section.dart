import 'package:flutter/material.dart';

import '../../../models/record_models.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/state_views.dart';

class ReviewHistorySection extends StatelessWidget {
  const ReviewHistorySection({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<RecentRecordItem> items;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: 'History',
      title: title,
      child: items.isEmpty
          ? const SectionMessageView(
              icon: Icons.history_rounded,
              title: '暂无历史数据',
              description: '当前筛选条件下没有可展示的历史记录。',
            )
          : Column(
              children: [
                for (final item in items.take(12))
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.42),
                      borderRadius: BorderRadius.circular(18),
                      border:
                          Border.all(color: Colors.white.withValues(alpha: 0.56)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(
                              item.occurredAt,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.detail,
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
