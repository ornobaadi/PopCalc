import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

import 'purchase_feedback.dart';
import 'store_widgets.dart';

import 'package:popcalc/features/calculator/presentation/widgets/doom_mask.dart';
import 'package:popcalc/features/calculator/presentation/widgets/drop_backdrop.dart';
import 'package:popcalc/features/calculator/presentation/widgets/sand_worm.dart';

import 'theme_card.dart';
import 'theme_detail_sheet.dart';

/// Whether the Dunesday pack is worth showing: the drops are on sale and the
/// user does not already own both.
bool showDunesday(Set<String> owned) {
  final drop = kDrops.first.drop!;
  return drop.open && !kDrops.every((s) => ownsSkin(owned, s));
}

/// Whole percent off buying both drops singly, or null while a price is
/// missing.
int? dunesdaySaving(PurchaseState p) {
  final pack = p.amounts[kDropBundleId];
  var singly = 0.0;
  for (final s in kDrops) {
    final a = p.amounts[s.productId];
    if (a == null) return null;
    singly += a;
  }
  if (pack == null || singly <= 0) return null;
  final percent = ((1 - pack / singly) * 100).floor();
  return percent < 5 ? null : percent;
}

/// Both drops bought one by one, written in Play's own currency format.
String? dunesdaySingly(PurchaseState p) {
  final first = kDrops.first.productId!;
  final sample = p.prices[first];
  final sampleAmount = p.amounts[first];
  if (sample == null || sampleAmount == null) return null;
  var total = 0.0;
  for (final s in kDrops) {
    final a = p.amounts[s.productId];
    if (a == null) return null;
    total += a;
  }
  return moneyLike(sample, sampleAmount, total);
}

const _copper = Color(0xFFE07A35);
const _green = Color(0xFF2FE274);
const _sand = Color(0xFFF7E4B8);

/// "DUNESDAY" painted from Mirage's sand into Reckoning's green.
class _Title extends StatelessWidget {
  final String text;
  final double size;
  const _Title(this.text, this.size);

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (r) => const LinearGradient(
      colors: [_sand, _copper, _green],
      stops: [0.0, 0.45, 1.0],
    ).createShader(r),
    child: Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: size,
        letterSpacing: size * 0.06,
        height: 1.0,
        color: Colors.white,
      ),
    ),
  );
}

/// A tiny caps label with wide tracking.
Widget _eyebrow(String text, Color color) => Text(
  text,
  style: TextStyle(
    fontFamily: 'BebasNeue',
    fontSize: 11.0,
    letterSpacing: 2.6,
    height: 1.2,
    color: color,
  ),
);

