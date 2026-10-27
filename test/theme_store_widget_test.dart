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
  tester.view.physicalSize = const Size(1080, 9000); // 360 × 3000 dp
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

Future<void> openMatcha(WidgetTester tester) async {
  await tester.ensureVisible(find.text('MATCHA'));
  await tester.pump();
  await tester.tap(find.text('MATCHA'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  // The drops are dated; keep them waiting for their day (27 Oct).
  setUp(() => DropWindow.now = () => DateTime.utc(2026, 10, 1));
  tearDown(() => DropWindow.now = DateTime.now);

  testWidgets('Locked skin: buy, then apply', (tester) async {
    final container = await pumpStore(tester);
    await openMatcha(tester);

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
    expect(container.read(themeProvider), AppThemeMode.matcha);
  });

  testWidgets('Hold to preview shows the calculator, release restores', (
    tester,
  ) async {
    final container = await pumpStore(tester);
    await openMatcha(tester);

    final hold = await tester.startGesture(
      tester.getCenter(find.text('HOLD TO PREVIEW')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PREVIEWING MATCHA'), findsOneWidget);
    expect(find.text('7'), findsWidgets); // keypad is on screen

    await hold.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('PREVIEWING MATCHA'), findsNothing);
    expect(container.read(themeProvider), AppThemeMode.sunny);
  });

  testWidgets('Bundle sheet opens from its card and unlocks every skin', (
    tester,
  ) async {
    await pumpStore(tester);
    expect(find.text(r'$0.99'), findsNWidgets(3));
    // The card itself carries no price or buy button, only the saving:
    // $13.92 singly against $6.99.
    expect(find.text(r'$6.99'), findsNothing);
    expect(find.text('49% OFF'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bundle-card')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('EVERYTHING BUNDLE'), findsOneWidget);

    // The sum that sells it, in the store's own money.
    expect(find.text('49% OFF'), findsNWidgets(2));
    expect(find.text(r'$2.97'), findsOneWidget); // 3 skins
    expect(find.text(r'$10.95'), findsOneWidget); // 5 materials
    expect(find.text(r'$13.92'), findsOneWidget);
    expect(find.text(r'You save $6.93'), findsOneWidget);

    await tester.tap(find.text('GET EVERYTHING'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    // Owned now: nothing left to sell.
    expect(find.textContaining('% OFF'), findsNothing);
    expect(find.textContaining('You save'), findsNothing);
    expect(find.text(r'$0.99'), findsNothing);
    expect(find.text(r'$1.99'), findsNothing);
    // 5 skins + 7 materials + the sheet
    expect(find.text('OWNED'), findsNWidgets(9));
  });

  testWidgets('what is owned steps aside under YOURS', (tester) async {
    await pumpStore(
      tester,
      store: FixedStore(
        PurchaseState(
          loaded: true,
          prices: allPriced,
          owned: const {'theme_velvet', 'material_chrome'},
        ),
      ),
    );
    expect(find.text('YOURS'), findsOneWidget);
    expect(find.text('OWNED'), findsNWidgets(2));
    expect(find.text('BDT 120.00'), findsNWidgets(6));
    // Below everything still for sale.
    final yours = tester.getTopLeft(find.text('YOURS')).dy;
    expect(tester.getTopLeft(find.text('VELVET')).dy, greaterThan(yours));
    expect(tester.getTopLeft(find.text('CHROME')).dy, greaterThan(yours));
    expect(tester.getTopLeft(find.text('MATCHA')).dy, lessThan(yours));
  });

  testWidgets('nothing owned: no YOURS section', (tester) async {
    await pumpStore(tester);
    expect(find.text('YOURS'), findsNothing);
  });

  group('What Play says', () {
    testWidgets('a product that is not on sale yet is shown but not sold', (
      tester,
    ) async {
      final store = FixedStore(const PurchaseState(loaded: true));
      await pumpStore(tester, store: store);
      // Still on show, each with a lock: 5 skins + 7 materials + 2 drops.
      expect(find.text('SOON'), findsNWidgets(8));
      // The drops wait for their date instead.
      expect(find.text('FROM 27 OCT'), findsNWidgets(2));
      expect(find.byIcon(Icons.lock_rounded), findsNWidgets(10));
      expect(find.byKey(const ValueKey('limited-mark')), findsNWidgets(2));

      await openMatcha(tester);
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
      expect(find.text('...'), findsNWidgets(8));

      await openMatcha(tester);
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
      expect(find.text('BDT 120.00'), findsNWidgets(8));
      expect(find.text(r'$0.99'), findsNothing);
    });

    testWidgets('a pending payment says so and cannot be bought twice', (
      tester,
    ) async {
      final store = FixedStore(
        PurchaseState(
          loaded: true,
          prices: allPriced,
          pending: const {'theme_matcha'},
        ),
      );
      await pumpStore(tester, store: store);
      expect(find.text('PENDING'), findsOneWidget);

      await openMatcha(tester);
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
      await openMatcha(tester);

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
      await openMatcha(tester);

      await tester.tap(find.text('BDT 120.00').last);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.buys, 1);
      expect(find.textContaining('did not go through'), findsNothing);
      // Still for sale: 12 cards and the sheet.
      expect(find.text('BDT 120.00'), findsNWidgets(9));
    });

    testWidgets('the bundle is not sold before Play has it either', (
      tester,
    ) async {
      final store = FixedStore(const PurchaseState(loaded: true));
      await pumpStore(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('bundle-card')));
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
          amounts: {kAllThemesProductId: 6.99, 'theme_matcha': 0.99},
        ),
      );
      await pumpStore(tester, store: store);
      await tester.tap(find.byKey(const ValueKey('bundle-card')));
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
      await openMatcha(tester);
      expect(find.text('UNLOCK'), findsOneWidget);

      await tester.tap(find.text(r'Or everything for $6.99'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('EVERYTHING BUNDLE'), findsOneWidget);
      expect(find.text('UNLOCK'), findsNothing); // the skin's sheet is gone

      // From inside the bundle, a skin's sheet does not point back at it.
      await tester.tap(find.byType(SkinSwatch).last);
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
        'settings_theme_mode': AppThemeMode.matcha.index,
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
      final container = await pumpApp(tester, {'theme_matcha'});
      expect(container.read(themeProvider), AppThemeMode.matcha);
    });

    testWidgets('stays on with the bundle', (tester) async {
      final container = await pumpApp(tester, {kAllThemesProductId});
      expect(container.read(themeProvider), AppThemeMode.matcha);
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
    expect(find.text('BLUEPRINT'), findsNothing);
    expect(find.text('FREE'), findsNothing);
  });
}
