import 'package:flutter/material.dart';

import '../../app/theme.dart';

class ModulePage extends StatelessWidget {
  const ModulePage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.actions = const [],
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x336A9CFF), Colors.transparent],
              ),
            ),
          ),
        ),
        Positioned(
          left: -30,
          bottom: 60,
          child: Container(
            width: 180,
            height: 180,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x26FFC891), Colors.transparent],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: AppTheme.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subtitle, style: textTheme.labelSmall),
                        const SizedBox(height: 8),
                        Text(title, style: textTheme.headlineMedium),
                      ],
                    ),
                    ...actions,
                  ],
                ),
                const SizedBox(height: 24),
                ..._withSpacing(children),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _withSpacing(List<Widget> items) {
    return [
      for (var index = 0; index < items.length; index++) ...[
        if (index > 0) const SizedBox(height: AppTheme.sectionGap),
        items[index],
      ],
    ];
  }
}
