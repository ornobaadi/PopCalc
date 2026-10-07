import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';

class AppSettings {
  final bool showLivePreview;
  final bool hapticsEnabled;
  final double hapticStrength;
  final bool liteMode;
  final bool soundEnabled;
  final double soundVolume;
  final SoundPack soundPack;
  /// Makes the scientific calculator available (Settings switch).
  final bool scientificMode;
  /// Whether the scientific tray is showing right now; flipped from the
  /// top bar so users can hop between simple and scientific.
  final bool scientificActive;
  /// Whether the scientific tray shows both rows or just the first.
  final bool scientificExpanded;
  /// Adds the unit converter screen, opened from the top bar.
  final bool converterEnabled;
  final AngleUnit angleUnit;

  const AppSettings({
    this.showLivePreview = false,
    this.hapticsEnabled = true,
    this.hapticStrength = 1.0,
    this.liteMode = false,
    this.soundEnabled = true,
    this.soundVolume = 0.5,
    this.soundPack = SoundPack.pop,
    this.scientificMode = false,
    this.scientificActive = true,
    this.scientificExpanded = true,
    this.converterEnabled = false,
    this.angleUnit = AngleUnit.degrees,
  });

  AppSettings copyWith({
    bool? showLivePreview,
    bool? hapticsEnabled,
    double? hapticStrength,
    bool? liteMode,
    bool? soundEnabled,
    double? soundVolume,
    SoundPack? soundPack,
    bool? scientificMode,
    bool? scientificActive,
    bool? scientificExpanded,
    bool? converterEnabled,
    AngleUnit? angleUnit,
  }) {
    return AppSettings(
      showLivePreview: showLivePreview ?? this.showLivePreview,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      hapticStrength: hapticStrength ?? this.hapticStrength,
      liteMode: liteMode ?? this.liteMode,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      soundVolume: soundVolume ?? this.soundVolume,
      soundPack: soundPack ?? this.soundPack,
      scientificMode: scientificMode ?? this.scientificMode,
      scientificActive: scientificActive ?? this.scientificActive,
      scientificExpanded: scientificExpanded ?? this.scientificExpanded,
      converterEnabled: converterEnabled ?? this.converterEnabled,
      angleUnit: angleUnit ?? this.angleUnit,
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
  static const _kHapticStrength = 'settings_haptic_strength';
  static const _kLiteMode = 'settings_lite_mode';
  static const _kSoundEnabled = 'settings_sound_enabled';
  // v2: default dropped to 50% so full media volume never blasts; the new
  // key resets test builds that saved the old louder default.
  static const _kSoundVolume = 'settings_sound_volume_v2';
  static const _kSoundPack = 'settings_sound_pack';
  static const _kScientificMode = 'settings_scientific_mode';
  static const _kScientificActive = 'settings_scientific_active';
  static const _kScientificExpanded = 'settings_scientific_expanded';
  static const _kConverterEnabled = 'settings_converter_enabled';
  static const _kAngleUnit = 'settings_angle_unit';

  /// Starts the sound engine with saved settings before the first frame,
  /// so the splash screen's launch sound respects the user's choices.
  static Future<void> initAudio() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await AppSounds.init(
        enabled: prefs.getBool(_kSoundEnabled) ?? true,
        volume: prefs.getDouble(_kSoundVolume) ?? 0.5,
        pack: SoundPack.fromName(prefs.getString(_kSoundPack)),
      );
    } catch (_) {
      await AppSounds.init(enabled: true, volume: 0.5, pack: SoundPack.pop);
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      state = AppSettings(
        showLivePreview: prefs.getBool(_kShowLivePreview) ?? false,
        hapticsEnabled: prefs.getBool(_kHapticsEnabled) ?? true,
        hapticStrength: prefs.getDouble(_kHapticStrength) ?? 1.0,
        liteMode: prefs.getBool(_kLiteMode) ?? false,
        soundEnabled: prefs.getBool(_kSoundEnabled) ?? true,
        soundVolume: prefs.getDouble(_kSoundVolume) ?? 0.5,
        soundPack: SoundPack.fromName(prefs.getString(_kSoundPack)),
        scientificMode: prefs.getBool(_kScientificMode) ?? false,
        scientificActive: prefs.getBool(_kScientificActive) ?? true,
        scientificExpanded: prefs.getBool(_kScientificExpanded) ?? true,
        converterEnabled: prefs.getBool(_kConverterEnabled) ?? false,
        angleUnit: AngleUnit.fromName(prefs.getString(_kAngleUnit)),
      );
      AppHaptics.enabled = state.hapticsEnabled;
      AppHaptics.strength = state.hapticStrength;
      _applyAudio();
    } catch (_) {}
  }

  void _applyAudio() {
    AppSounds.configure(
      enabled: state.soundEnabled,
      volume: state.soundVolume,
      pack: state.soundPack,
    );
  }

  Future<void> _persist(Future<void> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  /// Applies live while dragging; call [saveHapticStrength] when it ends.
  void setHapticStrength(double value) {
    state = state.copyWith(hapticStrength: value);
    AppHaptics.strength = value;
  }

  Future<void> saveHapticStrength() =>
      _persist((p) => p.setDouble(_kHapticStrength, state.hapticStrength));

  Future<void> setSoundEnabled(bool value) async {
    state = state.copyWith(soundEnabled: value);
    _applyAudio();
    await _persist((p) => p.setBool(_kSoundEnabled, value));
  }

  /// Applies live while dragging; call [saveSoundVolume] when the drag ends.
  void setSoundVolume(double value) {
    state = state.copyWith(soundVolume: value);
    _applyAudio();
  }

  Future<void> saveSoundVolume() =>
      _persist((p) => p.setDouble(_kSoundVolume, state.soundVolume));

  Future<void> setSoundPack(SoundPack pack) async {
    state = state.copyWith(soundPack: pack);
    _applyAudio();
    await _persist((p) => p.setString(_kSoundPack, pack.name));
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
    AppHaptics.enabled = value;
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

  /// Turning the feature on also shows the tray, so the switch has a
  /// visible effect straight away.
  Future<void> setScientificMode(bool value) async {
    state = state.copyWith(
      scientificMode: value,
      scientificActive: value ? true : null,
    );
    await _persist((p) async {
      await p.setBool(_kScientificMode, value);
      if (value) await p.setBool(_kScientificActive, true);
    });
  }

  Future<void> setScientificActive(bool value) async {
    state = state.copyWith(scientificActive: value);
    await _persist((p) => p.setBool(_kScientificActive, value));
  }

  Future<void> setScientificExpanded(bool value) async {
    state = state.copyWith(scientificExpanded: value);
    await _persist((p) => p.setBool(_kScientificExpanded, value));
  }

  Future<void> setConverterEnabled(bool value) async {
    state = state.copyWith(converterEnabled: value);
    await _persist((p) => p.setBool(_kConverterEnabled, value));
  }

  Future<void> setAngleUnit(AngleUnit unit) async {
    state = state.copyWith(angleUnit: unit);
    await _persist((p) => p.setString(_kAngleUnit, unit.name));
  }
}
