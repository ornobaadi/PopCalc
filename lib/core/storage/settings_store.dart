import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool showLivePreview;
  final bool hapticsEnabled;
  final bool liteMode;

  const AppSettings({
    this.showLivePreview = false,
    this.hapticsEnabled = true,
    this.liteMode = false,
  });

  AppSettings copyWith({
    bool? showLivePreview,
    bool? hapticsEnabled,
    bool? liteMode,
  }) {
    return AppSettings(
      showLivePreview: showLivePreview ?? this.showLivePreview,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      liteMode: liteMode ?? this.liteMode,
    );
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  static const _kShowLivePreview = 'settings_show_live_preview';
  static const _kHapticsEnabled = 'settings_haptics_enabled';
  static const _kLiteMode = 'settings_lite_mode';

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppSettings(
        showLivePreview: prefs.getBool(_kShowLivePreview) ?? false,
        hapticsEnabled: prefs.getBool(_kHapticsEnabled) ?? true,
        liteMode: prefs.getBool(_kLiteMode) ?? false,
      );
    } catch (_) {}
  }

  Future<void> setShowLivePreview(bool value) async {
    state = state.copyWith(showLivePreview: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kShowLivePreview, value);
    } catch (_) {}
  }

  Future<void> setHapticsEnabled(bool value) async {
    state = state.copyWith(hapticsEnabled: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHapticsEnabled, value);
    } catch (_) {}
  }

  Future<void> setLiteMode(bool value) async {
    state = state.copyWith(liteMode: value);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kLiteMode, value);
    } catch (_) {}
  }
}
