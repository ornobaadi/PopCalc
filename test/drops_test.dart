import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';
import 'package:popcalc/features/calculator/presentation/widgets/doom_incursion.dart';
import 'package:popcalc/features/calculator/presentation/widgets/drop_backdrop.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sand = skinOf(AppThemeMode.mirage);
  final hour = skinOf(AppThemeMode.reckoning);
  final drop = sand.drop!;

  tearDown(() => DropWindow.now = DateTime.now);

  void at(int y, int m, int d, [int h = 0]) =>
      DropWindow.now = () => DateTime.utc(y, m, d, h);

  test('a drop is upcoming, then open from 27 Oct, then over', () {
    at(2026, 10, 26);
    expect([drop.upcoming, drop.open, drop.over], [true, false, false]);
    at(2026, 10, 27);
    expect([drop.upcoming, drop.open, drop.over], [false, true, false]);
    at(2027, 1, 10, 23);
    expect(drop.open, isTrue);
    at(2027, 1, 11);
    expect([drop.upcoming, drop.open, drop.over], [false, false, true]);
  });

  test('days left count a part day as one and stop at zero', () {
    at(2026, 12, 11);
    expect(drop.daysLeft, 31);
    at(2026, 10, 27);
    expect(drop.daysLeft, 76);
    at(2027, 1, 10, 6);
    expect(drop.daysLeft, 1);
    at(2027, 2, 1);
    expect(drop.daysLeft, 0);
  });

  test('drops are not in the bundle, and the bundle does not unlock them', () {
    expect(kBundleItems, isNot(contains(sand)));
    expect(kBundleItems, isNot(contains(hour)));
    expect(ownsSkin({kAllThemesProductId}, sand, locked: true), isFalse);
    expect(ownsSkin({sand.productId!}, sand, locked: true), isTrue);
    expect(ownsSkin({sand.productId!}, hour, locked: true), isFalse);
    expect(kProductIds, containsAll([sand.productId, hour.productId]));
  });

  test('the Dunesday bundle unlocks both drops and nothing else', () {
    expect(ownsSkin({kDropBundleId}, sand, locked: true), isTrue);
    expect(ownsSkin({kDropBundleId}, hour, locked: true), isTrue);
    expect(
      ownsSkin({kDropBundleId}, skinOf(AppThemeMode.matcha), locked: true),
      isFalse,
    );
  });

  test('the bundle saving ignores the drops', () {
    final prices = {for (final id in kProductIds) id: 'x'};
    final amounts = {
      for (final id in kProductIds) id: 1.0,
      kAllThemesProductId: 1.0,
    };
    final state = PurchaseState(loaded: true, prices: prices, amounts: amounts);
    final singly = kBundleItems.length;
    expect(state.bundleSaving, ((1.0 - 1.0 / singly) * 100).floor());
  });

  test('a bought drop stays owned after the window closes', () async {
    SharedPreferences.setMockInitialValues({});
    at(2026, 12, 20);
    expect(drop.open, isTrue);
    final owned = {sand.productId!};
    at(2027, 3, 1);
    expect(drop.over, isTrue);
    expect(ownsSkin(owned, sand, locked: true), isTrue);
    expect(ownsSkin(owned, hour, locked: true), isFalse);
  });

  test('each drop has its own finish', () {
    expect(sand.colors.finish, SkinFinish.dune);
    expect(hour.colors.finish, SkinFinish.doom);
  });

  Future<ProviderContainer> pump(WidgetTester tester, AppThemeMode mode) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    for (final c in ['method', 'accelerometer', 'gyroscope', 'user_accel']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('dev.fluttercommunity.plus/sensors/$c'),
        (_) async => null,
      );
    }
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer(
      overrides: [
        themeProvider.overrideWith((ref) => ThemeNotifier.preview(mode)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalculatorScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    return container;
  }

  testWidgets('both drops lay their living backdrop behind the calculator', (
    tester,
  ) async {
    for (final mode in [AppThemeMode.mirage, AppThemeMode.reckoning]) {
      await pump(tester, mode);
      expect(find.byType(DropBackdrop), findsOneWidget);
      await tester.pump(const Duration(seconds: 2));
    }
  });

  testWidgets('holding the Reckoning clock, then letting go, brings the figure', (
    tester,
  ) async {
    await pump(tester, AppThemeMode.reckoning);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final hub = Offset(size.width * kClockHub.dx, size.height * kClockHub.dy);
    final line = find.text(DoomIncursion.line);
    expect(line, findsNothing);
    final hint = find.byKey(const ValueKey('egg-hint'));
    expect(hint, findsOneWidget, reason: 'first time: HOLD HERE over the hub');

    final g = await tester.startGesture(hub);
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await tester.pump();
    expect(line, findsOneWidget, reason: 'the sequence is running');
    for (var i = 0; i < 38; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: line, matching: find.byType(Opacity)).first,
    );
    expect(opacity.opacity, greaterThan(0.9));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(line, findsNothing, reason: 'it leaves again');
    expect(hint, findsNothing, reason: 'found once, the hint is gone for good');
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('egg_found_reckoning'), isTrue);
  });

  testWidgets('a quick tap or an early release on the hub does nothing', (
    tester,
  ) async {
    await pump(tester, AppThemeMode.reckoning);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final hub = Offset(size.width * kClockHub.dx, size.height * kClockHub.dy);
    await tester.tapAt(hub);
    await tester.pump(const Duration(milliseconds: 500));
    final g = await tester.startGesture(hub);
    await tester.pump(const Duration(milliseconds: 700));
    await g.up();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(DoomIncursion.line), findsNothing);
  });

  test('the sun by day and the moon by night, from the clock alone', () {
    const size = Size(400, 800);
    final noon = DuneSky.at(DateTime(2026, 11, 3, 12), size);
    expect([noon.sunUp, noon.night], [true, 0.0]);
    expect(noon.body, noon.sun);
    final night = DuneSky.at(DateTime(2026, 11, 3, 22), size);
    expect([night.sunUp, night.night], [false, 1.0]);
    expect(night.body, night.moon);
    final dusk = DuneSky.at(DateTime(2026, 11, 3, 18, 36), size);
    expect(dusk.night, inExclusiveRange(0.0, 1.0));
  });

  bool wormShowing(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((p) => p.painter.runtimeType.toString() == '_WormPainter');

  Future<void> hold(WidgetTester tester, Offset at, int ms) async {
    final g = await tester.startGesture(at);
    for (var i = 0; i < ms ~/ 100; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('holding the sun, then letting go, raises the worm and it sinks again', (
    tester,
  ) async {
    duneNow = () => DateTime(2026, 11, 3, 12);
    addTearDown(() => duneNow = DateTime.now);
    await pump(tester, AppThemeMode.mirage);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final sun = DuneSky.at(duneNow(), size).body;
    expect(wormShowing(tester), isFalse);
    expect(find.byKey(const ValueKey('egg-hint')), findsOneWidget);
    await hold(tester, sun, 2400);
    expect(wormShowing(tester), isTrue);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(wormShowing(tester), isFalse, reason: 'it sinks back under');
  });

  testWidgets('the moon works after dark, and a hold elsewhere does nothing', (
    tester,
  ) async {
    duneNow = () => DateTime(2026, 11, 3, 22);
    addTearDown(() => duneNow = DateTime.now);
    await pump(tester, AppThemeMode.mirage);
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    await hold(tester, Offset(size.width * 0.1, size.height * 0.6), 2400);
    expect(wormShowing(tester), isFalse);
    await hold(tester, DuneSky.at(duneNow(), size).body, 300);
    expect(wormShowing(tester), isFalse, reason: 'too short, only a tap');
    await hold(tester, DuneSky.at(duneNow(), size).body, 2400);
    expect(wormShowing(tester), isTrue);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('an ordinary skin has no backdrop scenery', (tester) async {
    await pump(tester, AppThemeMode.sunny);
    final box = find.descendant(
      of: find.byType(DropBackdrop),
      matching: find.byType(CustomPaint),
    );
    expect(box, findsNothing);
  });
}
