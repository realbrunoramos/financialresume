import 'package:flutter/material.dart';

/// Paleta completa de cores da aplicação.
/// Mantém compatibilidade total com o código existente.
class AppColors {
  AppColors._();

  // ─── BRAND ────────────────────────────────────────────────────────────────
  static const Color primary      = Color(0xFF0C0C0C);
  static const Color primarySoft  = Color(0xFF1A1A2E);

  // ─── BASE ─────────────────────────────────────────────────────────────────
  static const Color dark   = Color(0xFF0C0C0C);
  static const Color light  = Color(0xFFF4F4F3);
  static const Color black  = Colors.black;
  static const Color white  = Colors.white;

  // ─── NEUTRALS (escala cinzenta explícita) ─────────────────────────────────
  static const Color grey50  = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // MaterialColor alias — mantém ".shade300" etc. do código existente
  static const MaterialColor grey = Colors.grey;

  // ─── SEMÂNTICAS ───────────────────────────────────────────────────────────
  static const Color success      = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color danger       = Color(0xFFEF4444);
  static const Color dangerLight  = Color(0xFFFEE2E2);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color info         = Color(0xFF3B82F6);
  static const Color infoLight    = Color(0xFFDBEAFE);

  // Aliases semânticos (backward compat)
  static const Color green = success;
  static const Color red   = danger;
  static const Color blue  = info;

  // ─── DARK MODE ────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSurface    = Color(0xFF1C1C1E);
  static const Color darkCard       = Color(0xFF2C2C2E);
  static const Color darkBorder     = Color(0xFF3A3A3C);
  static const Color darkText       = Color(0xFFF2F2F7);
  static const Color darkSubtext    = Color(0xFF8E8E93);

  // ─── PREMIUM ──────────────────────────────────────────────────────────────
  static const Color premium      = Color(0xFF7C3AED);
  static const Color premiumSoft  = Color(0xFF8B5CF6);
  static const Color premiumGold  = Color(0xFFF59E0B);
  static const Color premiumDeep  = Color(0xFF6D28D9);
  static const Color premiumLight = Color(0xFFEDE9FE);

  // ─── GRADIENTES ───────────────────────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0C0C0C), Color(0xFF2D3748)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient dangerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFDC2626), Color(0xFFEF4444)],
  );

  // Gradientes das secções (cartões na HomeScreen)
  static const List<List<Color>> sectionGradients = [
    [Color(0xFF0C0C0C), Color(0xFF2D3748)],
    [Color(0xFF1E3A5F), Color(0xFF2B6CB0)],
    [Color(0xFF1A365D), Color(0xFF2C5282)],
    [Color(0xFF22543D), Color(0xFF276749)],
    [Color(0xFF44337A), Color(0xFF6B46C1)],
    [Color(0xFF702459), Color(0xFFB83280)],
    [Color(0xFF7B341E), Color(0xFFC05621)],
    [Color(0xFF1A202C), Color(0xFF4A5568)],
  ];
}
