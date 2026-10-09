import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/storage/play_purchase_service.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/features/themes/presentation/purchase_feedback.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _savedKey = 'purchases_owned';
const _obsidian = 'theme_obsidian';
const _clay = 'material_clay';

ProductDetails _product(String id, String price) => ProductDetails(
  id: id,
  title: id,
  description: '',
  price: price,
  rawPrice: 1.0,
  currencyCode: 'BDT',
);

PurchaseDetails _purchase(
  String id,
  PurchaseStatus status, {
  bool acknowledged = false,
}) => PurchaseDetails(
  purchaseID: 'order-$id',
  productID: id,
  verificationData: PurchaseVerificationData(
    localVerificationData: '',
    serverVerificationData: 'token-$id',
    source: 'test',
  ),
  transactionDate: null,
  status: status,
)..pendingCompletePurchase = !acknowledged;

/// How Play reports a sheet that closed without a purchase: no product id.
PurchaseDetails _noPurchase(PurchaseStatus status) => _purchase('', status);

/// A Play store the tests can script.
class _Play implements BillingGateway {
  bool available = true;
  List<ProductDetails> onSale = [];

  /// What the account holds; null makes Play unable to say.
  List<PurchaseDetails>? account = [];

  /// What the purchase sheet reports when it is opened, if anything.
  List<PurchaseDetails> Function(ProductDetails product)? onLaunch;
  bool opensSheet = true;

  final acknowledged = <String>[];
  final launched = <String>[];
  final _updates = StreamController<List<PurchaseDetails>>.broadcast();

  void report(List<PurchaseDetails> purchases) => _updates.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get updates => _updates.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> products(Set<String> ids) async {
    final found = onSale.where((p) => ids.contains(p.id)).toList();
    return ProductDetailsResponse(
      productDetails: found,
      notFoundIDs: ids.difference({for (final p in found) p.id}).toList(),
    );
  }

  @override
  Future<bool> launch(ProductDetails product) async {
    launched.add(product.id);
    final result = onLaunch?.call(product);
    if (result != null) report(result);
    return opensSheet;
  }

  @override
  Future<void> acknowledge(PurchaseDetails purchase) async {
    acknowledged.add(purchase.productID);
  }

  @override
  Future<List<PurchaseDetails>?> held() async => account;
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

Future<ProviderContainer> _start(
  _Play play, {
  List<String> saved = const [],
}) async {
  SharedPreferences.setMockInitialValues({
    if (saved.isNotEmpty) _savedKey: saved,
  });
  final container = ProviderContainer(
    overrides: [
      purchasesProvider.overrideWith((ref) => PlayPurchaseService(play)),
    ],
  );
  addTearDown(container.dispose);
  container.read(purchasesProvider);
  await _settle();
  return container;
}

Future<List<String>> _savedNow() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList(_savedKey) ?? const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('before any product exists in Play Console', () {
    test(
      'nothing has a price, nothing can be bought, nothing breaks',
      () async {
        final play = _Play();
        final container = await _start(play);
        final state = container.read(purchasesProvider);

        expect(state.loaded, isTrue);
        expect(state.checking, isFalse);
        expect(state.prices, isEmpty);
        expect(state.canBuy(_obsidian), isFalse);
        expect(
          await container.read(purchasesProvider.notifier).buy(_obsidian),
          BuyOutcome.unavailable,
        );
        expect(play.launched, isEmpty);
      },
    );

    test('a store that cannot be reached is the same', () async {
      final play = _Play()..available = false;
      final container = await _start(play);

      expect(container.read(purchasesProvider).checking, isFalse);
      expect(container.read(purchasesProvider).prices, isEmpty);
      expect(
        await container.read(purchasesProvider.notifier).refresh(),
        isFalse,
      );
    });
  });

  test('prices are whatever Play says, only for products on sale', () async {
    final play = _Play()
      ..onSale = [_product(_obsidian, 'BDT 120.00'), _product(_clay, '€1,99')];
    final container = await _start(play);
    final state = container.read(purchasesProvider);

    expect(state.prices, {_obsidian: 'BDT 120.00', _clay: '€1,99'});
    expect(state.canBuy(_obsidian), isTrue);
    expect(state.canBuy(kAllThemesProductId), isFalse);
  });

