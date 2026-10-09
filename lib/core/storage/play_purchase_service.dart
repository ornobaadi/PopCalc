import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

import 'entitlement_store.dart';

/// The few Play Billing calls PopCalc makes, behind an interface so the
/// purchase rules in [PlayPurchaseService] can be tested without Play.
abstract class BillingGateway {
  /// Purchases as Play reports them: finished, pending, cancelled or failed.
  Stream<List<PurchaseDetails>> get updates;

  Future<bool> isAvailable();

  Future<ProductDetailsResponse> products(Set<String> ids);

  /// Opens Play's purchase sheet. False if Play would not open it.
  Future<bool> launch(ProductDetails product);

  /// Play refunds any purchase that is not acknowledged within three days.
  Future<void> acknowledge(PurchaseDetails purchase);

  /// Everything this Play account holds for the app, or null if Play could
  /// not say (offline, signed out, no Play Store).
  Future<List<PurchaseDetails>?> held();
}

class PlayBillingGateway implements BillingGateway {
  InAppPurchase get _iap => InAppPurchase.instance;

  @override
  Stream<List<PurchaseDetails>> get updates => _iap.purchaseStream;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> products(Set<String> ids) =>
      _iap.queryProductDetails(ids);

  @override
  Future<bool> launch(ProductDetails product) => _iap.buyNonConsumable(
    purchaseParam: PurchaseParam(productDetails: product),
  );

  @override
  Future<void> acknowledge(PurchaseDetails purchase) =>
      _iap.completePurchase(purchase);

  @override
  Future<List<PurchaseDetails>?> held() async {
    final response = await _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
        .queryPastPurchases();
    return response.error == null ? response.pastPurchases : null;
  }
}

/// Google Play Billing. Owned products are saved on the device so skins stay
/// unlocked offline, and are checked against the Play account on every
/// start: a refund takes a skin back, a purchase made on another phone
/// appears. When Play cannot be reached the saved purchases stand.
class PlayPurchaseService extends PurchaseService {
  static const _kOwnedKey = 'purchases_owned';
  static const _patience = Duration(seconds: 12);

  final BillingGateway _play;
  final Map<String, ProductDetails> _products = {};
  StreamSubscription<List<PurchaseDetails>>? _updates;
  Future<bool>? _refreshing;

  // The purchase whose Play sheet is open, if any.
  Completer<BuyOutcome>? _flow;
  String? _flowProduct;

  PlayPurchaseService([BillingGateway? play])
    : _play = play ?? PlayBillingGateway(),
      super(const PurchaseState(checking: true)) {
    _start();
  }

  Future<void> _start() async {
    // Listen first, so nothing Play reports is missed: a pending payment can
    // be confirmed at any moment.
    try {
      _updates = _play.updates.listen(_onUpdates, onError: (_) {});
    } catch (_) {}

    var saved = const <String>[];
    try {
      final prefs = await SharedPreferences.getInstance();
      saved = prefs.getStringList(_kOwnedKey) ?? const [];
    } catch (_) {}
    if (!mounted) return;
    state = state.copyWith(owned: {...state.owned, ...saved}, loaded: true);

    await refresh();
  }

  @override
  void dispose() {
    _updates?.cancel();
    _end(BuyOutcome.cancelled);
    super.dispose();
  }

  @override
  Future<bool> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);

  Future<bool> _refresh() async {
    if (mounted) state = state.copyWith(checking: true);
    var reached = false;
    try {
      if (await _play.isAvailable().timeout(_patience)) {
        final found = await _play.products(kProductIds).timeout(_patience);
        // Added to, never cleared: a failed query looks the same as a store
        // with no products, and must not hide what was already on sale.
        for (final product in found.productDetails) {
          _products[product.id] = product;
        }
        reached = await _matchPlayAccount();
      }
    } catch (_) {}
    if (mounted) {
      state = state.copyWith(
        prices: {for (final p in _products.values) p.id: p.price},
        amounts: {for (final p in _products.values) p.id: p.rawPrice},
        checking: false,
      );
    }
    return reached;
  }

  @override
  Future<BuyOutcome> buy(String productId) async {
    final product = _products[productId];
    if (product == null) return BuyOutcome.unavailable;

    // A sheet that never reported back must not block the next one.
    _end(BuyOutcome.cancelled);
    final flow = _flow = Completer<BuyOutcome>();
    _flowProduct = productId;
    try {
      if (!await _play.launch(product)) await _endFailedFlow();
    } catch (_) {
      _end(BuyOutcome.failed);
    }
    return flow.future;
  }

  Future<void> _onUpdates(List<PurchaseDetails> updates) async {
    for (final purchase in updates) {
      if (!mounted) return;
      switch (purchase.status) {
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _keep({
            ...state.owned,
            purchase.productID,
          }, {...state.pending}..remove(purchase.productID));
          await _acknowledge(purchase);
          _end(BuyOutcome.purchased, purchase.productID);
        case PurchaseStatus.pending:
          await _keep(state.owned, {...state.pending, purchase.productID});
          _end(BuyOutcome.pending, purchase.productID);
        case PurchaseStatus.canceled:
          _end(BuyOutcome.cancelled);
        case PurchaseStatus.error:
          await _endFailedFlow();
      }
    }
  }

  /// Play also reports a failure when the account already owns the product,
  /// so look at the account before calling it one.
  Future<void> _endFailedFlow() async {
    await _matchPlayAccount();
    final owned = mounted && state.owned.contains(_flowProduct);
    _end(owned ? BuyOutcome.purchased : BuyOutcome.failed);
  }

  /// Answers the open purchase. With a [productId], only if it is the one
  /// being bought (Play can report an older, slower purchase meanwhile).
  void _end(BuyOutcome outcome, [String? productId]) {
    final flow = _flow;
    if (flow == null || (productId != null && productId != _flowProduct)) {
      return;
    }
    _flow = null;
    _flowProduct = null;
    flow.complete(outcome);
  }

  /// Makes the saved purchases match what the Play account really holds.
  /// Changes nothing, and returns false, if Play cannot say.
  Future<bool> _matchPlayAccount() async {
    final List<PurchaseDetails>? held;
    try {
      held = await _play.held().timeout(_patience);
    } catch (_) {
      return false;
    }
    if (held == null) return false;

    final paid = [
      for (final purchase in held)
        if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored)
          purchase,
    ];
    await _keep(
      {for (final purchase in paid) purchase.productID},
      {
        for (final purchase in held)
          if (purchase.status == PurchaseStatus.pending) purchase.productID,
      },
    );
    for (final purchase in paid) {
      await _acknowledge(purchase);
    }
    return true;
  }

  /// A failed acknowledgement is retried on the next start, when the
  /// purchase comes back from [BillingGateway.held] still unacknowledged.
  Future<void> _acknowledge(PurchaseDetails purchase) async {
    if (!purchase.pendingCompletePurchase) return;
    try {
      await _play.acknowledge(purchase).timeout(_patience);
    } catch (_) {}
  }

  Future<void> _keep(Set<String> owned, Set<String> pending) async {
    if (!mounted) return;
    state = state.copyWith(owned: owned, pending: pending);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kOwnedKey, owned.toList());
    } catch (_) {}
  }
}
