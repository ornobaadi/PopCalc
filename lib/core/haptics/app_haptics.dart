import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One haptic primitive in a pattern. [delayMs] is the gap before it.
class _Hit {
  final String primitive;
  final double scale;
  final int delayMs;

  const _Hit(this.primitive, this.scale, [this.delayMs = 0]);

  Map<String, Object> toMap() => {'p': primitive, 's': scale, 'd': delayMs};
}

/// Semantic haptic vocabulary. Each kind of interaction gets its own
/// distinct "feel", designed to match its sound effect.
///
/// On Android this drives the native haptic engine (MainActivity's
/// `popcalc/haptics` channel): composed primitives on capable motors, with
/// amplitude-scaled pulses as a fallback. That's far crisper and stronger
/// than Flutter's [HapticFeedback], which is used on other platforms or if
/// the native call fails.
class AppHaptics {
  static bool enabled = true;

  /// 0-1 user strength multiplier (settings slider).
  static double strength = 1.0;

  static const _channel = MethodChannel('popcalc/haptics');

  /// Set false after a failed native call so we don't retry every tap.
  static bool _nativeAvailable = true;

  static bool get _useNative =>
      _nativeAvailable &&
      !kIsWeb &&
      defaultTargetPlatform == TargetPlatform.android;

  static void _play(List<_Hit> hits, VoidCallback fallback) {
    if (!enabled || strength <= 0) return;
    if (!_useNative) {
      fallback();
      return;
    }
    _channel
        .invokeMethod<bool>('play', {
          'hits': [for (final h in hits) h.toMap()],
          'strength': strength,
        })
        .then((played) {
          if (played != true) fallback();
        })
        .catchError((Object _) {
          _nativeAvailable = false;
          fallback();
        });
  }

  // ─── General UI ────────────────────────────────────────────────────────────

  /// Toggles, list taps, slider detents: a light, crisp tick.
  static void selectionClick() =>
      _play(const [_Hit('tick', 0.6)], HapticFeedback.selectionClick);

  static void lightImpact() =>
      _play(const [_Hit('click', 0.5)], HapticFeedback.lightImpact);

  static void mediumImpact() =>
      _play(const [_Hit('click', 0.85)], HapticFeedback.mediumImpact);

  static void heavyImpact() =>
      _play(const [_Hit('thud', 1.0)], HapticFeedback.heavyImpact);

  // ─── Keypad ────────────────────────────────────────────────────────────────

  /// Digits & decimal: a firm, crisp key click.
  static void digit() =>
      _play(const [_Hit('click', 0.75)], HapticFeedback.lightImpact);

  /// Operators: a heavier double "clack" so they feel different by touch.
  static void operatorKey() => _play(
        const [_Hit('click', 1.0), _Hit('tick', 0.6, 35)],
        HapticFeedback.mediumImpact,
      );

  /// %, +/-: a light tick.
  static void utility() =>
      _play(const [_Hit('tick', 0.9)], HapticFeedback.selectionClick);

  /// Backspace: a soft low tick, like something being taken away.
  static void backspace() =>
      _play(const [_Hit('lowTick', 1.0)], HapticFeedback.selectionClick);

  /// Clear: a ratcheting "skrrr" that fades out, then lands — in sync with
  /// the clear sound's sweep.
  static void clear() => _play(
        const [
          _Hit('lowTick', 1.0),
          _Hit('lowTick', 0.9, 22),
          _Hit('lowTick', 0.8, 22),
          _Hit('lowTick', 0.7, 22),
          _Hit('lowTick', 0.6, 22),
          _Hit('thud', 0.8, 40),
        ],
        HapticFeedback.heavyImpact,
      );

  // ─── Scientific keys ───────────────────────────────────────────────────────
  // As firm as the main keypad. Each kind of key gets the shape of its
  // sound: a click to carry it, then a second hit that rises, falls or
  // repeats with the melody.

  /// sin, cos, tan: a click and an echo, up and back like a wave.
  static void trig() => _play(const [
    _Hit('click', 0.85),
    _Hit('tick', 0.9, 34),
    _Hit('tick', 0.6, 34),
  ], HapticFeedback.lightImpact);

