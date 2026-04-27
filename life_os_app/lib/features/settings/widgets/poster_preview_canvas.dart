import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../models/poster_models.dart';

class PosterPreviewCanvas extends StatelessWidget {
  const PosterPreviewCanvas({
    super.key,
    required this.data,
  });

  final PosterExportData data;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _palette(data.themeKey).background,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _PosterBackdropPainter(
                  palette: _palette(data.themeKey),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(64, 56, 64, 56),
            child: switch (data.template) {
              PosterTemplateKind.poster => _PosterLayout(data: data),
              PosterTemplateKind.minimal => _MinimalLayout(data: data),
              PosterTemplateKind.magazine => _MagazineLayout(data: data),
            },
          ),
        ],
      ),
    );
  }
}

class _PosterLayout extends StatelessWidget {
  const _PosterLayout({
    required this.data,
  });

  final PosterExportData data;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(data.themeKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrandRow(data: data),
        const SizedBox(height: 34),
        Expanded(
          flex: 11,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(42),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: palette.hero,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -12,
                    right: -50,
                    child: _GlowOrb(
                      size: 260,
                      color: Colors.white.withValues(alpha: 0.20),
                    ),
                  ),
                  Positioned(
                    left: -30,
                    bottom: -10,
                    child: _GlowOrb(
                      size: 220,
                      color: palette.accent.withValues(alpha: 0.32),
                    ),
                  ),
                  Positioned(
                    right: 46,
                    bottom: 36,
                    child: _HeroCoverArtwork(asset: data.coverAsset),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(42, 38, 42, 38),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: data.policy.showStateScore
                                ? Text(
                                    '${data.stateScore}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 148,
                                      height: 0.88,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -8,
                                    ),
                                  )
                                : Text(
                                    data.stateLabel,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 72,
                                      height: 0.92,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -3.2,
                                    ),
                                  ),
                          ),
                        ),
                        if (data.policy.showStateScore)
                          Text(
                            data.stateLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            data.periodLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.84),
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        Expanded(
          flex: 13,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final metric in data.metrics)
                    _MetricTile(
                      metric: metric,
                      palette: palette,
                      width: 420,
                    ),
                ],
              ),
              const Spacer(),
              if (data.projectLabel != null) ...[
                Text(
                  'Main Focus',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.70),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data.projectLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.3,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                '“${data.summary}”',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  height: 1.42,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 20),
              if (data.keywords.isNotEmpty)
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in data.keywords)
                      _KeywordChip(
                        label: item,
                        dark: true,
                      ),
                  ],
                ),
              const Spacer(),
              _FooterLine(data: data),
            ],
          ),
        ),
      ],
    );
  }
}

class _MinimalLayout extends StatelessWidget {
  const _MinimalLayout({
    required this.data,
  });

  final PosterExportData data;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(data.themeKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrandRow(data: data, dark: true),
        const SizedBox(height: 40),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 7,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      color: Color(0xFF111827),
                      fontSize: 54,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -2.8,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    data.summary,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 24,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 30),
            Expanded(
              flex: 4,
              child: AspectRatio(
                aspectRatio: 0.78,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(38),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: palette.hero,
                      ),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          top: 20,
                          right: 20,
                          child: _HeroCoverArtwork(
                            asset: data.coverAsset,
                            compact: true,
                          ),
                        ),
                        Center(
                          child: Text(
                            data.policy.showStateScore
                                ? '${data.stateScore}'
                                : data.stateLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: data.policy.showStateScore ? 122 : 54,
                              fontWeight: FontWeight.w800,
                              letterSpacing:
                                  data.policy.showStateScore ? -6 : -2,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 24,
                          left: 24,
                          child: Text(
                            data.stateLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.88),
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 34),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: [
            for (final metric in data.metrics)
              _MetricTile(
                metric: metric,
                palette: palette,
                width: 290,
                dark: false,
              ),
          ],
        ),
        const Spacer(),
        if (data.projectLabel != null)
          Text(
            data.projectLabel!,
            style: const TextStyle(
              color: Color(0xFF111827),
              fontSize: 30,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.1,
            ),
          ),
        if (data.projectLabel != null) const SizedBox(height: 16),
        if (data.keywords.isNotEmpty)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final item in data.keywords)
                _KeywordChip(
                  label: item,
                  dark: false,
                ),
            ],
          ),
        const Spacer(),
        _FooterLine(data: data, dark: true),
      ],
    );
  }
}

class _MagazineLayout extends StatelessWidget {
  const _MagazineLayout({
    required this.data,
  });

  final PosterExportData data;

