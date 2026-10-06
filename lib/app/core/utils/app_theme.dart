import 'package:acoplan/app/core/utils/app_colors.dart';
import 'package:acoplan/app/core/utils/app_css.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData theme = ThemeData(
    fontFamily: 'WorkSans',
    // Cores definidas explicitamente: com colorSchemeSeed o Flutter gerava
    // tons próprios (barra azul-arroxeada em Pedidos/Ordens/Estoque, fundos
    // lilases em diálogos e menus).
    primaryColor: AppColors.primaryMain,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryMain,
      primary: AppColors.primaryMain,
      onPrimary: AppColors.white,
      secondary: AppColors.secondary,
      onSecondary: AppColors.white,
      error: AppColors.error,
      onError: AppColors.white,
      surface: AppColors.white,
      onSurface: AppColors.black,
      onSurfaceVariant: AppColors.neutralDark,
      surfaceTint: Colors.transparent,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColorsSystem.light.primary[50]!,
      surfaceContainer: AppColors.neutralLightest,
      surfaceContainerHigh: const Color(0xFFE6EAEF),
      surfaceContainerHighest: AppColors.neutralLight,
      outline: AppColors.primaryMedium,
      outlineVariant: AppColors.neutralLight,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
    popupMenuTheme: const PopupMenuThemeData(color: Colors.white),
    drawerTheme: const DrawerThemeData(backgroundColor: Colors.white),
    bottomSheetTheme:
        const BottomSheetThemeData(backgroundColor: Colors.white),
    cardTheme: const CardThemeData(color: Colors.white),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: AppColors.neutralDark,
      selectionColor: AppColors.secondary.withValues(alpha: 0.25),
      selectionHandleColor: AppColors.neutralDark,
    ),
    datePickerTheme: DatePickerThemeData(
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryMain;
        }
        return null;
      }),
      backgroundColor: AppColors.white,
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? AppColors.neutralMedium
              : AppColors.primaryMain,
        ),
        textStyle: WidgetStatePropertyAll(
          const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ).setColor(AppColors.neutralLightest),
        ),
        foregroundColor: WidgetStatePropertyAll(AppColors.white),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppCss.radius8),
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStatePropertyAll(AppColors.primaryMain),
        foregroundColor: WidgetStatePropertyAll(AppColors.white),
        iconSize: const WidgetStatePropertyAll(24),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppCss.radius8),
        ),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: const EdgeInsets.all(12),
      border: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.neutralMedium, width: 1),
        borderRadius: AppCss.radius8,
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryMain, width: 2),
        borderRadius: AppCss.radius8,
      ),
      hintStyle: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.neutralMedium,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primaryMain,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: AppColors.primaryMain,
      shadowColor: Colors.transparent,
    ),
  );
}