  /// ln, log: one full, settled click with a low body.
  static void log() => _play(const [
    _Hit('click', 0.9),
    _Hit('lowTick', 1.0, 20),
  ], HapticFeedback.lightImpact);

  /// xʸ, x², eˣ, 10ˣ: two clicks stepping up in strength.
  static void power() => _play(const [
    _Hit('click', 0.7),
    _Hit('click', 1.0, 40),
  ], HapticFeedback.mediumImpact);

  /// √, ∛: the mirror of power, a strong click stepping down.
  static void root() => _play(const [
    _Hit('click', 1.0),
    _Hit('click', 0.7, 40),
  ], HapticFeedback.mediumImpact);

  /// "(" lands light-to-firm, ")" firm-to-light, so pairs feel matched.
  static void bracketOpen() => _play(const [
    _Hit('tick', 0.8),
    _Hit('click', 0.9, 24),
  ], HapticFeedback.lightImpact);

  static void bracketClose() => _play(const [
    _Hit('click', 0.9),
    _Hit('tick', 0.8, 24),
  ], HapticFeedback.lightImpact);

  /// π, e: a click with a bright tick on top, a sparkle.
  static void constant() => _play(const [
    _Hit('click', 0.8),
    _Hit('tick', 1.0, 30),
  ], HapticFeedback.lightImpact);

  /// !: three quick knocks, the last one hardest.
  static void factorial() => _play(const [
    _Hit('click', 0.6),
    _Hit('click', 0.75, 30),
    _Hit('click', 1.0, 30),
  ], HapticFeedback.mediumImpact);

  /// 2nd, DEG/RAD and other two-state switches: climbs switching on,
  /// drops switching off.
  static void shift(bool on) => _play(
    on
        ? const [_Hit('tick', 0.8), _Hit('click', 1.0, 35)]
        : const [_Hit('click', 1.0), _Hit('tick', 0.8, 35)],
    HapticFeedback.lightImpact,
  );

  /// Opening (on) or leaving (off) the scientific tray or converter.
  static void mode(bool on) => _play(
    on
        ? const [_Hit('quickRise', 1.0), _Hit('click', 1.0, 50)]
        : const [_Hit('quickFall', 1.0), _Hit('click', 0.8, 40)],
    HapticFeedback.mediumImpact,
  );

  // ─── Unit converter ────────────────────────────────────────────────────────

  /// Swap: a spin timed with the button's half-turn, then a firm landing.
  static void swap() => _play(const [
    _Hit('spin', 1.0),
    _Hit('click', 1.0, 90),
  ], HapticFeedback.mediumImpact);

  /// Category tabs: a firm key-like click.
  static void category() =>
      _play(const [_Hit('click', 0.8)], HapticFeedback.lightImpact);

  /// Picking a unit: one strong, confident click.
  static void unitPick() =>
      _play(const [_Hit('click', 1.0)], HapticFeedback.mediumImpact);

  /// One notch of a swipe-to-step control (units, categories): a crisp
  /// click, like a slider snapping into place.
  static void detent() =>
      _play(const [_Hit('click', 0.8)], HapticFeedback.selectionClick);

  /// Swiped past the last notch: a solid bump against the end stop.
  static void detentEnd() =>
      _play(const [_Hit('thud', 1.0)], HapticFeedback.mediumImpact);

  // ─── Results ───────────────────────────────────────────────────────────────

  /// Answer lands: a rising swell into a strong click and a sparkle tick,
  /// timed with the success chime and the pop animation.
  static void success() => _play(
        const [
          _Hit('quickRise', 0.7),
          _Hit('click', 1.0, 40),
          _Hit('tick', 0.6, 90),
        ],
        HapticFeedback.heavyImpact,
      );

  /// Error: three hard knocks, synced with the shake.
  static void error() => _play(
        const [
          _Hit('thud', 1.0),
          _Hit('thud', 1.0, 60),
          _Hit('thud', 1.0, 60),
        ],
        HapticFeedback.vibrate,
      );
}
