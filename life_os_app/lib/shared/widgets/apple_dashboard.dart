import 'package:flutter/material.dart';

class AppleDashboardPalette {
  static const background = Color(0xFFF4F6FA);
  static const surface = Colors.white;
  static const border = Color(0xFFE6EBF2);
  static const shadow = Color(0x120F172A);
  static const primary = Color(0xFF2F6BFF);
  static const text = Color(0xFF182033);
  static const secondaryText = Color(0xFF6F7B91);
  static const success = Color(0xFF31B36B);
  static const warning = Color(0xFFFF9B3F);
  static const danger = Color(0xFFFF5D5D);
  static const track = Color(0xFFF0F3F8);
}

class AppleDashboardPage extends StatelessWidget {
  const AppleDashboardPage({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.controls,
    this.exportBoundaryKey,
    required this.children,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget? controls;
  final GlobalKey? exportBoundaryKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppleDashboardPalette.background,
      ),
      child: Stack(
        children: [
          const Positioned(
            top: -100,
            right: -40,
            child: _BackdropGlow(
              size: 260,
              colors: [Color(0x1A6D9CFF), Color(0x006D9CFF)],
            ),
          ),
          const Positioned(
            left: -60,
            top: 240,
            child: _BackdropGlow(
              size: 220,
              colors: [Color(0x0E8BE3C2), Color(0x008BE3C2)],
            ),
          ),
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
              child: Center(
                child: RepaintBoundary(
                  key: exportBoundaryKey,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: AppleDashboardPalette.background,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineMedium
                                          ?.copyWith(
                                            color: AppleDashboardPalette.text,
                                            fontSize: 34,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.2,
                                          ),
                                    ),
                                    if (subtitle != null) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        subtitle!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppleDashboardPalette
                                                  .secondaryText,
                                              fontSize: 15,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (trailing != null) ...[
                                const SizedBox(width: 16),
                                trailing!,
                              ],
                            ],
                          ),
                          if (controls != null) ...[
                            const SizedBox(height: 18),
                            controls!,
                          ],
                          const SizedBox(height: 20),
                          ..._withSpacing(children),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _withSpacing(List<Widget> items) {
    return [
      for (var index = 0; index < items.length; index++) ...[
        if (index > 0) const SizedBox(height: 20),
        items[index],
      ],
    ];
  }
}

class AppleDashboardCard extends StatelessWidget {
  const AppleDashboardCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppleDashboardPalette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppleDashboardPalette.border),
        boxShadow: const [
          BoxShadow(
            color: AppleDashboardPalette.shadow,
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class AppleDashboardSection extends StatelessWidget {
  const AppleDashboardSection({
    super.key,
    required this.title,
    this.trailing,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });

  final String title;
  final Widget? trailing;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return AppleDashboardCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppleDashboardPalette.text,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppleDashboardPalette.secondaryText,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class AppleSegmentOption<T> {
  const AppleSegmentOption({
    required this.value,
    required this.label,
  });

  final T value;
  final String label;
}

class AppleSegmentedControl<T> extends StatelessWidget {
  const AppleSegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final List<AppleSegmentOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppleDashboardPalette.border),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _AppleSegmentItem<T>(
                  option: option,
                  selected: option.value == value,
                  onTap: onChanged,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ApplePill extends StatelessWidget {
  const ApplePill({
    super.key,
    required this.label,
    this.backgroundColor = const Color(0xFFF2F5FB),
    this.foregroundColor = AppleDashboardPalette.secondaryText,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class AppleIconCircle extends StatelessWidget {
  const AppleIconCircle({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.14),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

class AppleProgressBar extends StatelessWidget {
  const AppleProgressBar({
    super.key,
    required this.value,
    this.color = AppleDashboardPalette.primary,
    this.height = 10,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: height,
        backgroundColor: AppleDashboardPalette.track,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }
}

class AppleListRow extends StatelessWidget {
  const AppleListRow({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppleDashboardPalette.text,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppleDashboardPalette.secondaryText,
                      ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: row,
    );
  }
}

class AppleCircleButton extends StatelessWidget {
  const AppleCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onPressed,
        child: Ink(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color:
                enabled ? Colors.white : Colors.white.withValues(alpha: 0.72),
            shape: BoxShape.circle,
            border: Border.all(color: AppleDashboardPalette.border),
            boxShadow: const [
              BoxShadow(
                color: AppleDashboardPalette.shadow,
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: enabled
                ? AppleDashboardPalette.text
                : AppleDashboardPalette.secondaryText,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _AppleSegmentItem<T> extends StatelessWidget {
  const _AppleSegmentItem({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppleSegmentOption<T> option;
  final bool selected;
  final ValueChanged<T> onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onTap(option.value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: selected
                ? const LinearGradient(
                    colors: [Color(0xFF5D8DFF), AppleDashboardPalette.primary],
                  )
                : null,
            color: selected ? null : Colors.transparent,
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x1E2F6BFF),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Text(
            option.label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : AppleDashboardPalette.secondaryText,
                ),
          ),
        ),
      ),
    );
  }
}

class _BackdropGlow extends StatelessWidget {
  const _BackdropGlow({
    required this.size,
    required this.colors,
  });

  final double size;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: colors),
        ),
      ),
    );
  }
}
