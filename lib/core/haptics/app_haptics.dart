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
