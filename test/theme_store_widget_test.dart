import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/themes/presentation/theme_store_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> pumpStore(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  // Tall enough that the whole store (materials, then skins) is built.
  tester.view.physicalSize = const Size(1080, 7800); // 360 × 2600 dp
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ThemeStoreScreen()),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
  return container;
}

Future<void> openObsidian(WidgetTester tester) async {
  await tester.ensureVisible(find.text('OBSIDIAN'));
  await tester.pump();
  await tester.tap(find.text('OBSIDIAN'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('Locked skin: buy, then apply', (tester) async {
    final container = await pumpStore(tester);
    await openObsidian(tester);

    expect(find.text('HOLD TO PREVIEW'), findsOneWidget);
    expect(find.text('APPLY'), findsNothing);
    expect(container.read(themeProvider), AppThemeMode.sunny);

    // The sheet's price button is the last price in the tree.
    await tester.tap(find.text(r'$0.99').last);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('APPLY'), findsOneWidget);
    expect(container.read(themeProvider), AppThemeMode.sunny);

    await tester.tap(find.text('APPLY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(themeProvider), AppThemeMode.obsidian);
  });

  testWidgets('Hold to preview shows the calculator, release restores', (
    tester,
  ) async {
    final container = await pumpStore(tester);
    await openObsidian(tester);

    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO PREVIEW')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PREVIEWING OBSIDIAN'), findsOneWidget);
    expect(find.text('7'), findsWidgets); // keypad is on screen

    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PREVIEWING OBSIDIAN'), findsNothing);
    expect(container.read(themeProvider), AppThemeMode.sunny);
  });

  testWidgets('Bundle sheet opens from the carousel and unlocks every skin', (
    tester,
  ) async {
    await pumpStore(tester);
    expect(find.text(r'$0.99'), findsNWidgets(5));
    // The banner itself carries no price or buy button.
    expect(find.text(r'$9.99'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('bundle-wheel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('EVERYTHING BUNDLE'), findsOneWidget);

    await tester.tap(find.text(r'$9.99'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text(r'$0.99'), findsNothing);
    expect(find.text(r'$1.99'), findsNothing);
    // 5 skins + 7 materials + the sheet
    expect(find.text('OWNED'), findsNWidgets(13));
  });

  group('Bundle carousel', () {
    AppThemeMode front(WidgetTester tester) => tester
        .state<BundleCarouselState>(find.byType(BundleCarousel))
        .front
        .mode;
    final wheel = find.byKey(const ValueKey('bundle-wheel'));

    testWidgets('one skin per swipe, however hard', (tester) async {
      await pumpStore(tester);
      expect(front(tester), AppThemeMode.frost);

      await tester.fling(wheel, const Offset(-300, 0), 3000);
      await tester.pumpAndSettle();
      expect(front(tester), AppThemeMode.wood);

      await tester.fling(wheel, const Offset(300, 0), 3000);
      await tester.pumpAndSettle();
      expect(front(tester), AppThemeMode.frost);
    });

    testWidgets('turns by itself and wraps round forever', (tester) async {
      await pumpStore(tester);
      final seen = <AppThemeMode>[front(tester)];
      // Sample mid-dwell, exactly one dwell apart, so each sample sees
      // one more turn.
      await tester.pump(const Duration(milliseconds: 1000));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 1200)); // tick fires
        await tester.pump(const Duration(milliseconds: 16));
        await tester.pump(const Duration(milliseconds: 600)); // turn done
        await tester.pump(
          BundleCarousel.dwell - const Duration(milliseconds: 1816),
        );
        seen.add(front(tester));
      }
      // Skins and materials alternate; after Mechanical it wraps round.
      expect(seen, [
        AppThemeMode.frost,
        AppThemeMode.wood,
        AppThemeMode.velvet,
        AppThemeMode.candy,
        AppThemeMode.neon,
        AppThemeMode.mechanical,
        AppThemeMode.obsidian, // wrapped
      ]);
    });

    testWidgets('only the box recolours, not the screen', (tester) async {
      await pumpStore(tester);
      Color screen() =>
          tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor!;
      Color box() =>
          (tester
                      .widget<Container>(
                        find.byKey(const ValueKey('bundle-box')),
                      )
                      .decoration
                  as BoxDecoration)
              .color!;

      final before = box();
      expect(screen(), ThemeColors.sunnyTheme.bg);
      await tester.pump(BundleCarousel.dwell);
      await tester.pumpAndSettle();
      expect(box(), isNot(before));
      expect(screen(), ThemeColors.sunnyTheme.bg);
    });
  });

  testWidgets('Free skins are not sold in the store', (tester) async {
    await pumpStore(tester);
    expect(find.text('MARIGOLD'), findsNothing);
    expect(find.text('CHARCOAL'), findsNothing);
    expect(find.text('PEONY'), findsNothing);
    expect(find.text('FREE'), findsNothing);
  });
}
