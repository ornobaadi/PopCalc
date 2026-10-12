import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('Finding the secret skin', () {
    late ProviderContainer container;
    late CalculatorController calc;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      addTearDown(container.dispose);
      calc = container.read(calculatorProvider.notifier);
      container.read(settingsProvider);
      await settle();
    });

    void digits(String s) => s.split('').forEach(calc.onDigit);

    test('typing the answer itself and pressing = opens nothing', () async {
      digits('1337');
      calc.onEquals();
      await settle();
      expect(container.read(settingsProvider).secretUnlocked, isFalse);
      expect(container.read(themeProvider), AppThemeMode.sunny);
    });

    test('a calculation that comes out at it unlocks and puts it on', () async {
      digits('1000');
      calc.onOperator(TokenType.plus, '+');
      digits('337');
      calc.onEquals();
      await settle();

      expect(calc.state.resultText, kSecretAnswer);
      expect(container.read(settingsProvider).secretUnlocked, isTrue);
      expect(container.read(themeProvider), AppThemeMode.newsprint);
      expect(container.read(secretFoundProvider), 1);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_secret_unlocked'), isTrue);
    });

    test('it is only announced the first time', () async {
      for (var i = 0; i < 2; i++) {
        calc.onClear();
        digits('1338');
        calc.onOperator(TokenType.minus, '-');
        digits('1');
        calc.onEquals();
        await settle();
      }
      expect(container.read(secretFoundProvider), 1);
    });

    test('any other answer opens nothing', () async {
      digits('1000');
      calc.onOperator(TokenType.plus, '+');
      digits('338');
      calc.onEquals();
      await settle();
      expect(container.read(settingsProvider).secretUnlocked, isFalse);
    });
  });

  test('the secret skin is free, hidden from the store and not in the bundle',
      () {
    final secret = skinOf(AppThemeMode.newsprint);
    expect(secret.secret, isTrue);
    expect(secret.premium, isFalse);
    expect(ownsSkin(const {}, secret, locked: true), isTrue);
    expect(kBundleItems, isNot(contains(secret)));
    expect(kSkins, isNot(contains(secret)));
    expect(secret.colors.finish, SkinFinish.halftone);
  });

  group('The skin picker', () {
    Future<void> pumpSettings(
      WidgetTester tester,
      Map<String, Object> saved,
    ) async {
      SharedPreferences.setMockInitialValues(saved);
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SettingsSheet(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
    }

    /// Reading order: rows first, then left to right.
    bool before(WidgetTester tester, String a, String b) {
      final pa = tester.getTopLeft(find.text(a));
      final pb = tester.getTopLeft(find.text(b));
      return pa.dy < pb.dy - 1 || ((pa.dy - pb.dy).abs() <= 1 && pa.dx < pb.dx);
    }

    testWidgets('a bought skin joins the usable ones; locked ones stay out', (
      tester,
    ) async {
      await pumpSettings(tester, {
        'settings_owned_products': ['theme_velvet', 'material_clay'],
      });
      expect(before(tester, 'BLUEPRINT', 'VELVET'), isTrue);
      expect(before(tester, 'VELVET', 'CLAY'), isTrue);
      // Not owned: only in the store.
      for (final locked in ['OBSIDIAN', 'SYNTHWAVE', 'MATCHA', 'FROST']) {
        expect(find.text(locked), findsNothing);
      }
      expect(find.byIcon(Icons.lock_rounded), findsNothing);
    });

    testWidgets('an unfound secret is a question mark with a hint', (
      tester,
    ) async {
      await pumpSettings(tester, {});
      expect(find.text('NEWSPRINT'), findsNothing);
      expect(find.text('???'), findsOneWidget);
      // Second in the grid, where it is hard to miss.
      expect(before(tester, 'MARIGOLD', '???'), isTrue);
      expect(before(tester, '???', 'CHARCOAL'), isTrue);

      await tester.tap(find.text('?'));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Some answers open doors.'), findsOneWidget);
      // Let the tooltip's own timer run out.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('once found it takes that same slot', (tester) async {
      await pumpSettings(tester, {'settings_secret_unlocked': true});
      expect(find.text('???'), findsNothing);
      expect(find.text('NEWSPRINT'), findsOneWidget);
      expect(before(tester, 'MARIGOLD', 'NEWSPRINT'), isTrue);
      expect(before(tester, 'NEWSPRINT', 'CHARCOAL'), isTrue);
    });
  });
}
