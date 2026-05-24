import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'app_tokens.dart';

// ─── TEMA CLARO ───────────────────────────────────────────────────────────────
final ThemeData appTheme = _buildTheme(Brightness.light);

// ─── TEMA ESCURO ──────────────────────────────────────────────────────────────
final ThemeData appDarkTheme = _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;

  final Color background  = isDark ? AppColors.darkBackground : AppColors.light;
  final Color surface     = isDark ? AppColors.darkSurface    : AppColors.white;
  final Color cardColor   = isDark ? AppColors.darkCard       : AppColors.white;
  final Color onSurface   = isDark ? AppColors.darkText       : AppColors.dark;
  final Color subtext     = isDark ? AppColors.darkSubtext    : AppColors.grey500;
  final Color border      = isDark ? AppColors.darkBorder     : AppColors.grey200;

  // System UI overlay style
  final systemUiStyle = isDark
      ? SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.darkBackground,
        )
      : SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.white,
        );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Inter',

    // ── Paleta de cores ──────────────────────────────────────────────────────
    colorScheme: ColorScheme(
      brightness: brightness,
      primary:          AppColors.primary,
      onPrimary:        AppColors.white,
      primaryContainer: isDark ? AppColors.grey800 : AppColors.grey100,
      onPrimaryContainer: onSurface,
      secondary:        AppColors.info,
      onSecondary:      AppColors.white,
      secondaryContainer: isDark ? AppColors.darkCard : AppColors.infoLight,
      onSecondaryContainer: AppColors.info,
      error:            AppColors.danger,
      onError:          AppColors.white,
      errorContainer:   AppColors.dangerLight,
      onErrorContainer: AppColors.danger,
      surface:          surface,
      onSurface:        onSurface,
      surfaceContainerHighest: isDark ? AppColors.darkCard : AppColors.grey50,
      outline:          border,
      outlineVariant:   border,
      shadow:           Colors.black,
      inverseSurface:   isDark ? AppColors.white : AppColors.dark,
      onInverseSurface: isDark ? AppColors.dark : AppColors.white,
    ),

    scaffoldBackgroundColor: background,

    // ── AppBar ───────────────────────────────────────────────────────────────
    appBarTheme: AppBarTheme(
      backgroundColor:  surface,
      foregroundColor:  onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
      centerTitle: true,
      systemOverlayStyle: systemUiStyle,
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: onSurface, size: 22),
      actionsIconTheme: IconThemeData(color: onSurface, size: 22),
    ),

    // ── Tipografia ───────────────────────────────────────────────────────────
    textTheme: TextTheme(
      displayLarge: TextStyle(
        fontSize: 34, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -1.0, height: 1.1,
      ),
      displayMedium: TextStyle(
        fontSize: 28, fontWeight: FontWeight.w700,
        color: onSurface, letterSpacing: -0.8, height: 1.15,
      ),
      displaySmall: TextStyle(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.5, height: 1.2,
      ),
      headlineLarge: TextStyle(
        fontSize: 20, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.4,
      ),
      headlineMedium: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: -0.2,
      ),
      titleMedium: TextStyle(
        fontSize: 15, fontWeight: FontWeight.w500,
        color: onSurface, letterSpacing: -0.1,
      ),
      titleSmall: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w500,
        color: onSurface, letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: onSurface, height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: onSurface, height: 1.5,
      ),
      bodySmall: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: subtext, height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: onSurface, letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        fontSize: 12, fontWeight: FontWeight.w500,
        color: subtext, letterSpacing: 0.1,
      ),
      labelSmall: TextStyle(
        fontSize: 10, fontWeight: FontWeight.w500,
        color: subtext, letterSpacing: 0.2,
      ),
    ),

    // ── Cards ────────────────────────────────────────────────────────────────
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius16),
        side: BorderSide(color: border, width: 1),
      ),
      margin: EdgeInsets.zero,
    ),

    // ── Inputs ───────────────────────────────────────────────────────────────
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.darkCard : AppColors.grey50,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp16, vertical: AppTokens.sp14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
      labelStyle: TextStyle(
        color: subtext, fontWeight: FontWeight.w400, fontSize: 14,
      ),
      hintStyle: TextStyle(
        color: subtext, fontWeight: FontWeight.w400, fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: AppColors.primary, fontWeight: FontWeight.w500,
      ),
    ),

    // ── Botões ───────────────────────────────────────────────────────────────
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: isDark ? AppColors.grey800 : AppColors.grey200,
        disabledForegroundColor: subtext,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp24, vertical: AppTokens.sp14,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp12, vertical: AppTokens.sp8,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius8),
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: border, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radius12),
        ),
        textStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.sp24, vertical: AppTokens.sp14,
        ),
      ),
    ),

    // ── FAB ─────────────────────────────────────────────────────────────────
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius16),
      ),
    ),

    // ── Dialogs ──────────────────────────────────────────────────────────────
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius24),
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: onSurface,
        letterSpacing: -0.3,
      ),
      contentTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: subtext,
        height: 1.5,
      ),
    ),

    // ── Bottom Sheet ─────────────────────────────────────────────────────────
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTokens.radius24),
        ),
      ),
      dragHandleColor: isDark ? AppColors.grey600 : AppColors.grey300,
      dragHandleSize: const Size(40, 4),
    ),

    // ── Snack Bar ────────────────────────────────────────────────────────────
    snackBarTheme: SnackBarThemeData(
      backgroundColor: isDark ? AppColors.grey800 : AppColors.grey900,
      contentTextStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.white,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),

    // ── Chips ────────────────────────────────────────────────────────────────
    chipTheme: ChipThemeData(
      backgroundColor: isDark ? AppColors.darkCard : AppColors.grey100,
      selectedColor: isDark ? AppColors.grey700 : AppColors.grey900,
      labelStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      side: BorderSide(color: border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp10, vertical: AppTokens.sp4,
      ),
    ),

    // ── Switch ───────────────────────────────────────────────────────────────
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(AppColors.white),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return isDark ? AppColors.grey700 : AppColors.grey300;
      }),
    ),

    // ── Divider ──────────────────────────────────────────────────────────────
    dividerTheme: DividerThemeData(
      color: border,
      thickness: 1,
      space: 1,
    ),

    // ── List Tile ────────────────────────────────────────────────────────────
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTokens.sp16, vertical: AppTokens.sp4,
      ),
      titleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      subtitleTextStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: subtext,
      ),
      iconColor: onSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius12),
      ),
    ),

    // ── Icons ────────────────────────────────────────────────────────────────
    iconTheme: IconThemeData(color: onSurface, size: 22),

    // ── Progress Indicator ───────────────────────────────────────────────────
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
    ),

    // ── Checkbox ─────────────────────────────────────────────────────────────
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return AppColors.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.white),
      side: BorderSide(color: border, width: 1.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radius4),
      ),
    ),
  );
}
