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

  // ── Marca (vermelho do logo M2) — usar com moderação: item ativo,
  //    aba selecionada, um destaque por área da tela ──
  static const Color brand = Color(0xFFD7261E);
  static const Color brandSoft = Color(0xFFFCEDEC);

  // ── Status com significado fixo em todas as telas ──
  static const Color statusAguardando = Color(0xFF8A94A3);
  static const Color statusProduzindo = Color(0xFF2563EB);
  static const Color statusPronto = Color(0xFF15803D);
  static const Color statusAtencao = Color(0xFFD97706);
  static const Color statusCritico = Color(0xFFB42318);
}

class AppColorsSystem {
  static AppColorsSystem light = AppColorsSystem.lightFactory();
  static AppColorsSystem dart = AppColorsSystem.darkFactory();

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

  /// Paleta "Aço": neutros grafite com leve tom azul-acinzentado.
  factory AppColorsSystem.lightFactory() {
    return AppColorsSystem(
      primary: const MaterialColor(0xFF12161C, <int, Color>{
        50: Color(0xFFF6F8FA),
        100: Color(0xFFDCE1E7),
        200: Color(0xFFB8C0CB),
        300: Color(0xFF8A94A3),
        500: Color(0xFF12161C), // Aço 950 — barra superior, menu, botões principais
        700: Color(0xFF3A4350),
        900: Color(0xFF1B2129),
      }),
      secondary: const MaterialColor(0xFF2563EB, <int, Color>{
        200: Color(0xFFBFD3FB),
        500: Color(0xFF2563EB),
        900: Color(0xFF1E3A8A),
      }),
      neutral: const MaterialColor(0xFF6B7685, <int, Color>{
        100: Color(0xFFFFFFFF),
        300: Color(0xFFEDF0F4), // Aço 100 — fundos
        400: Color(0xFFDCE1E7), // Aço 200 — bordas
        500: Color(0xFF6B7685), // Aço 500 — legendas
        700: Color(0xFF3A4350), // Aço 700 — ícones, texto secundário
        900: Color(0xFF1B2129), // Aço 900 — texto
      }),
      error: const Color(0xFFB42318),
      success: const Color(0xFF15803D),
      pending: const Color(0xFFB45309),
    );
  }

  factory AppColorsSystem.darkFactory() {
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
        100: Color(0xFF0F172A),
        300: Color(0xFF1E293B),
        400: Color(0xFF334155),
        500: Color(0xFF64748B),
        700: Color(0xFFE2E8F0),
        900: Color(0xFFF8FAFC),
      }),
      error: const Color(0xFFBE123C),
      success: const Color(0xFF15803D),
      pending: const Color(0xFFB45309),
    );
  }
}
