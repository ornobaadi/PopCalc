import 'package:flutter/services.dart';

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
}