  group('buying', () {
    late _Play play;
    late ProviderContainer container;

    setUp(() async {
      play = _Play()..onSale = [_product(_obsidian, r'$0.99')];
      container = await _start(play);
    });

    Future<BuyOutcome> buy() =>
        container.read(purchasesProvider.notifier).buy(_obsidian);

    test('a purchase unlocks, is acknowledged and is saved', () async {
      play.onLaunch = (p) => [_purchase(p.id, PurchaseStatus.purchased)];

      expect(await buy(), BuyOutcome.purchased);
      expect(container.read(entitlementProvider), {_obsidian});
      expect(play.acknowledged, [_obsidian]);
      expect(await _savedNow(), [_obsidian]);
    });

    test('closing the sheet changes nothing', () async {
      play.onLaunch = (_) => [_noPurchase(PurchaseStatus.canceled)];

      expect(await buy(), BuyOutcome.cancelled);
      expect(container.read(entitlementProvider), isEmpty);
      expect(play.acknowledged, isEmpty);
    });

    test('an error changes nothing', () async {
      play.onLaunch = (_) => [_noPurchase(PurchaseStatus.error)];

      expect(await buy(), BuyOutcome.failed);
      expect(container.read(entitlementProvider), isEmpty);
    });

    test('a sheet that will not open is a failure', () async {
      play.opensSheet = false;

      expect(await buy(), BuyOutcome.failed);
      expect(container.read(entitlementProvider), isEmpty);
    });

    test('"already owned" errors unlock instead of failing', () async {
      play.onLaunch = (p) {
        play.account = [
          _purchase(p.id, PurchaseStatus.purchased, acknowledged: true),
        ];
        return [_noPurchase(PurchaseStatus.error)];
      };

      expect(await buy(), BuyOutcome.purchased);
      expect(container.read(entitlementProvider), {_obsidian});
    });

    test('a pending payment stays locked until Play confirms it', () async {
      play.onLaunch = (p) => [_purchase(p.id, PurchaseStatus.pending)];

      expect(await buy(), BuyOutcome.pending);
      var state = container.read(purchasesProvider);
      expect(state.owned, isEmpty);
      expect(state.pending, {_obsidian});
      expect(state.canBuy(_obsidian), isFalse);
      // Acknowledging before the money arrives would be refused by Play.
      expect(play.acknowledged, isEmpty);

      play.report([_purchase(_obsidian, PurchaseStatus.purchased)]);
      await _settle();
      state = container.read(purchasesProvider);
      expect(state.owned, {_obsidian});
      expect(state.pending, isEmpty);
      expect(play.acknowledged, [_obsidian]);
    });

    test(
      'a second attempt is not blocked by a sheet that never answered',
      () async {
        final first = buy();
        play.onLaunch = (p) => [_purchase(p.id, PurchaseStatus.purchased)];

        expect(await buy(), BuyOutcome.purchased);
        expect(await first, BuyOutcome.cancelled);
      },
    );
  });

  group('checking with the Play account on start', () {
    test('saved purchases unlock at once and survive being offline', () async {
      final play = _Play()..account = null;
      final container = await _start(play, saved: [_obsidian]);

      expect(container.read(entitlementProvider), {_obsidian});
      expect(await _savedNow(), [_obsidian]);
    });

    test('saved purchases survive a store that is not available', () async {
      final play = _Play()..available = false;
      final container = await _start(play, saved: [kAllThemesProductId]);

      expect(container.read(entitlementProvider), {kAllThemesProductId});
    });

    test('a refunded purchase is taken back', () async {
      final play = _Play()..account = [];
      final container = await _start(play, saved: [_obsidian]);

      expect(container.read(entitlementProvider), isEmpty);
      expect(await _savedNow(), isEmpty);
    });

    test('purchases made on another phone appear', () async {
      final play = _Play()
        ..account = [
          _purchase(
            kAllThemesProductId,
            PurchaseStatus.purchased,
            acknowledged: true,
          ),
        ];
      final container = await _start(play);

      expect(container.read(entitlementProvider), {kAllThemesProductId});
      expect(await _savedNow(), [kAllThemesProductId]);
      expect(play.acknowledged, isEmpty);
    });

    test(
      'a purchase that was never acknowledged is acknowledged now',
      () async {
        final play = _Play()
          ..account = [_purchase(_clay, PurchaseStatus.purchased)];
        await _start(play);

        expect(play.acknowledged, [_clay]);
      },
    );

    test('a payment still pending is neither owned nor acknowledged', () async {
      final play = _Play()
        ..onSale = [_product(_clay, r'$1.99')]
        ..account = [_purchase(_clay, PurchaseStatus.pending)];
      final container = await _start(play);
      final state = container.read(purchasesProvider);

      expect(state.owned, isEmpty);
      expect(state.pending, {_clay});
      expect(play.acknowledged, isEmpty);
    });
  });

