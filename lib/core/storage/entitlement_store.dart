import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

/// What the skin store needs from a billing backend. Play Billing will
/// implement this later; the UI only talks to [entitlementProvider].
abstract class PurchaseService {
  Future<Set<String>> loadOwned();
  Future<bool> buy(String productId);
  Future<Set<String>> restore();
  String priceFor(String productId);
}

/// Stand-in until real billing: grants instantly and remembers locally.
class FakePurchaseService implements PurchaseService {
  static const _kOwnedKey = 'settings_owned_products';

  @override
  Future<Set<String>> loadOwned() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_kOwnedKey) ?? const []).toSet();
    } catch (_) {
      return {};
    }
  }

  @override
  Future<bool> buy(String productId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final owned = (prefs.getStringList(_kOwnedKey) ?? const []).toSet()
        ..add(productId);
      await prefs.setStringList(_kOwnedKey, owned.toList());
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Set<String>> restore() => loadOwned();

  @override
  String priceFor(String productId) =>
      productId == kAllThemesProductId ? r'$2.99' : r'$0.99';
}

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => FakePurchaseService(),
);

final entitlementProvider =
    StateNotifierProvider<EntitlementNotifier, Set<String>>((ref) {
      return EntitlementNotifier(ref.watch(purchaseServiceProvider));
    });

/// State is the set of owned product ids.
class EntitlementNotifier extends StateNotifier<Set<String>> {
  final PurchaseService _service;

  EntitlementNotifier(this._service) : super(const {}) {
    _load();
  }

  Future<void> _load() async {
    final owned = await _service.loadOwned();
    if (mounted) state = {...state, ...owned};
  }

  Future<bool> buy(String productId) async {
    final ok = await _service.buy(productId);
    if (ok && mounted) state = {...state, productId};
    return ok;
  }

  Future<void> restore() async {
    final owned = await _service.restore();
    if (mounted) state = {...state, ...owned};
  }

  String priceFor(String productId) => _service.priceFor(productId);
}

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
