import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/themes/presentation/theme_card.dart';
import 'package:popcalc/features/themes/presentation/theme_store_screen.dart';
import 'package:popcalc/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A store held in one state, to show what the screens make of it.
class FixedStore extends PurchaseService {
  FixedStore(super.state, {this.outcome = BuyOutcome.failed});

  final BuyOutcome outcome;
  int buys = 0;

  @override
  Future<BuyOutcome> buy(String productId) async {
    buys++;
    return outcome;
  }

  @override
  Future<bool> refresh() async => false;
}

final allPriced = {for (final id in kProductIds) id: 'BDT 120.00'};

Future<ProviderContainer> pumpStore(
  WidgetTester tester, {
  PurchaseService? store,
}) async {
  SharedPreferences.setMockInitialValues({});
  // Tall enough that the whole store (materials, then skins) is built.
  tester.view.physicalSize = const Size(1080, 7800); // 360 × 2600 dp
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(
    overrides: [
      if (store != null) purchasesProvider.overrideWith((ref) => store),
    ],
  );
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
    // The banner itself carries no price or buy button, only the saving:
    // $19.88 singly against $6.99.
    expect(find.text(r'$6.99'), findsNothing);
    expect(find.text('64% OFF'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bundle-wheel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('EVERYTHING BUNDLE'), findsOneWidget);

    // The sum that sells it, in the store's own money.
    expect(find.text('64% OFF'), findsNWidgets(2));
    expect(find.text(r'$4.95'), findsOneWidget); // 5 skins
    expect(find.text(r'$14.93'), findsOneWidget); // 7 materials
    expect(find.text(r'$19.88'), findsOneWidget);
    expect(find.text(r'You save $12.89'), findsOneWidget);

    await tester.tap(find.text('GET EVERYTHING'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    // Owned now: nothing left to sell.
    expect(find.textContaining('% OFF'), findsNothing);
    expect(find.textContaining('You save'), findsNothing);
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

  group('What Play says', () {
    testWidgets('a product that is not on sale yet is shown but not sold', (
      tester,
    ) async {
      final store = FixedStore(const PurchaseState(loaded: true));
      await pumpStore(tester, store: store);
      // Still on show, each with a lock: 5 skins + 7 materials.
      expect(find.text('SOON'), findsNWidgets(12));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(12));

      await openObsidian(tester);
      expect(find.text('HOLD TO PREVIEW'), findsOneWidget);
      expect(find.textContaining('Not available yet'), findsOneWidget);

      await tester.tap(find.text('NOT AVAILABLE'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 0);
      expect(find.text('APPLY'), findsNothing);
    });

    testWidgets('while the store is being asked, prices wait', (tester) async {
      final store = FixedStore(
        const PurchaseState(loaded: true, checking: true),
      );
      await pumpStore(tester, store: store);
      expect(find.text('...'), findsNWidgets(12));

      await openObsidian(tester);
      await tester.tap(find.text('...').last);
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 0);
      expect(find.textContaining('Not available yet'), findsNothing);
    });

    testWidgets('prices are shown exactly as Play gives them', (tester) async {
      await pumpStore(
        tester,
        store: FixedStore(PurchaseState(loaded: true, prices: allPriced)),
      );
      expect(find.text('BDT 120.00'), findsNWidgets(12));
      expect(find.text(r'$0.99'), findsNothing);
    });

    testWidgets('a pending payment says so and cannot be bought twice', (
      tester,
    ) async {
      final store = FixedStore(
        PurchaseState(
          loaded: true,
          prices: allPriced,
          pending: const {'theme_obsidian'},
        ),
      );
      await pumpStore(tester, store: store);
      expect(find.text('PENDING'), findsOneWidget);

      await openObsidian(tester);
      expect(find.textContaining('Payment pending'), findsOneWidget);
      await tester.tap(find.text('PENDING').last);
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 0);
    });

    testWidgets('a purchase that fails leaves the skin locked and says why', (
      tester,
    ) async {
      final store = FixedStore(PurchaseState(loaded: true, prices: allPriced));
      await pumpStore(tester, store: store);
      await openObsidian(tester);

      await tester.tap(find.text('BDT 120.00').last);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 1);
      expect(find.textContaining('did not go through'), findsOneWidget);
      expect(find.text('APPLY'), findsNothing);
    });

    testWidgets('closing the Play sheet says nothing', (tester) async {
      final store = FixedStore(
        PurchaseState(loaded: true, prices: allPriced),
        outcome: BuyOutcome.cancelled,
      );
      await pumpStore(tester, store: store);
      await openObsidian(tester);

      await tester.tap(find.text('BDT 120.00').last);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 1);
      expect(find.textContaining('did not go through'), findsNothing);
      // Still for sale: 12 cards and the sheet.
      expect(find.text('BDT 120.00'), findsNWidgets(13));
    });

    testWidgets('the bundle is not sold before Play has it either', (
      tester,
    ) async {
      final store = FixedStore(const PurchaseState(loaded: true));
      await pumpStore(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('bundle-wheel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('NOT AVAILABLE'));
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 0);
      expect(find.textContaining('Not available yet'), findsOneWidget);
    });

    testWidgets('no saving is claimed while any price is missing', (
      tester,
    ) async {
      final store = FixedStore(
        PurchaseState(
          loaded: true,
          prices: allPriced,
          amounts: {kAllThemesProductId: 6.99, 'theme_obsidian': 0.99},
        ),
      );
      await pumpStore(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('bundle-wheel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('EVERYTHING BUNDLE'), findsOneWidget);
      expect(find.textContaining('% OFF'), findsNothing);
      expect(find.textContaining('You save'), findsNothing);
    });

    testWidgets('a single skin points at the bundle, which opens from it', (
      tester,
    ) async {
      await pumpStore(tester);
      await openObsidian(tester);
      expect(find.text('UNLOCK'), findsOneWidget);

      await tester.tap(find.text(r'Or everything for $6.99'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('EVERYTHING BUNDLE'), findsOneWidget);
      expect(find.text('UNLOCK'), findsNothing); // the skin's sheet is gone

      // From inside the bundle, a skin's sheet does not point back at it.
      await tester.tap(find.byType(SkinMockup).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('UNLOCK'), findsOneWidget);
      expect(find.textContaining('Or everything for'), findsNothing);
    });

    testWidgets('restore says what it found', (tester) async {
      await pumpStore(tester);
      await tester.tap(find.text('RESTORE PURCHASES'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('No purchases found'), findsOneWidget);
    });

    testWidgets('restore says when Play could not be reached', (tester) async {
      await pumpStore(
        tester,
        store: FixedStore(const PurchaseState(loaded: true)),
      );
      await tester.tap(find.text('RESTORE PURCHASES'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        find.textContaining('Could not reach Google Play'),
        findsOneWidget,
      );
    });
  });

  group('A premium skin that is on', () {
    Future<ProviderContainer> pumpApp(
      WidgetTester tester,
      Set<String> owned,
    ) async {
      SharedPreferences.setMockInitialValues({
        'settings_theme_mode': AppThemeMode.obsidian.index,
      });
      final container = ProviderContainer(
        overrides: [
          purchasesProvider.overrideWith(
            (ref) => FixedStore(PurchaseState(loaded: true, owned: owned)),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const PopCalcApp(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      return container;
    }

    testWidgets('stays on while it is owned', (tester) async {
      final container = await pumpApp(tester, {'theme_obsidian'});
      expect(container.read(themeProvider), AppThemeMode.obsidian);
    });

    testWidgets('stays on with the bundle', (tester) async {
      final container = await pumpApp(tester, {kAllThemesProductId});
      expect(container.read(themeProvider), AppThemeMode.obsidian);
    });

    testWidgets('goes back to Marigold once it is no longer owned', (
      tester,
    ) async {
      final container = await pumpApp(tester, const {});
      expect(container.read(themeProvider), AppThemeMode.sunny);
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
