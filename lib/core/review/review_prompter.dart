import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides when to show Google Play's own review card (In-App Review API).
///
/// The card is only ever offered at a moment that already feels good, never
/// to someone who has just met the app, and rarely:
///   * the moment the newsroom case is cracked (the biggest high there is);
///   * a quiet answer once PopCalc has become a habit: the 30th and the
///     150th answer, and only after it was used on 3 different days.
/// Never right after an error, never twice within [_gap], at most [_maxAsks]
/// times ever. Play adds its own quota on top and may show nothing at all,
/// so asking is always fire-and-forget.
class ReviewPrompter {
  ReviewPrompter._();

  static const _kAnswers = 'review_answers';
  static const _kDays = 'review_days';
  static const _kLastDay = 'review_last_day';
  static const _kAsks = 'review_asks';
  static const _kLastAsk = 'review_last_ask';
  static const _kAskedAtCase = 'review_asked_case';

  static const answerMilestones = {30, 150};
  static const minDays = 3;
  static const _maxAsks = 3;
  static const _gap = Duration(days: 30);

  /// Swappable for tests; Play's card in the real app.
  @visibleForTesting
  static Future<void> Function() request = _playCard;

  /// Swappable for tests.
  @visibleForTesting
  static DateTime Function() now = DateTime.now;

  static Future<void> _playCard() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {
      // No Play services (or a test run): nothing to show.
    }
  }

  /// A successful `=`. Returns true when this answer earned the card; the
  /// caller shows it once the celebration has finished and the user is idle.
  static Future<bool> onAnswer() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _dayStamp(now());
    if (prefs.getInt(_kLastDay) != today) {
      await prefs.setInt(_kLastDay, today);
      await prefs.setInt(_kDays, (prefs.getInt(_kDays) ?? 0) + 1);
    }
    final answers = (prefs.getInt(_kAnswers) ?? 0) + 1;
    await prefs.setInt(_kAnswers, answers);
    if (!answerMilestones.contains(answers)) return false;
    if ((prefs.getInt(_kDays) ?? 0) < minDays) return false;
    return _mayAsk(prefs);
  }

  /// The case is closed and Newsprint is on. Asked once, ever.
  static Future<bool> onCaseClosed() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kAskedAtCase) ?? false) return false;
    return _mayAsk(prefs);
  }

  /// Shows the card and books the ask. Call only after [onAnswer] or
  /// [onCaseClosed] said yes, and only if the user is still idle (a key
  /// pressed in the meantime calls it off, and the moment is not used up).
  static Future<void> ask({bool atCase = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (atCase) await prefs.setBool(_kAskedAtCase, true);
    await prefs.setInt(_kAsks, (prefs.getInt(_kAsks) ?? 0) + 1);
    await prefs.setInt(_kLastAsk, now().millisecondsSinceEpoch);
    await request();
  }

  static bool _mayAsk(SharedPreferences prefs) {
    if ((prefs.getInt(_kAsks) ?? 0) >= _maxAsks) return false;
    final last = prefs.getInt(_kLastAsk);
    if (last == null) return true;
    final since = now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    return since >= _gap;
  }

  static int _dayStamp(DateTime t) => t.year * 10000 + t.month * 100 + t.day;

  /// Settings' "Rate PopCalc" row: the user asked, so straight to the store.
  static Future<void> openStore() async {
    try {
      await InAppReview.instance.openStoreListing();
    } catch (_) {}
  }
}
