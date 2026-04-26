import 'dart:ui';

import 'package:flutter/material.dart';

class AppTheme {
  static const _surface = Color(0xCCFFFFFF);
  static const _outline = Color(0x33A0AEC0);
  static const _primary = Color(0xFF2363FF);
  static const _text = Color(0xFF152033);
  static const _muted = Color(0xFF60708A);
  static const _background = Color(0xFFF1F5FB);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _primary,
      brightness: Brightness.light,
      surface: _surface,
      primary: _primary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -1.1,
          color: _text,
        ),
        titleLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: _text,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _text,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          height: 1.55,
          color: _text,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: _muted,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w600,
          color: _muted,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: const BorderSide(color: _outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.78),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _primary, width: 1.2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          foregroundColor: _text,
          side: const BorderSide(color: _outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          backgroundColor: Colors.white.withValues(alpha: 0.45),
        ),
      ),
      chipTheme: ChipThemeData(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        side: const BorderSide(color: _outline),
        backgroundColor: Colors.white.withValues(alpha: 0.45),
        selectedColor: _primary.withValues(alpha: 0.12),
        labelStyle: const TextStyle(color: _text, fontWeight: FontWeight.w600),
      ),
    );
  }

  static const pagePadding = EdgeInsets.all(24);
  static const sectionGap = 20.0;
  static const sectionRadius = 28.0;

  static BoxDecoration glassDecoration() {
    return BoxDecoration(
      borderRadius: BorderRadius.circular(sectionRadius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.64)),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.78),
          Colors.white.withValues(alpha: 0.56),
        ],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x18435A86),
          blurRadius: 48,
          offset: Offset(0, 24),
        ),
      ],
    );
  }

  static ImageFilter glassBlur() => ImageFilter.blur(sigmaX: 18, sigmaY: 18);
}
