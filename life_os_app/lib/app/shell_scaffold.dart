import 'package:flutter/material.dart';

import '../features/capture/capture_page.dart';
import '../features/management/management_page.dart';
import '../features/review/review_page.dart';
import '../features/today/today_page.dart';
import 'router.dart';

class ShellScaffold extends StatefulWidget {
  const ShellScaffold({
    super.key,
    required this.destination,
    required this.child,
  });

  final AppDestination destination;
  final Widget child;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  late AppDestination _destination;

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
  }

  @override
  void didUpdateWidget(covariant ShellScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.destination != widget.destination) {
      _destination = widget.destination;
    }
  }

  void _openDestination(AppDestination next) {
    if (next == _destination) {
      return;
    }
    setState(() => _destination = next);
  }

  Widget _buildCurrentPage() {
    if (_destination == widget.destination) {
      return widget.child;
    }
    switch (_destination) {
      case AppDestination.today:
        return const TodayPage();
      case AppDestination.capture:
        return const CapturePage();
      case AppDestination.management:
        return const ManagementPage();
      case AppDestination.review:
        return const ReviewPage();
    }
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
                  selectedIndex: _destination.index,
                  labelType: NavigationRailLabelType.all,
                  onDestinationSelected: (index) {
                    _openDestination(destinations[index]);
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
            Expanded(child: _buildCurrentPage()),
          ],
        ),
      ),
      bottomNavigationBar: isCompact
          ? NavigationBar(
              selectedIndex: _destination.index,
              onDestinationSelected: (index) {
                _openDestination(destinations[index]);
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
