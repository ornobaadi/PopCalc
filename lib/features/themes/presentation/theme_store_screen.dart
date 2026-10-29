import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

import 'dunesday_bundle.dart';
import 'purchase_feedback.dart';
import 'store_widgets.dart';
import 'theme_bundle_sheet.dart';
import 'theme_card.dart';
import 'theme_detail_sheet.dart';

/// The skin store, kept as plain as the calculator: the everything bundle,
/// then what can still be bought (materials, then skins) as two-column
/// grids of swatches, then what is already owned. Free skins live in the
/// settings sheet.
class ThemeStoreScreen extends ConsumerStatefulWidget {
  const ThemeStoreScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => const ThemeStoreScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  ConsumerState<ThemeStoreScreen> createState() => _ThemeStoreScreenState();
}

class _ThemeStoreScreenState extends ConsumerState<ThemeStoreScreen> {
  bool _restoring = false;
  String? _restoreNote;

  @override
  void initState() {
    super.initState();
    recheckPrices(ref, kProductIds);
  }

  // Play has no separate restore: asking the account what it holds is it.
  Future<void> _restore() async {
    AppHaptics.selectionClick();
    setState(() {
      _restoring = true;
      _restoreNote = null;
    });
    final reached = await ref.read(purchasesProvider.notifier).refresh();
    if (!mounted) return;
    final owned = ref.read(purchasesProvider).owned;
    setState(() {
      _restoring = false;
      _restoreNote = !reached
          ? 'Could not reach Google Play. Try again in a moment.'
          : owned.isEmpty
          ? 'No purchases found for this Google account.'
          : 'Your purchases are restored.';
    });
  }

  static const _gutter = 20.0;
  static const _gap = 14.0;

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(themeProvider);
    final colors = ThemeColors.of(currentMode);
    final purchases = ref.watch(purchasesProvider);
    final owned = purchases.owned;
    bool has(SkinInfo skin) => ownsSkin(owned, skin);
    final ownsAll = kBundleItems.every(has);

    final premiumSkins = kSkins.where((s) => s.premium).toList();
    // What is theirs already steps out of the way of what is still on sale.
    final yours = [
      ...premiumSkins,
      ...kMaterials,
      ...kDrops,
    ].where(has).toList();
    // Drops still to come or on sale; once over they are gone for good.
    final drops = kDrops.where((s) => !has(s) && !s.drop!.over).toList();

    Widget card(SkinInfo skin) {
      final SkinStanding standing;
      final String status;
      if (skin.mode == currentMode) {
        standing = SkinStanding.active;
        status = 'ACTIVE';
      } else if (has(skin)) {
        standing = SkinStanding.owned;
        status = 'OWNED';
      } else if (skin.drop?.upcoming ?? false) {
        standing = SkinStanding.notForSale;
        status = dropOpens(skin.drop!);
      } else {
        final productId = skin.productId!;
        standing = purchases.canBuy(productId)
            ? SkinStanding.forSale
            : SkinStanding.notForSale;
        status = priceTag(purchases, productId, unavailable: 'SOON');
      }
      return SkinCard(
        skin: skin,
        colors: colors,
        status: status,
        standing: standing,
        onTap: () {
          AppHaptics.selectionClick();
          SkinDetailSheet.show(context, skin);
        },
      );
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440.0),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth =
                    (constraints.maxWidth - _gutter * 2 - _gap) / 2;

