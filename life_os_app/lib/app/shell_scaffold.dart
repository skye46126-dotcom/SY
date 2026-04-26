import 'package:flutter/material.dart';

import 'router.dart';

class ShellScaffold extends StatelessWidget {
  const ShellScaffold({
    super.key,
    required this.destination,
    required this.child,
  });

  final AppDestination destination;
  final Widget child;

  void _openDestination(BuildContext context, AppDestination next) {
    if (next == destination) {
      return;
    }
    Navigator.of(context).pushReplacementNamed(next.route);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 860;
    final destinations = AppDestination.values;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!isCompact)
              Padding(
                padding: const EdgeInsets.all(16),
                child: NavigationRail(
                  backgroundColor: Colors.white.withValues(alpha: 0.44),
                  selectedIndex: destination.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) {
                    _openDestination(context, destinations[index]);
                  },
                  destinations: [
                    for (final item in destinations)
                      NavigationRailDestination(
                        icon: Icon(item.icon),
                        label: Text(item.label),
                      ),
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: destination.index,
              onDestinationSelected: (index) {
                _openDestination(context, destinations[index]);
              },
              destinations: [
                for (final item in destinations)
                  NavigationDestination(
                    icon: Icon(item.icon),
                    label: item.label,
                  ),
              ],
            )
          : null,
    );
  }
}
