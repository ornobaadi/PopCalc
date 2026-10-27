import 'package:flutter/services.dart';

/// What happened when Settings asked to add the Quick Settings tile.
enum QuickTileResult {
  added,
  alreadyAdded,
  declined,

  /// Android before 13 (or no system support): the user adds it by hand.
  manual,
}

/// The "PopCalc" Quick Settings tile (`PopCalcTileService.kt`) and the
/// `popcalc/qs_tile` channel in PopCalcActivity.kt that asks Android to add
/// it. Without a native side (tests, other platforms) it answers [manual].
class QuickTile {
  static const _channel = MethodChannel('popcalc/qs_tile');

  static Future<QuickTileResult> request() async {
    try {
      final code = await _channel.invokeMethod<int>('request');
      return switch (code) {
        2 => QuickTileResult.added,
        1 => QuickTileResult.alreadyAdded,
        0 => QuickTileResult.declined,
        _ => QuickTileResult.manual,
      };
    } catch (_) {
      return QuickTileResult.manual;
    }
  }

  /// Shown under the Settings row after each answer.
  static String noteFor(QuickTileResult result) => switch (result) {
    QuickTileResult.added =>
      'Added. Swipe down from the top of the screen and tap PopCalc.',
    QuickTileResult.alreadyAdded =>
      'It is already in your Quick Settings. Swipe down to find it.',
    QuickTileResult.declined =>
      'No tile added. Tap again whenever you want it.',
    QuickTileResult.manual =>
      'Swipe down twice from the top, tap the pencil (edit), '
          'then drag the PopCalc tile into your panel.',
  };
}
