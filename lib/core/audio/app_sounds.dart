import 'dart:async';
import 'dart:math';

import 'package:flutter_soloud/flutter_soloud.dart';

/// Selectable sound packs. Every pack ships the same file names
/// (see tool/generate_sounds.py), so they can be swapped freely.
enum SoundPack {
  pop('Pop', 'Bubbly pops that play a melody as you type'),
  mellow('Mellow', 'Soft, warm marimba tones'),
  typewriter('Typewriter', 'Mechanical keys with a carriage bell');

  final String label;
  final String description;
  const SoundPack(this.label, this.description);

  static SoundPack fromName(String? name) =>
      SoundPack.values.firstWhere((p) => p.name == name, orElse: () => pop);
}

/// Every effect the app can play.
enum Sfx {
  digit0,
  digit1,
  digit2,
  digit3,
  digit4,
  digit5,
  digit6,
  digit7,
  digit8,
  digit9,
  operator,
  utility,
  backspace,
  clear,
  success,
  error;

  bool get isDigit => index <= 9;

  /// File name: "digit_3", "clear", ...
  String get file => isDigit ? 'digit_$index' : name;

  static Sfx digit(String d) => Sfx.values[int.parse(d)];
}

/// UI sound effects on the SoLoud engine: every sound is decoded into memory
/// up front and [SoLoud.play] is synchronous, so key sounds start within one
/// audio buffer of the touch and overlapping presses never cut each other off.
///
/// Mirrors [AppHaptics]: static and fire-and-forget. Everything is a silent
/// no-op until [init] succeeds (so tests never touch the native engine).
class AppSounds {
  static bool _ready = false;
  static bool _enabled = true;
  static double _volume = 0.5;
  static SoundPack _pack = SoundPack.pop;

  /// All packs stay loaded (~1 MB total) so switching and previewing packs
  /// is instant.
  static final Map<SoundPack, Map<Sfx, AudioSource>> _sources = {};

  /// PopCalc's launch sound (the typewriter "skrr"), used for every pack.
  static AudioSource? _launch;
  static DateTime? _launchPendingAt;

  /// Mechanical detent tick for swipe-to-step controls: one sound for
  /// every pack, like a slider clicking into notches.
  static AudioSource? _detent;
  static DateTime _lastDetent = DateTime(0);

  /// A sound requested before it finished loading.
  /// Played as soon as it's ready, unless it has gone stale.
  static Sfx? _pendingSfx;
  static DateTime? _pendingAt;
  static const _pendingTtl = Duration(milliseconds: 1200);

  /// Stereo position for the sound being triggered (see [panned]).
  static double _pan = 0.0;

  // Backspace "wind-down": each quick repeat plays a little lower.
  static int _backspaceStreak = 0;
  static DateTime _lastBackspace = DateTime(0);

  static final _random = Random();

  static bool get enabled => _enabled;
  static double get volume => _volume;
  static SoundPack get pack => _pack;

  /// Starts the engine, then loads sounds in the background — the
  /// launch sound first, so the splash can play it immediately.
  static Future<void> init({
    required bool enabled,
    required double volume,
    required SoundPack pack,
  }) async {
    _enabled = enabled;
    _volume = volume.clamp(0.0, 1.0);
    _pack = pack;
    try {
      // 1024 frames ≈ 23 ms: snappy, with headroom against crackle on
      // low-end devices. Plays on the media stream and never takes audio
      // focus, so the user's own music keeps playing.
      await SoLoud.instance.init(bufferSize: 1024);
      SoLoud.instance.setMaxActiveVoiceCount(32);
      _ready = true;
    } catch (_) {
      return; // No audio device: the app simply stays silent.
    }
    unawaited(_loadAll());
  }

  static Future<void> _loadAll() async {
    // Launch sound first so the splash can play it, then the current pack,
    // then the rest for previews.
    try {
      _launch = await SoLoud.instance.loadAsset('assets/sounds/launch.wav');
      final at = _launchPendingAt;
      _launchPendingAt = null;
      if (at != null && DateTime.now().difference(at) <= _pendingTtl) {
        launch();
      }
    } catch (_) {}
    try {
      _detent = await SoLoud.instance.loadAsset('assets/sounds/detent.wav');
    } catch (_) {}
    final order = [_pack, ...SoundPack.values.where((p) => p != _pack)];
    for (final pack in order) {
      for (final sfx in Sfx.values) {
        try {
          final source = await SoLoud.instance.loadAsset(
            'assets/sounds/${pack.name}/${sfx.file}.wav',
          );
          (_sources[pack] ??= {})[sfx] = source;
          if (pack == _pack && _pendingSfx == sfx) _flushPending();
        } catch (_) {
          // A missing/corrupt file only silences that one sound.
        }
      }
    }
  }

