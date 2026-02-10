import 'package:flutter/material.dart';

/// Tokens de color (roles), pensados para una UI dark-on-dark premium.
/// Mantiene tu identidad visual, pero con jerarquía tipográfica y bordes consistentes.
class AppColors {
  const AppColors._();

  // Surfaces
  static const Color background = Color(0xFF0E1624); // base
  static const Color card = Color(0xFF161F2C);       // cards principales
  static const Color surface = Color(0xFF1B2433);    // inputs/containers

  // Accents
  static const Color accent = Color(0xFF2AF5D2);
  static const Color accentSecondary = Color(0xFF7CF4FF);

  static const Color accentTraining = Color(0xFF2AD5C1);
  static const Color accentFood = Color(0xFFF6C85F);
  static const Color accentSleep = Color(0xFF8B7CFF);

  // Text (off-white premium para evitar blanco puro “quemado”)
  static const Color textPrimary = Color(0xFFEAF1FF);
  static const Color textSecondary = Color(0xFFC7D2E1);
  static const Color textMuted = Color(0xFF9BA7B4);

  // Borders / dividers
  static const Color border = Color(0xFF2F3B4C);
  static const Color borderSubtle = Color(0xFF243041);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
}
