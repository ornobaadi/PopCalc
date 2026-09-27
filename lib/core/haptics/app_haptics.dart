import 'package:flutter/services.dart';

/// Semantic haptic vocabulary. Each kind of interaction gets its own
/// distinct "feel" so users can tell keys apart without looking.
class AppHaptics {
  static bool enabled = true;

  static void selectionClick() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void lightImpact() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void mediumImpact() {
    if (enabled) HapticFeedback.mediumImpact();
  }

  static void heavyImpact() {
    if (enabled) HapticFeedback.heavyImpact();
  }

  static void vibrate() {
    if (enabled) HapticFeedback.vibrate();
  }

  // ─── Semantic patterns ─────────────────────────────────────────────────────

  /// Digits & decimal: crisp, light tick like a typewriter key.
  static void digit() => lightImpact();

  /// Operators: slightly firmer so they feel "heavier" than digits.
  static void operatorKey() => mediumImpact();

  /// Utility keys (%, +/-, backspace): subtle click.
  static void utility() => selectionClick();

  /// Clear: a solid thunk.
  static void clear() => heavyImpact();

  /// Successful evaluation: a rising "da-DUM" double pulse that lands
  /// in sync with the result pop + burst animation.
  static Future<void> success() async {
    if (!enabled) return;
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 70));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 110));
    HapticFeedback.selectionClick();
  }

  /// Error: a stuttering triple buzz synced with the shake.
  static Future<void> error() async {
    if (!enabled) return;
    for (var i = 0; i < 3; i++) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }
}