  static void configure({bool? enabled, double? volume, SoundPack? pack}) {
    _enabled = enabled ?? _enabled;
    _volume = (volume ?? _volume).clamp(0.0, 1.0);
    _pack = pack ?? _pack;
  }

  /// The sound files are mastered loud, so the slider's 100% maps to 40% of
  /// the engine's full gain (old 20% is the new 50%, old 40% the new 100%).
  static const double _maxGain = 0.4;
  static double get _gain => _volume * _maxGain;

  static bool get _canPlay => _ready && _enabled && _volume > 0;

  static void _playSource(AudioSource source, {double pitch = 1.0}) {
    try {
      if (pitch == 1.0) {
        SoLoud.instance.play(source, volume: _gain, pan: _pan);
        return;
      }
      // Start paused so the pitch applies from the very first sample.
      final handle = SoLoud.instance.play(
        source,
        volume: _gain,
        pan: _pan,
        paused: true,
      );
      SoLoud.instance.setRelativePlaySpeed(handle, pitch);
      SoLoud.instance.setPause(handle, false);
    } catch (_) {}
  }

  static void _flushPending() {
    final sfx = _pendingSfx;
    final at = _pendingAt;
    _pendingSfx = null;
    _pendingAt = null;
    if (sfx == null || at == null) return;
    if (DateTime.now().difference(at) > _pendingTtl) return;
    play(sfx);
  }

  /// Small random pitch drift keeps repeated non-melodic sounds from feeling
  /// robotic. Digits stay exact so typing still plays a clean melody.
  static double _pitchFor(Sfx sfx) {
    if (sfx.isDigit || sfx == Sfx.success) {
      return 1.0;
    }
    if (sfx == Sfx.backspace) {
      final now = DateTime.now();
      if (now.difference(_lastBackspace) > const Duration(milliseconds: 600)) {
        _backspaceStreak = 0;
      }
      _lastBackspace = now;
      final pitch = max(0.8, 1.0 - _backspaceStreak * 0.03);
      _backspaceStreak++;
      return pitch;
    }
    return 0.96 + _random.nextDouble() * 0.08;
  }

  static void play(Sfx sfx) {
    if (!_canPlay) return;
    final source = _sources[_pack]?[sfx];
    if (source != null) _playSource(source, pitch: _pitchFor(sfx));
  }

  /// Plays [sfx] [semitones] away from its recorded pitch, with no drift,
  /// so a series of taps can walk a scale.
  /// One notch of a swipe-to-step control. Stepping up clicks a touch
  /// higher than stepping down; fast swipes are thinned out so the ticks
  /// never blur into a buzz.
  static void detent({bool up = true}) {
    if (!_canPlay) return;
    final source = _detent;
    if (source == null) return;
    final now = DateTime.now();
    if (now.difference(_lastDetent) < const Duration(milliseconds: 40)) return;
    _lastDetent = now;
    _playSource(
      source,
      pitch: (up ? 1.05 : 0.95) + (_random.nextDouble() - 0.5) * 0.04,
    );
  }

  /// Like [play], but if the sound is still loading (e.g. at app launch),
  /// plays it the moment it's ready.
  static void playWhenReady(Sfx sfx) {
    if (!_enabled || _volume == 0) return;
    if (_sources[_pack]?[sfx] != null && _ready) {
      play(sfx);
    } else {
      _pendingSfx = sfx;
      _pendingAt = DateTime.now();
    }
  }

  /// The launch "skrr", played the moment it's loaded if the splash asks
  /// before it's ready.
  static void launch() {
    if (!_enabled || _volume == 0) return;
    final source = _launch;
    if (source != null && _ready) {
      _playSource(source);
    } else {
      _launchPendingAt = DateTime.now();
    }
  }

  /// Instantly previews [pack] (all packs are preloaded).
  static void previewPack(SoundPack pack) {
    if (!_canPlay) return;
    final source = _sources[pack]?[Sfx.success];
    if (source != null) _playSource(source);
  }

  /// Runs [trigger] with the sound positioned in the stereo field, e.g. by
  /// where on screen the key was pressed. Subtle, so mono speakers are fine.
  static void panned(double pan, void Function() trigger) {
    _pan = pan.clamp(-1.0, 1.0);
    try {
      trigger();
    } finally {
      _pan = 0.0;
    }
  }

  // Convenience wrappers matching the haptic vocabulary.
  static void digit(String d) => play(Sfx.digit(d));
  static void operatorKey() => play(Sfx.operator);
  static void utility() => play(Sfx.utility);
  static void backspace() => play(Sfx.backspace);
  static void clear() => play(Sfx.clear);
  static void success() => play(Sfx.success);
  static void error() => play(Sfx.error);
}
