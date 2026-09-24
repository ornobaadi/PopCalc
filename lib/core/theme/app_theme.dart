import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_tokens.dart';

final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  ThemeNotifier() : super(AppThemeMode.ink);

  void toggleTheme() {
    state = state == AppThemeMode.ink ? AppThemeMode.sunny : AppThemeMode.ink;
  }

  void setTheme(AppThemeMode mode) {
    state = mode;
  }
}

class AppTheme {
  static ThemeColors colorsOf(AppThemeMode mode) {
    return mode == AppThemeMode.ink ? ThemeColors.inkTheme : ThemeColors.sunnyTheme;
  }

  static ThemeData getThemeData(AppThemeMode mode) {
    final colors = colorsOf(mode);
    final isDark = mode == AppThemeMode.ink;

    return ThemeData(
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: colors.bg,
      fontFamily: 'BebasNeue',
      colorScheme: ColorScheme(
        brightness: isDark ? Brightness.dark : Brightness.light,
        primary: colors.accent,
        onPrimary: Colors.white,
        secondary: colors.accent,
        onSecondary: Colors.white,
        error: colors.accent,
        onError: Colors.white,
        surface: colors.bg,
        onSurface: colors.ink,
      ),
    );
  }
}
