import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/app_icon/app_icons.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';
import 'package:popcalc/features/splash/presentation/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('popcalc/app_icon');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return true;
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  Future<void> settle() async {
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  test(
    'the catalogue: Classic first, ids and aliases unique, previews on disk',
    () {
      expect(kAppIcons.first.id, kClassicIcon);
      expect(kAppIcons.first.alias, 'MainActivity');
      expect(kAppIcons.map((o) => o.id).toSet().length, kAppIcons.length);
      expect(kAppIcons.map((o) => o.alias).toSet().length, kAppIcons.length);
      for (final o in kAppIcons) {
        expect(
          File(o.previewAsset).existsSync(),
          isTrue,
          reason: o.previewAsset,
        );
      }
      expect(appIconOf('gone').id, kClassicIcon);
    },
  );

  test('every alias is declared in the manifest and known to the activity', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    final activity = File(
      'android/app/src/main/kotlin/com/ornobaadi/popcalc/PopCalcActivity.kt',
    ).readAsStringSync();
    for (final o in kAppIcons) {
      expect(manifest, contains('android:name=".${o.alias}"'));
      expect(activity, contains('"${o.alias}"'));
    }
    // Only the official icon is on out of the box.
    expect(RegExp(r'android:enabled="true"').allMatches(manifest).length, 1);
  });

  test('choosing an icon saves it and asks Android for that alias', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await settle();
    expect(container.read(settingsProvider).appIcon, kClassicIcon);
    expect(calls, isEmpty);

    await container.read(settingsProvider.notifier).setAppIcon('percent');
    expect(container.read(settingsProvider).appIcon, 'percent');
    expect(calls.single.method, 'set');
    expect(calls.single.arguments, {'alias': 'IconPercent'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings_app_icon'), 'percent');

    // Picking the same one again does nothing.
    await container.read(settingsProvider.notifier).setAppIcon('percent');
    expect(calls, hasLength(1));
  });

  test('a saved choice is re-applied at launch', () async {
    SharedPreferences.setMockInitialValues({'settings_app_icon': 'keypad'});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(settingsProvider);
    await settle();
    expect(container.read(settingsProvider).appIcon, 'keypad');
    expect(calls.single.arguments, {'alias': 'IconKeypad'});
  });

  testWidgets('settings lists every icon and a tap switches to it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
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
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('APP ICON'), findsOneWidget);
    for (final o in kAppIcons) {
      expect(find.byKey(ValueKey('app-icon-${o.id}')), findsOneWidget);
    }
    final tile = find.byKey(const ValueKey('app-icon-operators'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pump(const Duration(milliseconds: 200));
    expect(container.read(settingsProvider).appIcon, 'operators');
    expect(calls.last.arguments, {'alias': 'IconOperators'});
  });

  for (final size in const [
    Size(320, 568), // small old phone
    Size(360, 640),
    Size(412, 915),
    Size(800, 1280), // tablet
  ]) {
    testWidgets('icon picker fits a ${size.width.toInt()} dp wide screen', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = size * 2;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: SettingsSheet(),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final first = find.byKey(ValueKey('app-icon-${kAppIcons.first.id}'));
      await tester.ensureVisible(first);
      await tester.pump();
      expect(tester.takeException(), isNull);

      final images = find.descendant(
        of: find.byKey(ValueKey('app-icon-${kAppIcons.last.id}')),
        matching: find.byType(Image),
      );
      final w = tester.getSize(images).width;
      // Big enough to judge, never giant.
      expect(w, greaterThanOrEqualTo(50));
      expect(w, lessThanOrEqualTo(72));
      // Rows of four, every tile on screen.
      final tops = kAppIcons
          .map(
            (o) =>
                tester.getTopLeft(find.byKey(ValueKey('app-icon-${o.id}'))).dy,
          )
          .toList();
      expect((tops[0] - tops[3]).abs(), lessThan(2));
      expect(tops[4] - tops[0], greaterThan(w));
      expect((tops[4] - tops.last).abs(), lessThan(2));
      for (final o in kAppIcons) {
        final r = tester.getRect(find.byKey(ValueKey('app-icon-${o.id}')));
        expect(r.left, greaterThanOrEqualTo(0));
        expect(r.right, lessThanOrEqualTo(size.width));
      }
    });
  }

  testWidgets('splash opens on the launch screen picture, then settles', (
    tester,
  ) async {
    SettingsNotifier.bootAppIcon = 'ruler';
    addTearDown(() => SettingsNotifier.bootAppIcon = kClassicIcon);
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SplashScreen())),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    final icon = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          (w.image as AssetImage).assetName == 'assets/app_icons/ruler.png',
    );
    expect(icon, findsOneWidget);
    // Same size and place as Android's launch screen: 160 dp, dead centre.
    expect(
      tester.getSize(icon).width,
      closeTo(SplashScreen.launchIconSize, 0.5),
    );
    expect(tester.getCenter(icon), const Offset(180, 390));
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor, SplashScreen.background(Brightness.dark));

    await tester.pump(const Duration(milliseconds: 1100));
    expect(tester.getSize(icon).width, closeTo(SplashScreen.tileSize, 0.5));
    expect(find.text('POP CALC'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