/// The menu's small banner for both limited drops: copper dusk on the left,
/// green doom on the right, two phones, a title and a price.
class DunesdayBanner extends ConsumerWidget {
  const DunesdayBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchases = ref.watch(purchasesProvider);
    if (!showDunesday(purchases.owned)) return const SizedBox.shrink();
    final singly = dunesdaySingly(purchases);
    return Pressable(
      key: const ValueKey('dunesday-banner'),
      onTap: () {
        AppHaptics.selectionClick();
        DunesdayBundleSheet.show(context);
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 88.0),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFF0B0907),
          borderRadius: BorderRadius.circular(22.0),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            // Two glows meeting in the dark.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-1.0, 1.0),
                    radius: 1.4,
                    colors: [
                      _copper.withValues(alpha: 0.55),
                      _copper.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(1.0, -1.0),
                    radius: 1.2,
                    colors: [
                      _green.withValues(alpha: 0.35),
                      _green.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 50.0,
              top: 14.0,
              width: 50.0,
              child: Transform.rotate(
                angle: -0.14,
                child: FittedBox(child: SkinPhone(skin: kDrops.first)),
              ),
            ),
            Positioned(
              right: 10.0,
              top: 20.0,
              width: 50.0,
              child: Transform.rotate(
                angle: 0.12,
                child: FittedBox(child: SkinPhone(skin: kDrops.last)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18.0, 14.0, 118.0, 14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _eyebrow('LIMITED EDITION', _sand.withValues(alpha: 0.7)),
                  const SizedBox(height: 2.0),
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: _Title('DUNESDAY', 34.0),
                  ),
                  const SizedBox(height: 4.0),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          priceTag(purchases, kDropBundleId),
                          style: const TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 18.0,
                            letterSpacing: 1.0,
                            height: 1.1,
                            color: _sand,
                          ),
                        ),
                        if (singly != null) ...[
                          const SizedBox(width: 8.0),
                          Text(
                            singly,
                            style: TextStyle(
                              fontFamily: 'BebasNeue',
                              fontSize: 14.0,
                              letterSpacing: 1.0,
                              height: 1.1,
                              color: _sand.withValues(alpha: 0.4),
                              decoration: TextDecoration.lineThrough,
                              decorationColor: _sand.withValues(alpha: 0.4),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The Dunesday pack's sheet: the two drops, the price, one button.
class DunesdayBundleSheet extends ConsumerStatefulWidget {
  const DunesdayBundleSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const DunesdayBundleSheet(),
  );

  @override
  ConsumerState<DunesdayBundleSheet> createState() => _DunesdaySheetState();
}

class _DunesdaySheetState extends ConsumerState<DunesdayBundleSheet> {
  bool _buying = false;
  BuyOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    recheckPrices(ref, [kDropBundleId, for (final s in kDrops) s.productId!]);
  }

  Future<void> _buy() async {
    setState(() {
      _buying = true;
      _outcome = null;
    });
    final outcome = await ref
        .read(purchasesProvider.notifier)
        .buy(kDropBundleId);
    purchaseHaptic(outcome);
    if (!mounted) return;
    setState(() {
      _buying = false;
      _outcome = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = skinOf(AppThemeMode.reckoning).colors;
    final purchases = ref.watch(purchasesProvider);
    final ownsBoth = kDrops.every((s) => ownsSkin(purchases.owned, s));
    final open = kDrops.first.drop!.open;
    final canBuy = open && purchases.canBuy(kDropBundleId);
    final price = priceTag(purchases, kDropBundleId);
    final singly = dunesdaySingly(purchases);
    final note = ownsBoth
        ? null
        : purchaseNote(purchases, kDropBundleId, _outcome);

    return StoreSheet(
      colors: c,
      body: [
        Center(
          child: _eyebrow('LIMITED EDITION', _sand.withValues(alpha: 0.6)),
        ),
        const SizedBox(height: 6.0),
        const Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _Title('DUNESDAY', 54.0),
          ),
        ),
        const SizedBox(height: 14.0),
        const _Features(),
        const SizedBox(height: 20.0),
        Row(
          children: [
            for (final s in kDrops) ...[
              Expanded(
                child: Pressable(
                  onTap: () {
                    AppHaptics.selectionClick();
                    SkinDetailSheet.show(context, s, fromBundle: true);
                  },
                  child: Column(
                    children: [
                      DropShowcase(skin: s),
                      const SizedBox(height: 8.0),
                      Text(
                        s.label,
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 15.0,
                          letterSpacing: 2.0,
                          color: s.colors.accent,
                        ),
                      ),
                      Text(
                        _pitch[s.mode]!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11.0,
                          height: 1.3,
                          color: c.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (s != kDrops.last) const SizedBox(width: 12.0),
            ],
          ],
        ),
      ],
      footer: [
        if (!ownsBoth && singly != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  singly,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 20.0,
                    color: c.inkSoft,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: c.inkSoft,
                  ),
                ),
                const SizedBox(width: 10.0),
                Text(
                  price,
                  style: const TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 34.0,
                    color: _green,
                  ),
                ),
              ],
            ),
          ),
        StoreButton(
          colors: c,
          onTap: ownsBoth || _buying || !canBuy ? null : _buy,
          child: Text(
            ownsBoth
                ? 'OWNED'
                : !open
                ? 'GONE'
                : canBuy
                ? 'GET BOTH'
                : price,
          ),
        ),
        if (note != null) PurchaseNote(note, color: c.inkSoft),
      ],
    );
  }
}

/// One line under each drop: what it is, and that it hides something.
const _pitch = {
  AppThemeMode.mirage: 'Living dunes.\nSomething sleeps below.',
  AppThemeMode.reckoning: 'A clock on your time.\nSomeone is waiting.',
};

/// What every drop brings, in as few words as fit.
class _Features extends StatelessWidget {
  const _Features();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.visibility_rounded, 'HIDDEN SCENE'),
      (Icons.graphic_eq_rounded, 'SOUNDS'),
      (Icons.vibration_rounded, 'HAPTICS'),
      (Icons.motion_photos_on_rounded, 'ALIVE'),
    ];
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8.0,
      runSpacing: 8.0,
      children: [
        for (final (icon, label) in items)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10.0,
              vertical: 5.0,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13.0, color: _sand.withValues(alpha: 0.8)),
                const SizedBox(width: 5.0),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 12.0,
                    letterSpacing: 1.6,
                    height: 1.2,
                    color: _sand.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A drop's showcase: its phone, then every few seconds a glimpse of the
/// hidden moment (the worm, the masked figure), crossfading back and forth.
class DropShowcase extends StatefulWidget {
  final SkinInfo skin;
  const DropShowcase({super.key, required this.skin});

