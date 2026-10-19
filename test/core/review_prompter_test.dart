import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/review/review_prompter.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DateTime clock;
  late int shown;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    clock = DateTime(2026, 10, 20, 12);
    shown = 0;
    ReviewPrompter.now = () => clock;
    ReviewPrompter.request = () async => shown++;
  });

  Future<List<int>> answers(int n) async {
    final earned = <int>[];
    for (var i = 1; i <= n; i++) {
      if (await ReviewPrompter.onAnswer()) earned.add(i);
    }
    return earned;
  }

  test('a newcomer is never asked, however many answers on day one',
      () async {
    expect(await answers(200), isEmpty);
  });

  test('the 30th answer earns the card once PopCalc is used on 3 days',
      () async {
    await answers(10);
    clock = clock.add(const Duration(days: 1));
    await answers(10);
    clock = clock.add(const Duration(days: 1));
    expect(await answers(10), [10]); // the 30th overall
    await ReviewPrompter.ask();
    expect(shown, 1);
  });

  test('cracking the case earns it once, ever', () async {
    expect(await ReviewPrompter.onCaseClosed(), isTrue);
    await ReviewPrompter.ask(atCase: true);
    expect(await ReviewPrompter.onCaseClosed(), isFalse);
  });

  test('a moment not used (user kept typing) is not spent', () async {
    expect(await ReviewPrompter.onCaseClosed(), isTrue);
    expect(await ReviewPrompter.onCaseClosed(), isTrue);
  });

  test('never twice within 30 days', () async {
    await ReviewPrompter.ask(atCase: true);
    for (var d = 0; d < 3; d++) {
      clock = clock.add(const Duration(days: 1));
      await answers(10);
    }
    // 30th answer, three days in, but only 3 days after the last card.
    expect(await ReviewPrompter.onAnswer(), isFalse);
  });

  test('at most three cards ever', () async {
    for (var i = 0; i < 3; i++) {
      await ReviewPrompter.ask();
      clock = clock.add(const Duration(days: 40));
    }
    // Forty days on, the gap is long past, but three is the limit.
    expect(await ReviewPrompter.onCaseClosed(), isFalse);
  });
}
