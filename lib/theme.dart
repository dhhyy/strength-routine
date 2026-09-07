import 'package:flutter/material.dart';
import 'tokens.dart';

/// Console v2 테마 — 토큰을 ThemeData로 묶어 모든 위젯이 상속받게 한다.
ThemeData buildConsoleTheme() {
  final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.bg,
    dividerColor: AppColors.hair,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      surface: AppColors.bgLift,
      onSurface: AppColors.ink,
    ),
    textTheme: base.textTheme.apply(
      fontFamily: 'IBM Plex Sans KR',
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.navBg,
      indicatorColor: AppColors.navIndicator,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => kr(
          size: 10.5,
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          size: 22,
          color: s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
      ),
    ),
  );
}
