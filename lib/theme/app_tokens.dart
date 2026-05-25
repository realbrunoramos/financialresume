import 'package:flutter/material.dart';
import 'colors.dart';

/// Tokens de design — a única fonte de verdade para espaçamentos,
/// raios, sombras e durações de animação.
abstract class AppTokens {

  // ─── ESPAÇAMENTO ──────────────────────────────────────────────────────────
  static const double sp2  = 2;
  static const double sp4  = 4;
  static const double sp6  = 6;
  static const double sp8  = 8;
  static const double sp10 = 10;
  static const double sp12 = 12;
  static const double sp14 = 14;
  static const double sp16 = 16;
  static const double sp20 = 20;
  static const double sp24 = 24;
  static const double sp28 = 28;
  static const double sp32 = 32;
  static const double sp40 = 40;
  static const double sp48 = 48;
  static const double sp56 = 56;
  static const double sp64 = 64;

  // ─── RAIO DE BORDA ────────────────────────────────────────────────────────
  static const double radius4   = 4;
  static const double radius6   = 6;
  static const double radius8   = 8;
  static const double radius10  = 10;
  static const double radius12  = 12;
  static const double radius16  = 16;
  static const double radius20  = 20;
  static const double radius24  = 24;
  static const double radius32  = 32;
  static const double radiusFull = 999;

  // ─── ANIMAÇÕES ────────────────────────────────────────────────────────────
  static const Duration fast   = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow   = Duration(milliseconds: 450);
  static const Duration xslow  = Duration(milliseconds: 650);

  static const Curve easeOut   = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve decelerate = Curves.decelerate;

  // ─── SOMBRAS ──────────────────────────────────────────────────────────────
  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(10),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(6),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowMd => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(14),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(7),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> get shadowLg => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(20),
      blurRadius: 20,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(10),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowXl => [
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(28),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: const Color(0xFF000000).withAlpha(14),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ─── DECORAÇÕES DE CARD ───────────────────────────────────────────────────
  static BoxDecoration cardLight({double radius = radius16}) => BoxDecoration(
    color: AppColors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadowMd,
  );

  static BoxDecoration cardDark({double radius = radius16}) => BoxDecoration(
    color: AppColors.darkCard,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: shadowMd,
  );

  /// Devolve a decoração correcta para o tema actual do contexto.
  static BoxDecoration cardOf(BuildContext context, {double radius = radius16}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? cardDark(radius: radius) : cardLight(radius: radius);
  }

  // ─── PADDING PADRÕES ──────────────────────────────────────────────────────

  static const EdgeInsets paddingScreen  = EdgeInsets.all(sp16);
  static const EdgeInsets paddingCard    = EdgeInsets.all(sp20);
  static const EdgeInsets paddingSection = EdgeInsets.symmetric(
    horizontal: sp16, vertical: sp12,
  );
}

/// Shared fade + 4 % horizontal slide page route.
/// Import `app_tokens.dart` (already done in every screen) and call
/// `slideRoute(MyScreen())` wherever you would use `MaterialPageRoute`.
PageRouteBuilder<T> slideRoute<T>(Widget page) => PageRouteBuilder<T>(
  pageBuilder: (_, __, ___) => page,
  transitionDuration: AppTokens.normal,
  transitionsBuilder: (_, animation, __, child) => FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween(begin: const Offset(0.04, 0), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
      child: child,
    ),
  ),
);
