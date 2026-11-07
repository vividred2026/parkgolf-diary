import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  // 2027 Friends Screen Library 색 (Color.Primitive / Color.Semantic).
  // 라이브러리에는 다크 값이 없어 다크는 같은 회색 단계로 만들었어요.
  static const light = AppColors(
    bgScreen: Color(0xFFFFFFFF), // common/white
    surfaceDefault: Color(0xFFFFFFFF),
    surfaceSubtle: Color(0xFFF6F8F9), // gray/50
    surfacePlaceholder: Color(0xFFD0D7DC), // gray/200
    surfaceSelected: Color(0xFFE9F8EF), // primary-green/100
    borderDefault: Color(0xFFECEFF1), // gray/100 (border/primary)
    textPrimary: Color(0xFF101214), // gray/900 (contents/primary)
    textSecondary: Color(0xFF6C7883), // gray/500 (contents/secondary)
    textDisabled: Color(0xFFADB9C2), // gray/300 (contents/tertiary)
    brandPrimary: Color(0xFF22BB5F), // primary-green/600
    brandOnPrimary: Color(0xFFFFFFFF),
    inverseBg: Color(0xFF101214),
    inverseText: Color(0xFFFFFFFF),
    warningBg: Color(0xFFFFF8EE),
    warningBorder: Color(0xFFFFD9A8),
    warningText: Color(0xFFB35900),
    danger: Color(0xFFFA5E4C), // functional/s5 (contents/error)
    success: Color(0xFF22BB5F),
  );

  static const dark = AppColors(
    bgScreen: Color(0xFF101214), // gray/900
    surfaceDefault: Color(0xFF101214),
    surfaceSubtle: Color(0xFF272C30), // gray/800
    surfacePlaceholder: Color(0xFF3E454B), // gray/700
    surfaceSelected: Color(0xFF272C30), // gray/800
    borderDefault: Color(0xFF3E454B), // gray/700
    textPrimary: Color(0xFFF6F8F9), // gray/50
    textSecondary: Color(0xFFADB9C2), // gray/300
    textDisabled: Color(0xFF555F67), // gray/600
    brandPrimary: Color(0xFF22BB5F), // primary-green/600
    brandOnPrimary: Color(0xFFFFFFFF),
    inverseBg: Color(0xFFF6F8F9),
    inverseText: Color(0xFF101214),
    warningBg: Color(0xFF2E2416),
    warningBorder: Color(0xFF5C4423),
    warningText: Color(0xFFFFB866),
    danger: Color(0xFFFA5E4C),
    success: Color(0xFF22BB5F),
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

/// 상태바 · 하단 내비게이션 바: 투명 배경 + 화면 모드에 맞는 아이콘 색.
SystemUiOverlayStyle systemBarsStyle(Brightness b) {
  final dark = b == Brightness.dark;
  return SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
    statusBarBrightness: b, // iOS
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
    systemNavigationBarIconBrightness: dark
        ? Brightness.light
        : Brightness.dark,
    systemNavigationBarContrastEnforced: false,
    systemStatusBarContrastEnforced: false,
  );
}

ThemeData buildTheme(Brightness b) {
  final c = b == Brightness.light ? AppColors.light : AppColors.dark;
  final scheme = ColorScheme.fromSeed(seedColor: c.brandPrimary, brightness: b)
      .copyWith(
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
      systemOverlayStyle: systemBarsStyle(b),
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
    // 라이브러리 toast: radius 8 · 14 Bold
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.inverseBg,
      contentTextStyle: TextStyle(
        fontFamily: kFont,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: c.inverseText,
      ),
      actionTextColor: c.inverseText,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
