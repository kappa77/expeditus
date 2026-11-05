import 'package:flutter/material.dart';

/// A small, warm palette for a deliberately quiet app.
abstract final class ExpeditusColors {
  static const background = Color(0xFF0D0F12);
  static const surface = Color(0xFF14171B);
  static const surfaceAlt = Color(0xFF1A1E24);
  static const surfaceHover = Color(0xFF20252C);
  static const border = Color(0xFF272C34);
  static const text = Color(0xFFE9E7E2);
  static const textDim = Color(0xFFB5B9C0);
  static const muted = Color(0xFF858C96);
  static const accent = Color(0xFFE7B45A);
  static const accentSoft = Color(0x33E7B45A);
  static const green = Color(0xFF7BC29A);
  static const red = Color(0xFFE07A7A);
}

ThemeData expeditusTheme() {
  const scheme = ColorScheme.dark(
    primary: ExpeditusColors.accent,
    onPrimary: ExpeditusColors.background,
    secondary: ExpeditusColors.green,
    onSecondary: ExpeditusColors.background,
    surface: ExpeditusColors.surface,
    onSurface: ExpeditusColors.text,
    error: ExpeditusColors.red,
    onError: ExpeditusColors.background,
  );

  final base = ThemeData(
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: ExpeditusColors.background,
    useMaterial3: true,
    fontFamily: 'Segoe UI',
    fontFamilyFallback: const ['Inter', 'SF Pro Text', 'Roboto', 'sans-serif'],
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: ExpeditusColors.text,
      displayColor: ExpeditusColors.text,
    ),
    dividerTheme: const DividerThemeData(
      color: ExpeditusColors.border,
      thickness: 1,
      space: 1,
    ),
    iconTheme: const IconThemeData(color: ExpeditusColors.muted, size: 20),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: ExpeditusColors.surfaceAlt,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ExpeditusColors.border),
      ),
      textStyle: const TextStyle(
        color: ExpeditusColors.text,
        fontSize: 12,
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: ExpeditusColors.surfaceAlt,
      contentTextStyle: TextStyle(color: ExpeditusColors.text),
      behavior: SnackBarBehavior.floating,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: ExpeditusColors.accent,
        foregroundColor: ExpeditusColors.background,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: ExpeditusColors.accent,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: ExpeditusColors.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      hintStyle: const TextStyle(color: ExpeditusColors.muted, fontSize: 13),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ExpeditusColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ExpeditusColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ExpeditusColors.accent),
      ),
    ),
  );
}