  test('restore reports whether Play answered', () async {
    final play = _Play();
    final container = await _start(play);
    final service = container.read(purchasesProvider.notifier);

    play.account = [
      _purchase(_obsidian, PurchaseStatus.purchased, acknowledged: true),
    ];
    expect(await service.refresh(), isTrue);
    expect(container.read(entitlementProvider), {_obsidian});

    play.account = null;
    expect(await service.refresh(), isFalse);
    expect(container.read(entitlementProvider), {_obsidian});
  });

  group('bundle saving', () {
    Map<String, double> singles(double each) => {
      for (final id in kProductIds)
        if (id != kAllThemesProductId) id: each,
    };

    test('is the whole percent off buying everything singly', () {
      // 12 items at 10 each = 120; the bundle at 40 is two thirds off.
      final state = PurchaseState(
        amounts: {...singles(10.0), kAllThemesProductId: 40.0},
      );
      expect(state.bundleSaving, 66);
    });

    test('is not claimed while any price is missing', () {
      expect(const PurchaseState().bundleSaving, isNull);
      expect(PurchaseState(amounts: singles(10.0)).bundleSaving, isNull);
      final partial = {...singles(10.0), kAllThemesProductId: 40.0}
        ..remove('material_clay');
      expect(PurchaseState(amounts: partial).bundleSaving, isNull);
    });

    test('is not claimed when the bundle is no bargain', () {
      final state = PurchaseState(
        amounts: {...singles(10.0), kAllThemesProductId: 119.0},
      );
      expect(state.bundleSaving, isNull);
    });

    test('uses the numbers Play gives', () async {
      final play = _Play()..onSale = [_product(_obsidian, 'BDT 60.00')];
      final container = await _start(play);
      expect(container.read(purchasesProvider).amounts, {_obsidian: 1.0});
    });
  });

  group('totals are written the way the store writes prices', () {
    test('dollars', () {
      expect(moneyLike(r'$6.99', 6.99, 19.88), r'$19.88');
      expect(moneyLike(r'$6.99', 6.99, 4.95), r'$4.95');
    });

    test(
      'a currency code in front, with the thousands mark if one is seen',
      () {
        expect(moneyLike('BDT 400.00', 400, 1200), 'BDT 1200.00');
        expect(
          moneyLike('BDT 400.00', 400, 1200, others: ['BDT 1,100.00']),
          'BDT 1,200.00',
        );
      },
    );

    test('comma decimals and the sign behind', () {
      expect(moneyLike('6,99 €', 6.99, 19.88), '19,88 €');
      expect(moneyLike('1.234,50 €', 1234.5, 2469), '2.469,00 €');
    });

    test('no decimals at all', () {
      expect(moneyLike('Rp 59.000', 59000, 162000), 'Rp 162.000');
      expect(moneyLike('¥700', 700, 2100), '¥2100');
    });

    test('three decimals', () {
      expect(moneyLike('KWD 0.300', 0.3, 1.25), 'KWD 1.250');
    });

    test('gives up rather than guess', () {
      expect(moneyLike('Free', 0, 5), isNull);
      // The text and the amount do not agree.
      expect(moneyLike(r'$6.99', 123.0, 5), isNull);
    });
  });

  test('every product id is unique and the bundle is among them', () {
    expect(kProductIds, contains(kAllThemesProductId));
    expect(kProductIds.length, kBundleItems.length + 1);
  });
}
