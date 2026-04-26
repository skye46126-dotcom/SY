import 'package:flutter/material.dart';

import '../../../shared/widgets/section_card.dart';

class ManagementGroupCard extends StatelessWidget {
  const ManagementGroupCard({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.items,
  });

  final String title;
  final String eyebrow;
  final List<ManagementEntry> items;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: eyebrow,
      title: title,
      child: Column(
        children: [
          for (final item in items) ...[
            _ManagementItem(
              title: item.title,
              description: item.description,
              onTap: item.onTap,
            ),
            if (item != items.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _ManagementItem extends StatelessWidget {
  const _ManagementItem({
    required this.title,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
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
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(description, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ManagementEntry {
  const ManagementEntry({
    required this.title,
    required this.description,
    this.onTap,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;
}
