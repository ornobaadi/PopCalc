import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

import 'play_purchase_service.dart';

/// How an attempt to buy something ended.
enum BuyOutcome {
  /// Paid for and unlocked.
  purchased,

  /// The store took the order but not the money yet (cash, bank transfer).
  /// It unlocks by itself once the payment is confirmed.
  pending,

  /// The buyer closed the store's sheet.
  cancelled,

  /// The store is not selling this product (yet), or cannot be reached.
  unavailable,

  /// Anything else that stopped the purchase.
  failed,
}

/// What the app knows about the store and this buyer's purchases.
@immutable
class PurchaseState {
  /// Owned product ids. Saved on the device, so they keep working offline.
  final Set<String> owned;

  /// Ordered but not paid for yet; see [BuyOutcome.pending].
  final Set<String> pending;

  /// The store's own price text by product id. A product missing from here
  /// is not on sale, so it cannot be bought.
  final Map<String, String> prices;

  /// The same prices as numbers, all in the buyer's currency.
  final Map<String, double> amounts;

  /// The saved purchases have been read.
  final bool loaded;

  /// The store is being asked for prices and purchases right now.
  final bool checking;

  const PurchaseState({
    this.owned = const {},
    this.pending = const {},
    this.prices = const {},
    this.amounts = const {},
    this.loaded = false,
    this.checking = false,
  });

  /// Whether tapping the price of [productId] can start a purchase.
  bool canBuy(String productId) =>
      prices.containsKey(productId) && !pending.contains(productId);

  /// How much cheaper the bundle is than buying everything in it singly,
  /// as a whole percent. Null unless every price is known, so it never
  /// claims a saving it cannot work out, and null when there is little or
  /// none to speak of.
  int? get bundleSaving {
    final bundle = amounts[kAllThemesProductId];
    if (bundle == null) return null;
    var singly = 0.0;
    for (final id in kProductIds) {
      if (id == kAllThemesProductId) continue;
      final amount = amounts[id];
      if (amount == null) return null;
      singly += amount;
    }
    if (singly <= 0.0) return null;
    final percent = ((1.0 - bundle / singly) * 100.0).floor();
    return percent < 5 ? null : percent;
  }

  PurchaseState copyWith({
    Set<String>? owned,
    Set<String>? pending,
    Map<String, String>? prices,
    Map<String, double>? amounts,
    bool? loaded,
    bool? checking,
  }) {
    return PurchaseState(
      owned: owned ?? this.owned,
      pending: pending ?? this.pending,
      prices: prices ?? this.prices,
      amounts: amounts ?? this.amounts,
      loaded: loaded ?? this.loaded,
      checking: checking ?? this.checking,
    );
  }
}

/// A billing backend. The UI watches [purchasesProvider] for the state and
/// calls [buy] and [refresh] on its notifier.
abstract class PurchaseService extends StateNotifier<PurchaseState> {
  PurchaseService(super.state);

  Future<BuyOutcome> buy(String productId);

  /// Asks the store again for prices and for what this account owns, which
  /// is also how purchases are restored. False if the store could not say.
  Future<bool> refresh();
}

/// Stand-in store for debug builds and tests: grants instantly, for free,
/// and remembers locally.
class FakePurchaseService extends PurchaseService {
  static const _kOwnedKey = 'settings_owned_products';

  FakePurchaseService()
    : super(
        PurchaseState(
          prices: {
            for (final id in kProductIds)
              id: '\$${_amount(id).toStringAsFixed(2)}',
          },
          amounts: {for (final id in kProductIds) id: _amount(id)},
        ),
      ) {
    refresh();
  }

  // The base prices planned for Play Console.
  static double _amount(String productId) => productId == kAllThemesProductId
      ? 6.99
      : productId == 'material_mechanical'
      ? 2.99
      : productId.startsWith('material_')
      ? 1.99
      : 0.99;

  @override
  Future<bool> refresh() async {
    var saved = const <String>[];
    var read = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getStringList(_kOwnedKey) ?? const [];
      read = true;
    } catch (_) {}
    if (mounted) {
      state = state.copyWith(owned: {...state.owned, ...saved}, loaded: true);
    }
    return read;
  }

  @override
  Future<BuyOutcome> buy(String productId) async {
    try {
      final owned = {...state.owned, productId};
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kOwnedKey, owned.toList());
      if (mounted) state = state.copyWith(owned: owned);
      return BuyOutcome.purchased;
    } catch (_) {
      return BuyOutcome.failed;
    }
  }
}

/// Play only sells to the release build's package id. Debug and profile
/// builds install as a separate app ("PopCalc Dev") that Play knows nothing
/// about, so they and the tests keep the stand-in store.
final purchasesProvider = StateNotifierProvider<PurchaseService, PurchaseState>(
  (ref) {
    return kReleaseMode ? PlayPurchaseService() : FakePurchaseService();
  },
);

/// The owned product ids, for anything that only asks what is unlocked.
final entitlementProvider = Provider<Set<String>>((ref) {
  return ref.watch(purchasesProvider.select((s) => s.owned));
});

/// Whether [skin] can be applied given the [owned] product ids.
bool ownsSkin(
  Set<String> owned,
  SkinInfo skin, {
  bool locked = kPremiumLocked,
}) =>
    !skin.premium ||
    !locked ||
    owned.contains(kAllThemesProductId) ||
    owned.contains(skin.productId);
