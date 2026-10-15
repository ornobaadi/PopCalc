import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';
import 'package:popcalc/features/calculator/presentation/widgets/ink_spill.dart';
import 'package:popcalc/features/history/presentation/history_sheet.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';
import 'package:popcalc/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  group('The newsroom hunt', () {
    late ProviderContainer container;
    late CalculatorController calc;
    late SettingsNotifier settings;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      container = ProviderContainer();
      addTearDown(container.dispose);
      calc = container.read(calculatorProvider.notifier);
      settings = container.read(settingsProvider.notifier);
      await settle();
    });

    int step() => container.read(settingsProvider).huntStep;
    void digits(String s) => s.split('').forEach(calc.onDigit);
    void divideByZero() {
      calc.onClear();
      digits('5');
      calc.onOperator(TokenType.divide, '÷');
      digits('0');
      calc.onEquals();
    }

    test('note 1: dividing by zero files the story with its own line',
        () async {
      divideByZero();
      await settle();
      expect(step(), 1);
      expect(calc.state.resultText, kHuntErrorLine);
      expect(calc.state.errorNote, kHuntErrorNote);
      expect(container.read(huntSolvedProvider), 1);

      // Afterwards it is an ordinary joke again.
      divideByZero();
      expect(calc.state.resultText, isNot(kHuntErrorLine));
      expect(calc.state.errorNote, isNull);
      expect(step(), 1);
    });

    test('notes only count in order', () async {
      settings.setSoundPack(SoundPack.typewriter);
      settings.setShowLivePreview(true);
      settings.advanceHunt(3);
      await settle();
      expect(step(), 0);

      divideByZero();
      settings.setShowLivePreview(true); // note 3 before note 2
      expect(step(), 1);
      settings.setSoundPack(SoundPack.mellow);
      expect(step(), 1);
      settings.setSoundPack(SoundPack.typewriter);
      expect(step(), 2);
      settings.setShowLivePreview(false);
      expect(step(), 2);
      settings.setShowLivePreview(true);
      expect(step(), 3);
      settings.advanceHunt(4); // the edition before the ruler
      expect(step(), 3);
      settings.advanceHunt(3);
      expect(step(), 4);
      settings.advanceHunt(4);
      expect(step(), kHuntLength);
      expect(container.read(settingsProvider).huntDone, isTrue);
      // The skin itself arrives with the ink spill on the calculator.
      expect(container.read(settingsProvider).secretUnlocked, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('settings_hunt_step'), kHuntLength);
    });

    test('lead 4: a guy named Tan tried to do a 90', () async {
      SharedPreferences.setMockInitialValues({'settings_hunt_step': 3});
      final c4 = ProviderContainer();
      addTearDown(c4.dispose);
      final calc4 = c4.read(calculatorProvider.notifier);
      c4.read(settingsProvider);
      await settle();
      void tan(String n) {
        calc4.onClear();
        calc4.onOpener(const Token(TokenType.function, 'tan('));
        n.split('').forEach(calc4.onDigit);
        calc4.onEquals();
      }

      // tan 270 is undefined too, but it is not the lead.
      tan('270');
      expect(c4.read(settingsProvider).huntStep, 3);
      expect(calc4.state.resultText, isNot(kHuntTanLine));

      tan('90');
      expect(calc4.state.resultText, kHuntTanLine);
      expect(calc4.state.errorNote, kHuntTanNote);
      expect(c4.read(settingsProvider).huntStep, 4);

      // Afterwards tan 90 is an ordinary joke again.
      tan('90');
      expect(calc4.state.resultText, isNot(kHuntTanLine));
    });

    test('1,337 no longer opens anything', () async {
      digits('1000');
      calc.onOperator(TokenType.plus, '+');
      digits('337');
      calc.onEquals();
      await settle();
      expect(container.read(settingsProvider).secretUnlocked, isFalse);
      expect(container.read(themeProvider), AppThemeMode.sunny);
    });

    test('progress survives a restart', () async {
      SharedPreferences.setMockInitialValues({'settings_hunt_step': 2});
      final again = ProviderContainer();
      addTearDown(again.dispose);
      again.read(settingsProvider);
      await settle();
      expect(again.read(settingsProvider).huntStep, 2);
    });

    test('1,337 finders play the case like everyone else', () async {
      SharedPreferences.setMockInitialValues({'settings_secret_unlocked': true});
      final old = ProviderContainer();
      addTearDown(old.dispose);
      final c = old.read(calculatorProvider.notifier);
      old.read(settingsProvider);
      await settle();
      expect(old.read(settingsProvider).secretUnlocked, isFalse);
      expect(old.read(settingsProvider).huntDone, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('settings_secret_unlocked'), isFalse);
      // Lead 1 is theirs to crack.
      c.onDigit('5');
      c.onOperator(TokenType.divide, '÷');
      c.onDigit('0');
      c.onEquals();
      expect(c.state.resultText, kHuntErrorLine);
      expect(old.read(settingsProvider).huntStep, 1);
    });

    test('a solved case stays solved', () async {
      SharedPreferences.setMockInitialValues({
        'settings_secret_unlocked': true,
        'settings_hunt_step': kHuntLength,
      });
      final done = ProviderContainer();
      addTearDown(done.dispose);
      done.read(settingsProvider);
      await settle();
      expect(done.read(settingsProvider).secretUnlocked, isTrue);
      expect(done.read(settingsProvider).huntDone, isTrue);
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

    testWidgets('an unfound secret is a ??? tile that opens the first note', (
      tester,
    ) async {
      await pumpSettings(tester, {});
      expect(find.text('NEWSPRINT'), findsNothing);
      expect(find.text('???'), findsOneWidget);
      // Second in the grid, where it is hard to miss.
      expect(before(tester, 'MARIGOLD', '???'), isTrue);
      expect(before(tester, '???', 'CHARCOAL'), isTrue);

      await tester.tap(find.byKey(const ValueKey('mystery-tile')));
      await tester.pumpAndSettle();
      expect(find.text(kHuntNotes[0]), findsOneWidget);
      expect(find.text("THE EDITOR'S CASE FILE"), findsOneWidget);
      expect(find.text('CONFIDENTIAL'), findsOneWidget);
    });

    testWidgets('mid-hunt the note shows the next clue and the filed ones', (
      tester,
    ) async {
      await pumpSettings(tester, {'settings_hunt_step': 2});
      await tester.tap(find.byKey(const ValueKey('mystery-tile')));
      await tester.pumpAndSettle();
      expect(find.text(kHuntNotes[2]), findsOneWidget);
      expect(find.text(kHuntNotes[1]), findsOneWidget);
      expect(find.text('CRACKED'), findsNWidgets(2));
      // The leads still to come are blacked out, numbers only.
      expect(find.text('LEAD #04'), findsOneWidget);
      expect(find.text(kHuntNotes[3]), findsNothing);
      expect(find.text(kHuntAgainHint), findsOneWidget);

      // Holding the card flips it to the plain hint.
      double backOpacity() => tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('hunt-hint')),
              matching: find.byType(Opacity),
            ).first,
          )
          .opacity;
      expect(backOpacity(), 0);
      final hold = await tester.startGesture(
        tester.getCenter(find.text(kHuntNotes[2])),
      );
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));
      expect(backOpacity(), 1);
      expect(find.text(kHuntHints[2]), findsOneWidget);
      await hold.up();
      await tester.pumpAndSettle();
      expect(backOpacity(), 0);
    });

    testWidgets('once found it takes that same slot', (tester) async {
      await pumpSettings(tester, {
        'settings_secret_unlocked': true,
        'settings_hunt_step': kHuntLength,
      });
      expect(find.text('???'), findsNothing);
      expect(find.text('NEWSPRINT'), findsOneWidget);
      expect(before(tester, 'MARIGOLD', 'NEWSPRINT'), isTrue);
      expect(before(tester, 'NEWSPRINT', 'CHARCOAL'), isTrue);
    });
  });

  testWidgets('every note solved: ink spills and Newsprint goes on', (
    tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final c in ['method', 'accelerometer', 'gyroscope', 'user_accel']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('dev.fluttercommunity.plus/sensors/$c'),
        (_) async => null,
      );
    }
    SharedPreferences.setMockInitialValues({'settings_hunt_step': kHuntLength});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalculatorScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(InkSpill), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1300));
    expect(container.read(settingsProvider).secretUnlocked, isTrue);
    expect(container.read(themeProvider), AppThemeMode.newsprint);
    // The big number reads the headline, not the old error or its note.
    final calc = container.read(calculatorProvider);
    expect(calc.resultText, kHuntHeadline);
    expect(calc.errorNote, kHuntHeadlineNote);
    expect(calc.error, isNull);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.byType(InkSpill), findsNothing);
    // Let the announcement pill time out.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets("the last note: today's edition waits in History", (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'settings_hunt_step': kHuntLength - 1,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => HistorySheet.show(ctx, onSelectEntry: (_, _) {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    // Shown even with no calculations at all.
    expect(find.text(kHuntEditionTitle), findsOneWidget);
    expect(find.text('No calculations yet'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('hunt-edition')));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).huntStep, kHuntLength);
    expect(find.text(kHuntEditionTitle), findsNothing); // sheet closed
  });

  testWidgets('no edition in History before its note', (tester) async {
    SharedPreferences.setMockInitialValues({'settings_hunt_step': 2});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: HistorySheet(onSelectEntry: (_, _) {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text(kHuntEditionTitle), findsNothing);
  });

  testWidgets('wearing Newsprint from 1,337 goes back to Marigold', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'settings_secret_unlocked': true,
      'settings_theme_mode': AppThemeMode.newsprint.index,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const PopCalcApp()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(themeProvider), AppThemeMode.sunny);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('a solved case keeps Newsprint on', (tester) async {
    SharedPreferences.setMockInitialValues({
      'settings_secret_unlocked': true,
      'settings_hunt_step': kHuntLength,
      'settings_theme_mode': AppThemeMode.newsprint.index,
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const PopCalcApp()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(themeProvider), AppThemeMode.newsprint);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
