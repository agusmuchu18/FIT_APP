import 'package:flutter/material.dart';

import '../../features/common/theme/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primaryBlue = Color(0xFF2563EB);

  static ThemeData get light => ThemeData(
        colorScheme: _lightColorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: _lightColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: _lightColorScheme.surface,
          foregroundColor: _lightColorScheme.onSurface,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _lightColorScheme.primary,
            foregroundColor: _lightColorScheme.onPrimary,
            disabledBackgroundColor: _lightColorScheme.onSurface.withOpacity(0.12),
            disabledForegroundColor:
                _lightColorScheme.onSurface.withOpacity(0.38),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: _inputDecorationTheme(_lightColorScheme),
        cardTheme: CardThemeData(
          color: _lightColorScheme.surface,
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        primaryColor: _primaryBlue,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: AppColors.background,
        cardColor: AppColors.card,
        textTheme: _darkTextTheme,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _primaryBlue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.white.withOpacity(0.12),
            disabledForegroundColor: Colors.white.withOpacity(0.38),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: _darkInputDecorationTheme,
        cardTheme: CardThemeData(
          color: AppColors.card,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.all(12),
        ),
      );

  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: _primaryBlue,
    brightness: Brightness.light,
  );

  static final ColorScheme _darkColorScheme =
      ColorScheme.fromSeed(seedColor: _primaryBlue, brightness: Brightness.dark)
          .copyWith(
    primary: _primaryBlue,
    secondary: AppColors.accent,
    background: AppColors.background,
    surface: AppColors.card,
    surfaceVariant: AppColors.surface,
    onSurfaceVariant: AppColors.textMuted,
    onBackground: AppColors.textPrimary,
    onSurface: AppColors.textPrimary,
    tertiary: const Color(0xFF7C3AED),
  );

  static final TextTheme _darkTextTheme =
      ThemeData.dark(useMaterial3: true).textTheme.copyWith(
            bodyLarge: const TextStyle(color: AppColors.textPrimary, height: 1.4),
            bodyMedium:
                const TextStyle(color: AppColors.textSecondary, height: 1.45),
            bodySmall: const TextStyle(color: AppColors.textMuted, height: 1.4),
            titleMedium: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
            titleLarge: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
            labelLarge: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          );

  static final InputDecorationTheme _darkInputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    labelStyle: const TextStyle(color: AppColors.textSecondary),
    floatingLabelStyle: const TextStyle(color: AppColors.textSecondary),
    hintStyle: const TextStyle(color: AppColors.textMuted),
    prefixIconColor: AppColors.textMuted,
    suffixIconColor: AppColors.textMuted,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
  );

  static InputDecorationTheme _inputDecorationTheme(ColorScheme colorScheme) =>
      InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant,
        labelStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: colorScheme.primary),
        prefixIconColor: colorScheme.onSurfaceVariant,
        suffixIconColor: colorScheme.onSurfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: colorScheme.error, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}