  @override
  Widget build(BuildContext context) {
    final palette = _palette(data.themeKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _BrandRow(data: data),
        const SizedBox(height: 30),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(34),
                      child: Container(
                        height: 430,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: palette.hero,
                          ),
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              left: 24,
                              top: 24,
                              child: Text(
                                data.periodLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Positioned.fill(
                              child: Align(
                                alignment: Alignment.center,
                                child:
                                    _HeroCoverArtwork(asset: data.coverAsset),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      data.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 62,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -2.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      data.summary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 28),
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.16),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            data.policy.showStateScore
                                ? '${data.stateScore}'
                                : data.stateLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 96,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            data.stateLabel,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 24),
                          for (final metric in data.metrics)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _MetricTile(
                                metric: metric,
                                palette: palette,
                                width: double.infinity,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (data.projectLabel != null)
                      Text(
                        data.projectLabel!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1.1,
                        ),
                      ),
                    if (data.projectLabel != null) const SizedBox(height: 16),
                    if (data.keywords.isNotEmpty)
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final item in data.keywords)
                            _KeywordChip(label: item, dark: true),
                        ],
                      ),
                    const Spacer(),
                    _FooterLine(data: data),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrandRow extends StatelessWidget {
  const _BrandRow({
    required this.data,
    this.dark = false,
  });

  final PosterExportData data;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textColor = dark ? const Color(0xFF111827) : Colors.white;
    final secondary =
        dark ? const Color(0xFF6B7280) : Colors.white.withValues(alpha: 0.74);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: dark
                ? const Color(0xFF111827)
                : Colors.white.withValues(alpha: 0.18),
            border: Border.all(
              color: dark
                  ? const Color(0xFFCBD5E1)
                  : Colors.white.withValues(alpha: 0.28),
            ),
          ),
          child: Icon(
            Icons.stacked_line_chart_rounded,
            color: dark ? Colors.white : Colors.white,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.brandLabel,
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${data.periodLabel} · ${data.dateLabel}',
              style: TextStyle(
                color: secondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.metric,
    required this.palette,
    required this.width,
    this.dark = true,
  });

  final PosterMetricData metric;
  final _PosterPalette palette;
  final double width;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? Colors.white.withValues(alpha: 0.10)
        : Colors.white.withValues(alpha: 0.68);
    final border =
        dark ? Colors.white.withValues(alpha: 0.14) : const Color(0xFFE5E7EB);
    final titleColor =
        dark ? Colors.white.withValues(alpha: 0.78) : const Color(0xFF6B7280);
    final valueColor = dark ? Colors.white : const Color(0xFF111827);
    final noteColor =
        dark ? Colors.white.withValues(alpha: 0.66) : const Color(0xFF4B5563);
    return Container(
      width: width,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: _toneColor(metric.tone, palette),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.label,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  metric.value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  metric.note,
                  style: TextStyle(
                    color: noteColor,
                    fontSize: 15,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _toneColor(String tone, _PosterPalette palette) {
    switch (tone) {
      case 'primary':
        return palette.accent;
      case 'secondary':
        return palette.support;
      case 'accent':
        return palette.hero.last;
      case 'positive':
        return const Color(0xFF31B36B);
      case 'warning':
        return const Color(0xFFFF9B3F);
      default:
        return Colors.white.withValues(alpha: 0.68);
    }
  }
}

class _FooterLine extends StatelessWidget {
  const _FooterLine({
    required this.data,
    this.dark = false,
  });

  final PosterExportData data;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final textColor =
        dark ? const Color(0xFF6B7280) : Colors.white.withValues(alpha: 0.72);
    return Row(
      children: [
        Text(
          'Generated by SkyeOS',
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        const Spacer(),
        Text(
          data.policy.mode.label,
          style: TextStyle(
            color: textColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _KeywordChip extends StatelessWidget {
  const _KeywordChip({
    required this.label,
    required this.dark,
  });

  final String label;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: dark
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.16)
              : const Color(0xFFE5E7EB),
        ),
      ),
      child: Text(
        '#$label',
        style: TextStyle(
          color: dark
              ? Colors.white.withValues(alpha: 0.88)
              : const Color(0xFF111827),
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _HeroCoverArtwork extends StatelessWidget {
  const _HeroCoverArtwork({
    required this.asset,
    this.compact = false,
  });

  final PosterCoverAsset asset;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 126.0 : 240.0;
    final height = compact ? 166.0 : 320.0;
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _CoverArtPainter(
          artKind: asset.artKind,
          compact: compact,
        ),
      ),
    );
  }
}

class _PosterPalette {
  const _PosterPalette({
    required this.background,
    required this.hero,
    required this.accent,
    required this.support,
  });

  final List<Color> background;
  final List<Color> hero;
  final Color accent;
  final Color support;
}

_PosterPalette _palette(String key) {
  switch (key) {
    case 'focus_blue':
      return const _PosterPalette(
        background: [Color(0xFF08111F), Color(0xFF17335F), Color(0xFF2759B6)],
        hero: [Color(0xFF5F89FF), Color(0xFF1D49C6)],
        accent: Color(0xFF9ED0FF),
        support: Color(0xFF87E5D8),
      );
    case 'growth_mint':
      return const _PosterPalette(
        background: [Color(0xFF0F1E1E), Color(0xFF1F5554), Color(0xFF62A99E)],
        hero: [Color(0xFF8AE8D8), Color(0xFF208A78)],
        accent: Color(0xFFD6FFF7),
        support: Color(0xFFFFD599),
      );
    case 'amber_reset':
      return const _PosterPalette(
        background: [Color(0xFF22160A), Color(0xFF6B4314), Color(0xFFB9691A)],
        hero: [Color(0xFFF7C36A), Color(0xFFD87D19)],
        accent: Color(0xFFFFF0CC),
        support: Color(0xFFFFD2A1),
      );
    default:
      return const _PosterPalette(
        background: [Color(0xFFF1F5F9), Color(0xFFDCE6F2), Color(0xFFC3D0E2)],
        hero: [Color(0xFFDAE4F5), Color(0xFF8EA8D7)],
        accent: Color(0xFF2F6BFF),
        support: Color(0xFF39C2BD),
      );
  }
}

class _PosterBackdropPainter extends CustomPainter {
  const _PosterBackdropPainter({
    required this.palette,
  });

  final _PosterPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    paint.color = palette.accent.withValues(alpha: 0.10);
    canvas.drawCircle(
        Offset(size.width * 0.18, size.height * 0.16), 170, paint);

    paint.color = palette.support.withValues(alpha: 0.08);
    canvas.drawCircle(
        Offset(size.width * 0.82, size.height * 0.22), 210, paint);

    paint.color = Colors.white.withValues(alpha: 0.05);
    for (var i = 0; i < 12; i++) {
      final radius = 18 + (i * 4).toDouble();
      final angle = i / 12 * math.pi * 2;
      canvas.drawCircle(
        Offset(
          size.width * 0.72 + math.cos(angle) * 68,
          size.height * 0.80 + math.sin(angle) * 46,
        ),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PosterBackdropPainter oldDelegate) {
    return oldDelegate.palette != palette;
  }
}

class _CoverArtPainter extends CustomPainter {
  const _CoverArtPainter({
    required this.artKind,
    required this.compact,
  });

  final PosterArtKind artKind;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = compact ? 10 : 18
      ..strokeCap = StrokeCap.round;

    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(compact ? 24 : 34),
    );
    paint.color = Colors.white.withValues(alpha: compact ? 0.10 : 0.12);
    canvas.drawRRect(frame, paint);

    switch (artKind) {
      case PosterArtKind.focusBeam:
        paint.color = Colors.white.withValues(alpha: 0.22);
        final path = Path()
          ..moveTo(size.width * 0.18, size.height)
          ..lineTo(size.width * 0.50, size.height * 0.18)
          ..lineTo(size.width * 0.82, size.height)
          ..close();
        canvas.drawPath(path, paint);
        stroke.color = Colors.white.withValues(alpha: 0.52);
        canvas.drawLine(
          Offset(size.width * 0.50, size.height * 0.20),
          Offset(size.width * 0.50, size.height * 0.88),
          stroke,
        );
      case PosterArtKind.growthWave:
        stroke.color = Colors.white.withValues(alpha: 0.60);
        final wave = Path()
          ..moveTo(size.width * 0.14, size.height * 0.72)
          ..quadraticBezierTo(
            size.width * 0.44,
            size.height * 0.30,
            size.width * 0.84,
            size.height * 0.62,
          );
        canvas.drawPath(wave, stroke);
        stroke.color = Colors.white.withValues(alpha: 0.34);
        final wave2 = Path()
          ..moveTo(size.width * 0.22, size.height * 0.86)
          ..quadraticBezierTo(
            size.width * 0.48,
            size.height * 0.46,
            size.width * 0.76,
            size.height * 0.80,
          );
        canvas.drawPath(wave2, stroke);
      case PosterArtKind.amberSun:
        paint.color = Colors.white.withValues(alpha: 0.20);
        canvas.drawCircle(
          Offset(size.width * 0.50, size.height * 0.42),
          compact ? 24 : 48,
          paint,
        );
        stroke.color = Colors.white.withValues(alpha: 0.48);
        final arch = Path()
          ..moveTo(size.width * 0.18, size.height * 0.78)
          ..quadraticBezierTo(
            size.width * 0.50,
            size.height * 0.32,
            size.width * 0.82,
            size.height * 0.78,
          );
        canvas.drawPath(arch, stroke);
      case PosterArtKind.glassRibbon:
        paint.color = Colors.white.withValues(alpha: 0.14);
        final ribbon = Path()
          ..moveTo(size.width * -0.08, size.height * 0.58)
          ..quadraticBezierTo(
            size.width * 0.28,
            size.height * 0.24,
            size.width * 0.56,
            size.height * 0.44,
          )
          ..quadraticBezierTo(
            size.width * 0.76,
            size.height * 0.60,
            size.width * 1.08,
            size.height * 0.38,
          )
          ..lineTo(size.width * 1.08, size.height * 0.64)
          ..quadraticBezierTo(
            size.width * 0.74,
            size.height * 0.84,
            size.width * 0.46,
            size.height * 0.68,
          )
          ..quadraticBezierTo(
            size.width * 0.20,
            size.height * 0.52,
            size.width * -0.08,
            size.height * 0.76,
          )
          ..close();
        canvas.drawPath(ribbon, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CoverArtPainter oldDelegate) {
    return oldDelegate.artKind != artKind || oldDelegate.compact != compact;
  }
}
