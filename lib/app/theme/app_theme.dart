import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../features/common/theme/app_colors.dart';

class AppTheme {
  const AppTheme._();

  static const Color _primaryBlue = Color(0xFF2563EB);

  // Design tokens (consistencia visual)
  static const double _rSm = 12;
  static const double _rMd = 16;
  static const double _rLg = 18;

  static ThemeData get light => _buildTheme(_lightColorScheme);
  static ThemeData get dark => _buildTheme(_darkColorScheme);

  static ThemeData _buildTheme(ColorScheme scheme) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.background,
    );

    final baseText = GoogleFonts.interTextTheme(base.textTheme);

    final textTheme = baseText
        .apply(
          bodyColor: scheme.onBackground,
          displayColor: scheme.onBackground,
        )
        .copyWith(
          // Números “Strava”: bien pesados y con tabular figures (alinean perfecto)
          displaySmall: baseText.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.05,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),

          headlineSmall: baseText.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),

          titleLarge: baseText.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),

          titleMedium: baseText.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),

          labelLarge: baseText.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),

          bodyMedium: baseText.bodyMedium?.copyWith(height: 1.45),
          bodySmall: baseText.bodySmall?.copyWith(height: 1.35),
        );

    return base.copyWith(
      textTheme: textTheme,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent, // evita tint gris raro en M3
      ),

      // Cards: sin margin global (para que TODO alinee prolijo)
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: scheme.brightness == Brightness.dark ? 2 : 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_rMd),
        ),
      ),

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withOpacity(0.7),
        thickness: 1,
        space: 1,
      ),

      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),

      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurfaceVariant,
        textColor: scheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rMd)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.onSurface.withOpacity(0.12),
          disabledForegroundColor: scheme.onSurface.withOpacity(0.38),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: _inputDecorationTheme(scheme),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rSm)),
        labelStyle: TextStyle(color: scheme.onSurface),
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primary.withOpacity(0.14),
        disabledColor: scheme.onSurface.withOpacity(0.08),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
        actionTextColor: scheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rMd)),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rLg)),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rLg)),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.all(
          TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600),
        ),
        iconTheme: WidgetStateProperty.all(
          IconThemeData(color: scheme.onSurfaceVariant),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(_rMd)),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceVariant,
        circularTrackColor: scheme.surfaceVariant,
      ),
    );
  }

  static InputDecorationTheme _inputDecorationTheme(ColorScheme scheme) {
    final radius = BorderRadius.circular(_rLg);

    return InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceVariant,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      floatingLabelStyle: TextStyle(color: scheme.primary),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.75)),
      prefixIconColor: scheme.onSurfaceVariant,
      suffixIconColor: scheme.onSurfaceVariant,

      border: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide.none,
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),

      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error),
      ),

      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: scheme.error, width: 1.5),
      ),

      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
    );
  }

  static final ColorScheme _lightColorScheme = ColorScheme.fromSeed(
    seedColor: _primaryBlue,
    brightness: Brightness.light,
  );

  static final ColorScheme _darkColorScheme =
      ColorScheme.fromSeed(seedColor: _primaryBlue, brightness: Brightness.dark).copyWith(
    primary: _primaryBlue,
    secondary: AppColors.accent,
    tertiary: AppColors.accentSecondary,

    background: AppColors.background,
    surface: AppColors.card,
    surfaceVariant: AppColors.surface,

    onBackground: AppColors.textPrimary,
    onSurface: AppColors.textPrimary,
    onSurfaceVariant: AppColors.textMuted,

    outline: AppColors.border,
    outlineVariant: AppColors.borderSubtle,

    error: AppColors.danger,
  );
}
