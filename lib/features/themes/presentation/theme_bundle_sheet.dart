import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

import 'purchase_feedback.dart';
import 'store_widgets.dart';
import 'theme_card.dart';
import 'theme_detail_sheet.dart';

/// Product sheet for the everything bundle (premium skins and materials),
/// drawn in the colours of the skin that was at the front of the carousel.
/// It makes the case for the bundle: what is in it, and what it costs
/// against buying the same things one by one. Tapping a skin opens its own
/// sheet.
class BundleDetailSheet extends ConsumerStatefulWidget {
  final SkinInfo tone;
  const BundleDetailSheet({super.key, required this.tone});

  static Future<void> show(BuildContext context, SkinInfo tone) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BundleDetailSheet(tone: tone),
    );
  }

  @override
  ConsumerState<BundleDetailSheet> createState() => _BundleDetailSheetState();
}

class _BundleDetailSheetState extends ConsumerState<BundleDetailSheet> {
  bool _buying = false;
  BuyOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    recheckPrices(ref, [kAllThemesProductId]);
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _outcome = null;
    });
    final outcome = await ref
        .read(purchasesProvider.notifier)
        .buy(kAllThemesProductId);
    purchaseHaptic(outcome);
    if (!mounted) return;
    setState(() {
      _buying = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.tone.colors;
    final skins = kBundleItems;
    final skinCount = skins.where((s) => !s.isMaterial).length;
    final materialCount = skins.length - skinCount;
    final purchases = ref.watch(purchasesProvider);
    final ownsAll = skins.every((s) => ownsSkin(purchases.owned, s));

    final canBuy = purchases.canBuy(kAllThemesProductId);
    final price = Text(priceTag(purchases, kAllThemesProductId));
    final Widget primary = ownsAll
        ? const Text('OWNED')
        : canBuy
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('GET EVERYTHING'),
              const SizedBox(width: 12.0),
              price,
            ],
          )
        : price;
    final onPrimary = ownsAll || _buying || !canBuy ? null : _buy;
    final note = ownsAll
        ? null
        : purchaseNote(purchases, kAllThemesProductId, _outcome);
    final value = ownsAll ? null : BundleValue.of(purchases);
    final saving = ownsAll ? null : purchases.bundleSaving;

    return StoreSheet(
      colors: c,
      body: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$skinCount SKINS + $materialCount MATERIALS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  color: c.inkSoft,
                ),
              ),
            ),
            if (saving != null)
              SavingChip(percent: saving, color: c.accent, onColor: c.bg),
          ],
        ),
        const SizedBox(height: 4.0),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            'EVERYTHING BUNDLE',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 38.0,
              letterSpacing: 2.2,
              height: 1.1,
              color: c.accent,
            ),
          ),
        ),
        Text(
          'Everything in the store, for one payment.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 14.0,
            height: 1.35,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 20.0),
        GridView.count(
          crossAxisCount: 4,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final skin in skins)
              Pressable(
                onTap: () {
                  AppHaptics.selectionClick();
                  SkinDetailSheet.show(context, skin, fromBundle: true);
                },
                child: SkinMockup(
                  skin: skin,
                  borderColor: c.ink.withValues(alpha: 0.14),
                  borderWidth: 1.0,
                  radius: 16.0,
                ),
              ),
          ],
        ),
        if (value != null) ...[
          const SizedBox(height: 20.0),
          _ValueCard(
            value: value,
            skinCount: skinCount,
            materialCount: materialCount,
            colors: c,
          ),
        ],
      ],
      footer: [
        StoreButton(colors: c, onTap: onPrimary, child: primary),
        PurchaseNote(
          note ??
              'One payment, no subscription. Yours on every phone signed '
                  'in to your Google account.',
          color: c.inkSoft,
        ),
      ],
    );
  }
}

/// The sum that sells the bundle: what its contents cost one by one, struck
/// through, over what the bundle costs.
class _ValueCard extends StatelessWidget {
  final BundleValue value;
  final int skinCount;
  final int materialCount;
  final ThemeColors colors;

  const _ValueCard({
    required this.value,
    required this.skinCount,
    required this.materialCount,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final plain = TextStyle(
      fontFamily: 'Inter',
      fontSize: 12.5,
      height: 1.3,
      color: c.inkSoft,
    );

    Widget line(String what, String amount, {TextStyle? amountStyle}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(child: Text(what, style: plain)),
              Text(amount, style: amountStyle ?? plain),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
      decoration: BoxDecoration(
        color: c.ink.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Column(
        children: [
          line('$skinCount premium skins', value.skins),
          line('$materialCount materials', value.materials),
          line(
            'Bought one by one',
            value.singly,
            amountStyle: plain.copyWith(
              decoration: TextDecoration.lineThrough,
              decorationColor: c.inkSoft,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1.0, color: c.ink.withValues(alpha: 0.1)),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WITH THE BUNDLE',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 17.0,
                        letterSpacing: 1.4,
                        height: 1.15,
                        color: c.ink,
                      ),
                    ),
                    Text(
                      'You save ${value.saved}',
                      style: plain.copyWith(color: c.accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12.0),
              Text(
                value.bundle,
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 28.0,
                  letterSpacing: 1.0,
                  height: 1.1,
                  color: c.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
