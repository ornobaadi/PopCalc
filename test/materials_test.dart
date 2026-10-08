import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/material_feel.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every material ships a full sound set for each of its feels', () {
    for (final material in kMaterials) {
      expect(material.isMaterial, isTrue);
      for (final feel in material.feels) {
        for (final sfx in Sfx.values) {
          final path = 'assets/sounds/${feel.soundFolder}/${sfx.file}.wav';
          expect(File(path).existsSync(), isTrue, reason: path);
        }
      }
    }
  });

  test('materials have a finish, a price and their own haptics', () {
    final feels = <HapticFeel>{};
    for (final material in kMaterials) {
      expect(material.colors.finish, isNot(SkinFinish.standard));
      expect(material.productId, startsWith('material_'));
      for (final feel in material.feels) {
        expect(feel.haptics, isNot(HapticFeel.standard));
        expect(feels.add(feel.haptics), isTrue, reason: 'shared haptics');
      }
    }
  });

  test('the existing skins are untouched: no finish, no feel', () {
    for (final skin in kSkins) {
      expect(skin.isMaterial, isFalse);
      expect(skin.colors.finish, SkinFinish.standard);
    }
  });

  test('a material is unlocked by its own product or the bundle', () {
    final clay = skinOf(AppThemeMode.clay);
    final wood = skinOf(AppThemeMode.wood);
    expect(ownsSkin(const {}, clay, locked: true), isFalse);
    expect(ownsSkin({clay.productId!}, clay, locked: true), isTrue);
    expect(ownsSkin({clay.productId!}, wood, locked: true), isFalse);
    expect(ownsSkin({kAllThemesProductId}, wood, locked: true), isTrue);
  });

  test('the bundle lists every premium skin and material once', () {
    final expected = {
      ...kSkins.where((s) => s.premium).map((s) => s.mode),
      ...kMaterials.map((s) => s.mode),
    };
    expect(kBundleItems.map((s) => s.mode).toSet(), expected);
    expect(kBundleItems.length, expected.length);
  });

  test('a material applies its sound and haptics as one set', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    // Let the saved settings and skin load before changing them.
    container.read(settingsProvider);
    container.read(themeProvider);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // Ordinary skin: nothing special.
    expect(container.read(materialFeelProvider), isNull);

    container.read(themeProvider.notifier).setTheme(AppThemeMode.wood);
    expect(container.read(materialFeelProvider)!.soundFolder, 'wood');
    applyMaterialFeel(container.read(materialFeelProvider));
    expect(AppHaptics.feel, HapticFeel.wood);

    // Mechanical follows the chosen switch.
    container.read(themeProvider.notifier).setTheme(AppThemeMode.mechanical);
    expect(container.read(materialFeelProvider)!.id, 'clicky');
    await container.read(settingsProvider.notifier).setMechSwitch('linear');
    expect(container.read(materialFeelProvider)!.soundFolder, 'mech_linear');

    // Back to a plain skin restores the standard feel.
    container.read(themeProvider.notifier).setTheme(AppThemeMode.ink);
    applyMaterialFeel(container.read(materialFeelProvider));
    expect(AppHaptics.feel, HapticFeel.standard);
  });

  testWidgets('settings swap sound packs for switches under Mechanical', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'settings_theme_mode': AppThemeMode.mechanical.index,
      'settings_owned_products': ['material_mechanical'],
    });
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

    // The owned material joins the skins grid.
    expect(find.text('MECHANICAL'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('TACTILE'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('CLICKY'), findsOneWidget);
    expect(find.text('LINEAR'), findsOneWidget);
    expect(find.text('POP'), findsNothing);

    await tester.tap(find.text('TACTILE'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(container.read(settingsProvider).mechSwitch, 'tactile');
  });
}
