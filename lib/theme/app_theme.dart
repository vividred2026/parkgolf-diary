import 'package:flutter/material.dart';

/// Figma "Theme" 컬러 변수(Light / Dark)를 그대로 옮긴 토큰.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bgScreen,
    required this.surfaceDefault,
    required this.surfaceSubtle,
    required this.surfacePlaceholder,
    required this.surfaceSelected,
    required this.borderDefault,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.brandPrimary,
    required this.brandOnPrimary,
    required this.inverseBg,
    required this.inverseText,
    required this.warningBg,
    required this.warningBorder,
    required this.warningText,
    required this.danger,
    required this.success,
  });

  final Color bgScreen;
  final Color surfaceDefault;
  final Color surfaceSubtle;
  final Color surfacePlaceholder;
  final Color surfaceSelected;
  final Color borderDefault;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color brandPrimary;
  final Color brandOnPrimary;
  final Color inverseBg;
  final Color inverseText;
  final Color warningBg;
  final Color warningBorder;
  final Color warningText;
  final Color danger;
  final Color success;

  static const light = AppColors(
    bgScreen: Color(0xFFFFFFFF),
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF5F7FA),
    surfacePlaceholder: Color(0xFFD9D9D9),
    surfaceSelected: Color(0xFFF2EFFB),
    borderDefault: Color(0xFFD1D6DB),
    textPrimary: Color(0xFF0F1214),
    textSecondary: Color(0xFF6B7782),
    textDisabled: Color(0xFFD1D6DB),
    brandPrimary: Color(0xFF493DE7),
    brandOnPrimary: Color(0xFFFFFFFF),
    inverseBg: Color(0xFF0F1214),
    inverseText: Color(0xFFFFFFFF),
    warningBg: Color(0xFFFFF8EE),
    warningBorder: Color(0xFFFFD9A8),
    warningText: Color(0xFFB35900),
    danger: Color(0xFFE5484D),
    success: Color(0xFF22BB5F),
  );

  static const dark = AppColors(
    bgScreen: Color(0xFF111214),
    surfaceDefault: Color(0xFF1C1D21),
    surfaceSubtle: Color(0xFF26272D),
    surfacePlaceholder: Color(0xFF3A3B42),
    surfaceSelected: Color(0xFF2D2544),
    borderDefault: Color(0xFF34363D),
    textPrimary: Color(0xFFF1F2F4),
    textSecondary: Color(0xFF9BA4AE),
    textDisabled: Color(0xFF4A4D55),
    brandPrimary: Color(0xFF928CEE),
    brandOnPrimary: Color(0xFFFFFFFF),
    inverseBg: Color(0xFFF1F2F4),
    inverseText: Color(0xFF111214),
    warningBg: Color(0xFF2E2416),
    warningBorder: Color(0xFF5C4423),
    warningText: Color(0xFFFFB866),
    danger: Color(0xFFFF6B6F),
    success: Color(0xFF4CD483),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

extension AppColorsX on BuildContext {
  AppColors get c => Theme.of(this).extension<AppColors>()!;
}

const kFont = 'Pretendard';

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? AppColors.light : AppColors.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: c.brandPrimary,
    brightness: b,
  ).copyWith(
    primary: c.brandPrimary,
    onPrimary: c.brandOnPrimary,
    surface: c.bgScreen,
    onSurface: c.textPrimary,
    error: c.danger,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    fontFamily: kFont,
    scaffoldBackgroundColor: c.bgScreen,
    extensions: [c],
    splashFactory: InkRipple.splashFactory,
    appBarTheme: AppBarTheme(
      backgroundColor: c.bgScreen,
      foregroundColor: c.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleSpacing: 0,
      titleTextStyle: TextStyle(
        fontFamily: kFont,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: c.textPrimary,
      ),
    ),
    dividerColor: c.borderDefault,
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.bgScreen,
      modalBackgroundColor: c.bgScreen,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.bgScreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.inverseBg,
      contentTextStyle: TextStyle(fontFamily: kFont, color: c.inverseText),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surfaceSubtle,
      hintStyle: TextStyle(color: c.textSecondary, fontSize: 15),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c.brandPrimary, width: 1.5),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.brandPrimary),
  );
}