                // A titled two-column grid; nothing at all when empty.
                List<Widget> section(
                  String title,
                  String hint,
                  List<SkinInfo> items,
                ) => items.isEmpty
                    ? const []
                    : [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _gutter,
                            30.0,
                            _gutter,
                            0.0,
                          ),
                          child: Text(
                            title,
                            style: TextStyle(
                              fontFamily: 'BebasNeue',
                              fontSize: 24.0,
                              letterSpacing: 1.8,
                              height: 1.1,
                              color: colors.ink,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                            _gutter,
                            2.0,
                            _gutter,
                            14.0,
                          ),
                          child: Text(
                            hint,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12.0,
                              height: 1.35,
                              color: colors.inkSoft,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: _gutter,
                          ),
                          child: GridView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: _gap,
                                  mainAxisSpacing: 18.0,
                                  mainAxisExtent:
                                      cardWidth / SkinCard.swatchAspect +
                                      SkinCard.captionHeight,
                                ),
                            itemCount: items.length,
                            itemBuilder: (context, i) => card(items[i]),
                          ),
                        ),
                      ];

                return ListView(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 28.0),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 8.0, right: _gutter),
                      child: Row(
                        children: [
                          IconButton(
                            tooltip: 'Back',
                            onPressed: () {
                              AppHaptics.selectionClick();
                              Navigator.of(context).pop();
                            },
                            icon: Icon(
                              Icons.arrow_back_rounded,
                              color: colors.ink,
                              size: 22.0,
                            ),
                          ),
                          Expanded(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'SKIN STORE',
                                style: TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 24.0,
                                  letterSpacing: 1.8,
                                  color: colors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        _gutter,
                        8.0,
                        _gutter,
                        0.0,
                      ),
                      child: _BundleCard(
                        colors: colors,
                        ownsAll: ownsAll,
                        saving: ownsAll ? null : purchases.bundleSaving,
                        onTap: () {
                          AppHaptics.selectionClick();
                          BundleDetailSheet.show(context, skinOf(currentMode));
                        },
                      ),
                    ),
                    // Both drops at once, while they are on sale
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20.0, 18.0, 20.0, 0.0),
                      child: DunesdayBanner(),
                    ),
                    if (drops.isNotEmpty)
                      ...section(
                        'LIMITED DROP',
                        dropLine(drops.first.drop!),
                        drops,
                      ),
                    ...section(
                      'MATERIALS',
                      'Look, sound and haptics, made as one set.',
                      kMaterials.where((s) => !has(s)).toList(),
                    ),
                    ...section(
                      'SKINS',
                      'A new face for every numeral and key.',
                      premiumSkins.where((s) => !has(s)).toList(),
                    ),
                    ...section('YOURS', 'Tap one to put it on.', yours),
                    const SizedBox(height: 22.0),
                    Center(
                      child: TextButton(
                        onPressed: _restoring ? null : _restore,
                        child: Text(
                          _restoring ? 'CHECKING...' : 'RESTORE PURCHASES',
                          style: TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 14.0,
                            letterSpacing: 1.6,
                            color: colors.inkSoft,
                          ),
                        ),
                      ),
                    ),
                    if (_restoreNote != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: _gutter,
                        ),
                        child: Text(
                          _restoreNote!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            height: 1.35,
                            color: colors.inkSoft,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The everything bundle, the store's headline: what it is and what it
/// saves, beside three of the phones it unlocks. It carries no price; the
/// bundle sheet it opens makes the case.
class _BundleCard extends StatelessWidget {
  final ThemeColors colors;
  final bool ownsAll;
  final int? saving;
  final VoidCallback onTap;

  const _BundleCard({
    required this.colors,
    required this.ownsAll,
    required this.saving,
    required this.onTap,
  });

  // Mode, distance from the right edge, from the top, width and lean.
  // Back to front.
  static const _phones = [
    (AppThemeMode.velvet, 104.0, 46.0, 84.0, -0.16),
    (AppThemeMode.chrome, 4.0, 52.0, 84.0, 0.14),
    (AppThemeMode.neon, 48.0, 22.0, 98.0, -0.02),
  ];

  @override
  Widget build(BuildContext context) {
    final skinCount = kBundleItems.where((s) => !s.isMaterial).length;
    final materialCount = kBundleItems.length - skinCount;
    return Pressable(
      key: const ValueKey('bundle-card'),
      onTap: onTap,
      child: Container(
        height: 176.0,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.ink.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(28.0),
        ),
        // Words on the left, phones on the right, sharing the width
        // whatever the phone's size. The words shrink as one block
        // rather than wrap or overflow on a narrow screen.
        child: Row(
          children: [
            Expanded(
              flex: 11,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20.0, 14.0, 16.0, 14.0),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (saving != null) ...[
                        SavingChip(
                          percent: saving!,
                          color: colors.accent,
                          onColor: colors.bg,
                          fontSize: 13.0,
                        ),
                        const SizedBox(height: 8.0),
                      ],
                      Text(
                        'EVERYTHING',
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 34.0,
                          letterSpacing: 2.0,
                          height: 1.05,
                          color: colors.ink,
                        ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        ownsAll
                            ? 'All yours. Thank you.'
                            : '$skinCount skins, $materialCount materials.\n'
                                  'One payment.',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          height: 1.35,
                          color: colors.inkSoft,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SEE THE BUNDLE',
                            style: TextStyle(
                              fontFamily: 'BebasNeue',
                              fontSize: 15.0,
                              letterSpacing: 1.4,
                              color: colors.accent,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18.0,
                            color: colors.accent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 10,
              child: FittedBox(
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: 190.0,
                  height: 176.0,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      for (final (mode, right, top, width, lean) in _phones)
                        Positioned(
                          right: right,
                          top: top,
                          width: width,
                          child: Transform.rotate(
                            angle: lean,
                            child: FittedBox(
                              child: SkinPhone(skin: skinOf(mode)),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
