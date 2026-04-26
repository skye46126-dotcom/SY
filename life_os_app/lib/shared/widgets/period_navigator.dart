import 'package:flutter/material.dart';

class PeriodNavigator extends StatelessWidget {
  const PeriodNavigator({
    super.key,
    required this.currentLabel,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
    this.todayLabel = '今天',
  });

  final String currentLabel;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;
  final String todayLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
      ),
      child: Row(
        children: [
          _NavigatorAction(
            label: '上一周期',
            icon: Icons.chevron_left_rounded,
            alignment: Alignment.centerLeft,
            onTap: onPrevious,
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  currentLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 16),
                ),
                TextButton(
                  onPressed: onToday,
                  style: TextButton.styleFrom(
                    foregroundColor: theme.textTheme.bodyMedium?.color,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(todayLabel),
                ),
              ],
            ),
          ),
          _NavigatorAction(
            label: '下一周期',
            icon: Icons.chevron_right_rounded,
            alignment: Alignment.centerRight,
            iconAtEnd: true,
            onTap: onNext,
          ),
        ],
      ),
    );
  }
}

class _NavigatorAction extends StatelessWidget {
  const _NavigatorAction({
    required this.label,
    required this.icon,
    required this.alignment,
    required this.onTap,
    this.iconAtEnd = false,
  });

  final String label;
  final IconData icon;
  final Alignment alignment;
  final VoidCallback onTap;
  final bool iconAtEnd;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final content = [
      if (!iconAtEnd) Icon(icon, size: 18),
      Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      if (iconAtEnd) Icon(icon, size: 18),
    ];

    return Expanded(
      child: Align(
        alignment: alignment,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: textColor,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            minimumSize: const Size(0, 40),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < content.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                content[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
