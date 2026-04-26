import 'package:flutter/material.dart';

import '../../app/theme.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.sectionRadius),
      child: BackdropFilter(
        filter: AppTheme.glassBlur(),
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: padding,
            decoration: AppTheme.glassDecoration(),
            child: child,
          ),
        ),
      ),
    );
  }
}
