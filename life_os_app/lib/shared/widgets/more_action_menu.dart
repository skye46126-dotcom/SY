import 'package:flutter/material.dart';

class MoreActionMenuItem {
  const MoreActionMenuItem({
    required this.label,
    required this.icon,
    this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool enabled;
}

class MoreActionMenu extends StatelessWidget {
  const MoreActionMenu({
    super.key,
    required this.items,
    this.tooltip = '更多操作',
  });

  final List<MoreActionMenuItem> items;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openSheet(context),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
            ),
            child: const Icon(Icons.more_horiz_rounded),
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) {
    final rootContext = Navigator.of(context, rootNavigator: true).context;
    final availableItems =
        items.where((item) => item.enabled || item.onPressed != null).toList();
    return showModalBottomSheet<void>(
      context: rootContext,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF7F9FD),
      builder: (context) {
        final textTheme = Theme.of(context).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('更多操作', style: textTheme.titleLarge),
                  const SizedBox(height: 12),
                  for (final item in availableItems)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      enabled: item.enabled && item.onPressed != null,
                      leading: Icon(item.icon),
                      title: Text(item.label),
                      onTap: item.enabled && item.onPressed != null
                          ? () {
                              Navigator.of(context).pop();
                              item.onPressed!();
                            }
                          : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