  @override
  State<DropShowcase> createState() => _DropShowcaseState();
}

class _DropShowcaseState extends State<DropShowcase>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final c = skin.colors;
    // Mirage shows its secret in the second half, Reckoning in the first,
    // so one of the two is always giving something away.
    final first = skin.mode == AppThemeMode.reckoning;
    return AnimatedBuilder(
      animation: _cycle,
      builder: (_, _) {
        final secret = (_cycle.value < 0.5) == first;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 600),
          child: secret
              ? AspectRatio(
                  key: const ValueKey('secret'),
                  aspectRatio: 0.78,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20.0),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.6),
                      ),
                      gradient: RadialGradient(
                        center: const Alignment(0.2, -0.3),
                        radius: 1.3,
                        colors: [c.bgShade, c.bg],
                      ),
                    ),
                    child: Stack(
                      children: [
                        DropBackdrop(colors: c),
                        Positioned.fill(
                          child: skin.mode == AppThemeMode.mirage
                              ? const WormGlimpse()
                              : MaskGlimpse(light: c.accent),
                        ),
                        Positioned(
                          left: 10.0,
                          top: 10.0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7.0,
                              vertical: 2.0,
                            ),
                            decoration: BoxDecoration(
                              color: c.accent,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: Text(
                              'SECRET',
                              style: TextStyle(
                                fontFamily: 'BebasNeue',
                                fontSize: 11.0,
                                letterSpacing: 1.6,
                                height: 1.2,
                                color: c.bg,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SkinSwatch(
                  key: const ValueKey('phone'),
                  skin: skin,
                  borderColor: c.accent.withValues(alpha: 0.35),
                  borderWidth: 1.0,
                  radius: 20.0,
                  aspectRatio: 0.78,
                ),
        );
      },
    );
  }
}

/// What each drop brings, one short line per perk, for its own sheet.
const _perks = {
  AppThemeMode.mirage: [
    (Icons.visibility_rounded, 'SECRET SCENE'),
    (Icons.wb_twilight_rounded, 'LIVE SKY'),
    (Icons.graphic_eq_rounded, 'FILM SOUNDS'),
    (Icons.vibration_rounded, 'OWN HAPTICS'),
  ],
  AppThemeMode.reckoning: [
    (Icons.visibility_rounded, 'SECRET SCENE'),
    (Icons.schedule_rounded, 'REAL CLOCK'),
    (Icons.graphic_eq_rounded, 'FILM SOUNDS'),
    (Icons.vibration_rounded, 'OWN HAPTICS'),
  ],
};

/// A drop's perks as a two-by-two grid of small cards.
class DropPerks extends StatelessWidget {
  final SkinInfo skin;
  const DropPerks({super.key, required this.skin});

  @override
  Widget build(BuildContext context) {
    final c = skin.colors;
    final perks = _perks[skin.mode] ?? const [];
    Widget tile((IconData, String) p) => Container(
      height: 38.0,
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: c.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(p.$1, size: 16.0, color: c.accent),
          const SizedBox(width: 8.0),
          Expanded(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                p.$2,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 15.0,
                  letterSpacing: 1.4,
                  color: c.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    return Column(
      children: [
        for (var i = 0; i + 1 < perks.length; i += 2) ...[
          if (i > 0) const SizedBox(height: 8.0),
          Row(
            children: [
              Expanded(child: tile(perks[i])),
              const SizedBox(width: 8.0),
              Expanded(child: tile(perks[i + 1])),
            ],
          ),
        ],
      ],
    );
  }
}
