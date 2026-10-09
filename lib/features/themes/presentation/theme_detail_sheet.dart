import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

import 'purchase_feedback.dart';
import 'store_widgets.dart';
import 'theme_bundle_sheet.dart';
import 'theme_card.dart';
import 'theme_preview_overlay.dart';

/// Product sheet for one skin, drawn in that skin's own colours:
/// mockup, pitch, hold-to-preview and buy / apply.
class SkinDetailSheet extends ConsumerStatefulWidget {
  final SkinInfo skin;

  /// Opened from the bundle sheet, which is still underneath, so there is
  /// no need to point back at the bundle.
  final bool fromBundle;

  const SkinDetailSheet({
    super.key,
    required this.skin,
    this.fromBundle = false,
  });

  static Future<void> show(
    BuildContext context,
    SkinInfo skin, {
    bool fromBundle = false,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SkinDetailSheet(skin: skin, fromBundle: fromBundle),
    );
  }

  @override
  ConsumerState<SkinDetailSheet> createState() => _SkinDetailSheetState();
}

class _SkinDetailSheetState extends ConsumerState<SkinDetailSheet> {
  final _preview = ThemePreview();
  bool _buying = false;
  BuyOutcome? _outcome;
  int _demoTaps = 0;

  @override
  void initState() {
    super.initState();
    recheckPrices(ref, [?widget.skin.productId]);
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _outcome = null;
    });
    final outcome = await ref
        .read(purchasesProvider.notifier)
        .buy(widget.skin.productId!);
    purchaseHaptic(outcome);
    if (!mounted) return;
    setState(() {
      _buying = false;
      _outcome = outcome;
    });
  }

  // Each tap plays the next digit, so a few taps give a feel for typing.
  void _demo(MaterialFeel feel) {
    final digit = Sfx.values[_demoTaps++ % 10];
    AppSounds.previewMaterial(feel.soundFolder, digit);
    AppHaptics.demo(feel.haptics);
  }

  void _apply() {
    AppHaptics.selectionClick();
    ref.read(themeProvider.notifier).setTheme(widget.skin.mode);
    Navigator.of(context).pop();
  }

  // Swaps this sheet for the bundle's, in this skin's colours.
  void _openBundle() {
    AppHaptics.selectionClick();
    final navigator = Navigator.of(context);
    navigator.pop();
    BundleDetailSheet.show(navigator.context, widget.skin);
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final c = skin.colors;
    final purchases = ref.watch(purchasesProvider);
    final owned = ownsSkin(purchases.owned, skin);
    final active = ref.watch(themeProvider) == skin.mode;

    final Widget primary;
    final VoidCallback? onPrimary;
    String? note;
    var offerBundle = false;
    if (active) {
      primary = const Text('ACTIVE');
      onPrimary = null;
    } else if (owned) {
      primary = const Text('APPLY');
      onPrimary = _apply;
    } else {
      final productId = skin.productId!;
      final canBuy = purchases.canBuy(productId);
      final price = Text(priceTag(purchases, productId));
      primary = canBuy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('UNLOCK'),
                const SizedBox(width: 12.0),
                price,
              ],
            )
          : price;
      onPrimary = _buying || !canBuy ? null : _buy;
      note = purchaseNote(purchases, productId, _outcome);
      offerBundle =
          !widget.fromBundle &&
          purchases.canBuy(kAllThemesProductId) &&
          purchases.bundleSaving != null;
    }

    TextStyle small({Color? color, double size = 10.5}) => TextStyle(
      fontFamily: 'Inter',
      fontSize: size,
      letterSpacing: 1.6,
      color: color ?? c.inkSoft,
    );

    return StoreSheet(
      colors: c,
      body: [
        Center(
          child: SizedBox(
            width: 176.0,
            child: SkinMockup(
              skin: skin,
              borderColor: c.accent,
              borderWidth: 2.0,
              radius: 28.0,
            ),
          ),
        ),
        const SizedBox(height: 20.0),
        Text(
          'MODEL  ${skin.modelCode}',
          textAlign: TextAlign.center,
          style: small(),
        ),
        const SizedBox(height: 2.0),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            skin.label,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 42.0,
              letterSpacing: 2.4,
              height: 1.1,
              color: c.accent,
            ),
          ),
        ),
        Text(
          skin.tagline,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 15.0,
            height: 1.25,
            color: c.ink,
          ),
        ),
        const SizedBox(height: 10.0),
        Text(
          skin.description,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            height: 1.45,
            color: c.inkSoft,
          ),
        ),
        if (skin.isMaterial) ...[
          const SizedBox(height: 22.0),
          Text(
            skin.feels.length > 1
                ? 'TAP A SWITCH TO HEAR AND FEEL IT'
                : 'TAP TO HEAR AND FEEL IT',
            textAlign: TextAlign.center,
            style: small(),
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              for (final feel in skin.feels) ...[
                if (feel != skin.feels.first) const SizedBox(width: 8.0),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) => _demo(feel),
                    child: Container(
                      height: 48.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(16.0),
                        border: Border.all(
                          color: c.accent.withValues(alpha: 0.7),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        skin.feels.length > 1 ? feel.label : 'PRESS A KEY',
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 17.0,
                          letterSpacing: 1.6,
                          color: c.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
      footer: [
        // Hold to preview: finger down shows the calculator in this skin,
        // lifting brings the sheet back.
        Listener(
          onPointerDown: (_) => _preview.show(context, skin),
          onPointerUp: (_) => _preview.hide(),
          onPointerCancel: (_) => _preview.hide(),
          child: StoreButton(
            colors: c,
            filled: false,
            onTap: () {},
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.touch_app_rounded, size: 18.0, color: c.ink),
                const SizedBox(width: 8.0),
                const Text('HOLD TO PREVIEW'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10.0),
        StoreButton(colors: c, onTap: onPrimary, child: primary),
        if (note != null) PurchaseNote(note, color: c.inkSoft),
        if (offerBundle)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openBundle,
            child: Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 2.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Or everything for '
                      '${purchases.prices[kAllThemesProductId]}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        color: c.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  SavingChip(
                    percent: purchases.bundleSaving!,
                    color: c.accent,
                    onColor: c.bg,
                    fontSize: 12.0,
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18.0,
                    color: c.inkSoft,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
