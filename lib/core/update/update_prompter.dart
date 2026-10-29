import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Offers a newer PopCalc from Google Play, through Play's own in-app update
/// card. PopCalc stays fully offline: with no connection the check simply
/// fails and nothing shows.
///
/// The update downloads in the background while the calculator keeps working
/// (Play's "flexible" flow); it is installed at the next launch, so nobody is
/// thrown out of a calculation. A declined offer is not repeated for
/// [_patience].
class UpdatePrompter {
  static const _kLastAsk = 'update_last_ask';
  static const _patience = Duration(days: 3);

  /// Swapped in tests.
  static Future<AppUpdateInfo> Function() check = InAppUpdate.checkForUpdate;
  static Future<AppUpdateResult> Function() start = InAppUpdate.startFlexibleUpdate;
  static Future<void> Function() install = InAppUpdate.completeFlexibleUpdate;
  static DateTime Function() now = DateTime.now;

  /// Only Play-installed release builds can be updated by Play.
  static bool enabled = kReleaseMode && !kIsWeb && Platform.isAndroid;

  static Future<void> run() async {
    if (!enabled) return;
    try {
      final info = await check().timeout(const Duration(seconds: 8));
      // Downloaded last time: install now, at launch, before anything is typed.
      if (info.installStatus == InstallStatus.downloaded) {
        await install();
        return;
      }
      if (info.updateAvailability != UpdateAvailability.updateAvailable ||
          !info.flexibleUpdateAllowed) {
        return;
      }
      final prefs = await SharedPreferences.getInstance();
      final last = prefs.getInt(_kLastAsk);
      if (last != null &&
          now().difference(DateTime.fromMillisecondsSinceEpoch(last)) < _patience) {
        return;
      }
      await prefs.setInt(_kLastAsk, now().millisecondsSinceEpoch);
      await start();
    } catch (_) {
      // Offline, not installed from Play, or Play busy: stay quiet.
    }
  }
}
