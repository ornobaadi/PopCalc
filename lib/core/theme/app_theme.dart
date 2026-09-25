import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme_tokens.dart';

import 'package:shared_preferences/shared_preferences.dart';

final themeProvider =
    StateNotifierProvider<ThemeNotifier, AppThemeMode>((ref) {
  return ThemeNotifier();
});

class ThemeNotifier extends StateNotifier<AppThemeMode> {
  static const _kThemeKey = 'settings_theme_mode';

  ThemeNotifier() : super(AppThemeMode.sunny) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final index = prefs.getInt(_kThemeKey);
      if (index != null && index >= 0 && index < AppThemeMode.values.length) {
        state = AppThemeMode.values[index];
      }
    } catch (_) {}
  }

  void toggleTheme() {
    state = state == AppThemeMode.ink ? AppThemeMode.sunny : AppThemeMode.ink;
    _saveTheme(state);
  }

  void setTheme(AppThemeMode mode) {
    state = mode;
    _saveTheme(state);
  }

  Future<void> _saveTheme(AppThemeMode mode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kThemeKey, mode.index);
    } catch (_) {}
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
