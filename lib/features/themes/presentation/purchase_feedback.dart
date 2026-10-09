import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

/// A [purchaseNote] as it sits under a sheet's buttons.
class PurchaseNote extends StatelessWidget {
  final String text;
  final Color color;

  const PurchaseNote(this.text, {super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0),
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            height: 1.35,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// What a locked product's price tag says: the store's price, or why there
/// is none. [unavailable] is the wording for a product that is not on sale.
String priceTag(
  PurchaseState purchases,
  String productId, {
  String unavailable = 'NOT AVAILABLE',
}) {
  if (purchases.pending.contains(productId)) return 'PENDING';
  return purchases.prices[productId] ??
      (purchases.checking ? '...' : unavailable);
}

/// A line for under a buy button: why the product cannot be bought right
/// now, or how the [last] attempt went. Null when there is nothing to say.
String? purchaseNote(
  PurchaseState purchases,
  String productId, [
  BuyOutcome? last,
]) {
  if (purchases.pending.contains(productId)) {
    return 'Payment pending. This unlocks by itself as soon as Google Play '
        'confirms it.';
  }
  if (!purchases.prices.containsKey(productId)) {
    return purchases.checking
        ? null
        : 'Not available yet. Check that Google Play is reachable and try '
              'again later.';
  }
  if (last == BuyOutcome.failed) {
    return 'The purchase did not go through. If you were charged, use '
        'Restore purchases in the skin store.';
  }
  return null;
}

/// Purchases are haptics only, like every tap outside the keypad.
void purchaseHaptic(BuyOutcome outcome) {
  switch (outcome) {
    case BuyOutcome.purchased:
      AppHaptics.success();
    case BuyOutcome.pending:
      AppHaptics.lightImpact();
    case BuyOutcome.cancelled:
      break;
    case BuyOutcome.unavailable:
    case BuyOutcome.failed:
      AppHaptics.error();
  }
}

/// Asks the store again when any of [productIds] still has no price (say,
/// the phone was offline at launch). For the initState of anything about to
/// show one.
void recheckPrices(WidgetRef ref, Iterable<String> productIds) {
  final prices = ref.read(purchasesProvider).prices;
  if (productIds.every(prices.containsKey)) return;
  // After this frame: providers cannot change while widgets are building.
  Future.microtask(ref.read(purchasesProvider.notifier).refresh);
}

/// Writes [amount] the way the store wrote [sample] (the price text of
/// something costing [sampleAmount]): same currency mark, decimals and
/// separators. The app only ever shows money as Play formats it, and this
/// is how a total keeps to that. Null if [sample] cannot be read that way.
///
/// [others] are more price texts in the same currency, looked at only for
/// the thousands separator when [sample] is too small to have one.
String? moneyLike(
  String sample,
  double sampleAmount,
  double amount, {
  Iterable<String> others = const [],
}) {
  final run = _number.firstMatch(sample)?.group(0);
  if (run == null) return null;
  final digits = int.tryParse(run.replaceAll(_notDigit, ''));
  if (digits == null) return null;

  // How many of those digits are decimals: whatever makes them add up to
  // the amount the store says this price is.
  var decimals = -1;
  var unit = 1;
  for (var d = 0; d <= 3; d++, unit *= 10) {
    final separated = d == 0 || run.length > d && !_isDigit(run, d);
    if (separated && (sampleAmount * unit).round() == digits) {
      decimals = d;
      break;
    }
  }
  if (decimals < 0) return null;

  String whole(String text) =>
      decimals == 0 ? text : text.substring(0, text.length - decimals - 1);
  final point = decimals == 0 ? '' : run[run.length - decimals - 1];
  var comma = '';
  for (final text in [run, ...others.map((o) => _number.stringMatch(o))]) {
    if (text == null || text.length <= decimals + 1) continue;
    final mark = _notDigit.stringMatch(whole(text));
    if (mark != null) {
      comma = mark;
      break;
    }
  }

  final fixed = amount.toStringAsFixed(decimals);
  final units = whole(fixed);
  final grouped = StringBuffer();
  for (var i = 0; i < units.length; i++) {
    if (i > 0 && (units.length - i) % 3 == 0) grouped.write(comma);
    grouped.write(units[i]);
  }
  final written = decimals == 0
      ? '$grouped'
      : '$grouped$point${fixed.substring(fixed.length - decimals)}';
  return sample.replaceFirst(run, written);
}

final _number = RegExp(r"\d(?:[\d.,'\s]*\d)?");
final _notDigit = RegExp(r'\D');

/// Whether the character [fromEnd] places before the end of [text] is a digit.
bool _isDigit(String text, int fromEnd) {
  final unit = text.codeUnitAt(text.length - fromEnd - 1);
  return unit >= 0x30 && unit <= 0x39;
}

/// The everything bundle against buying its contents one by one, as money
/// in the store's own format.
class BundleValue {
  final String skins;
  final String materials;
  final String singly;
  final String bundle;
  final String saved;
  final int percent;

  const BundleValue({
    required this.skins,
    required this.materials,
    required this.singly,
    required this.bundle,
    required this.saved,
    required this.percent,
  });

  /// Null unless every product has a price and the bundle really is cheaper,
  /// so the sheet never shows a sum it could not work out.
  static BundleValue? of(PurchaseState purchases) {
    final percent = purchases.bundleSaving;
    final bundle = purchases.prices[kAllThemesProductId];
    final bundleAmount = purchases.amounts[kAllThemesProductId];
    if (percent == null || bundle == null || bundleAmount == null) return null;

    double sum(Iterable<SkinInfo> items) => items.fold(
      0.0,
      (total, item) => total + (purchases.amounts[item.productId] ?? 0.0),
    );
    final skins = sum(kSkins.where((s) => s.premium));
    final materials = sum(kMaterials);

    String? money(double amount) => moneyLike(
      bundle,
      bundleAmount,
      amount,
      others: purchases.prices.values,
    );
    final skinsText = money(skins);
    final materialsText = money(materials);
    final singlyText = money(skins + materials);
    final savedText = money(skins + materials - bundleAmount);
    if (skinsText == null ||
        materialsText == null ||
        singlyText == null ||
        savedText == null) {
      return null;
    }
    return BundleValue(
      skins: skinsText,
      materials: materialsText,
      singly: singlyText,
      bundle: bundle,
      saved: savedText,
      percent: percent,
    );
  }
}
