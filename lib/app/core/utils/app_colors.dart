import 'package:flutter/material.dart';

class AppColors {
  static Color get primaryLightest => AppColorsSystem.light.primary[100]!;
  static Color get primaryLight => AppColorsSystem.light.primary[200]!;
  static Color get primaryMedium => AppColorsSystem.light.primary[300]!;
  static Color get primaryMain => AppColorsSystem.light.primary[500]!;
  static Color get primaryDark => AppColorsSystem.light.primary[900]!;

  static Color get secondaryLight => AppColorsSystem.light.secondary[200]!;
  static Color get secondary => AppColorsSystem.light.secondary[500]!;
  static Color get secondaryDark => AppColorsSystem.light.secondary[900]!;

  static Color get white => AppColorsSystem.light.neutral[100]!;
  static Color get neutralLightest => AppColorsSystem.light.neutral[300]!;
  static Color get neutralLight => AppColorsSystem.light.neutral[400]!;
  static Color get neutralMedium => AppColorsSystem.light.neutral[500]!;
  static Color get neutralDark => AppColorsSystem.light.neutral[700]!;
  static Color get black => AppColorsSystem.light.neutral[900]!;

  static Color get error => AppColorsSystem.light.error;
  static Color get success => AppColorsSystem.light.success;
  static Color get pending => AppColorsSystem.light.pending;
}

class AppColorsSystem {
  static AppColorsSystem light = AppColorsSystem.lightFactory();

  MaterialColor primary;
  MaterialColor secondary;
  MaterialColor neutral;
  Color error;
  Color success;
  Color pending;

  AppColorsSystem({
    required this.primary,
    required this.secondary,
    required this.neutral,
    required this.error,
    required this.success,
    required this.pending,
  });

  factory AppColorsSystem.lightFactory() {
    return AppColorsSystem(
      primary: const MaterialColor(0xFF0F172A, <int, Color>{
        50: Color(0xFFF1F5F9),
        100: Color(0xFFE2E8F0),
        200: Color(0xFFCBD5E1),
        300: Color(0xFF94A3B8),
        500: Color(0xFF0F172A),
        700: Color(0xFF334155),
        900: Color(0xFF1E293B),
      }),
      secondary: const MaterialColor(0xFF3B82F6, <int, Color>{
        200: Color(0xFFBFDBFE),
        500: Color(0xFF3B82F6),
        900: Color(0xFF1E3A8A),
      }),
      neutral: const MaterialColor(0xFF64748B, <int, Color>{
        100: Color(0xFFFFFFFF),
        300: Color(0xFFF1F5F9),
        400: Color(0xFFE2E8F0),
        500: Color(0xFF64748B),
        700: Color(0xFF334155),
        900: Color(0xFF0F172A),
      }),
      error: const Color(0xFFBE123C),
      success: const Color(0xFF15803D),
      pending: const Color(0xFFB45309),
    );
  }
}
