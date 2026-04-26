import 'package:flutter/material.dart';

import '../../../shared/widgets/section_card.dart';

class ManagementListGroup extends StatelessWidget {
  const ManagementListGroup({
    super.key,
    required this.title,
    required this.eyebrow,
    required this.items,
    this.muted = false,
  });

  final String title;
  final String eyebrow;
  final List<ManagementEntry> items;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      eyebrow: eyebrow,
      title: title,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: muted ? 0.2 : 0.3),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.58)),
        ),
        child: Column(
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _ManagementItem(
                title: items[index].title,
                description: items[index].description,
                onTap: items[index].onTap,
                muted: muted,
              ),
              if (index < items.length - 1)
                Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.54),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ManagementItem extends StatelessWidget {
  const _ManagementItem({
    required this.title,
    required this.description,
    required this.onTap,
    required this.muted,
  });

  final String title;
  final String description;
  final VoidCallback? onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final titleColor = Theme.of(context).textTheme.titleMedium?.color;
    final bodyColor = Theme.of(context).textTheme.bodyMedium?.color;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: muted
                                ? bodyColor?.withValues(alpha: 0.92)
                                : titleColor,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: muted
                                ? bodyColor?.withValues(alpha: 0.82)
                                : bodyColor,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Icon(
              Icons.chevron_right_rounded,
              color: (muted ? bodyColor : titleColor)?.withValues(alpha: 0.72),
            ),
          ],
        ),
      ),
    );
  }
}

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
    return ManagementListGroup(
      title: title,
      eyebrow: eyebrow,
      items: items,
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
