import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

import 'purchase_feedback.dart';
import 'store_widgets.dart';
import 'theme_bundle_sheet.dart';
import 'theme_card.dart';
import 'theme_detail_sheet.dart';

/// The skin store: a carousel of everything in the bundle (premium skins and
/// materials),
/// then the materials and the premium skins, each a row of cards that
/// scrolls sideways. Free skins live in the settings sheet.
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

  @override
  Widget build(BuildContext context) {
    final currentMode = ref.watch(themeProvider);
    final colors = ThemeColors.of(currentMode);
    final purchases = ref.watch(purchasesProvider);
    final owned = purchases.owned;
    final ownsAll = kBundleItems.every((s) => ownsSkin(owned, s));

    Widget card(SkinInfo skin) {
      final SkinStanding standing;
      final String status;
      if (skin.mode == currentMode) {
        standing = SkinStanding.active;
        status = 'ACTIVE';
      } else if (ownsSkin(owned, skin)) {
        standing = SkinStanding.owned;
        status = 'OWNED';
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

    // A section is one row of cards that scrolls sideways.
    List<Widget> section(
      String title,
      String hint,
      List<SkinInfo> items,
      double cardWidth,
    ) => [
      Padding(
        padding: const EdgeInsets.fromLTRB(_gutter, 32.0, _gutter, 0.0),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              text: title,
              children: [
                TextSpan(
                  text: '  ${items.length}',
                  style: TextStyle(
                    color: colors.inkSoft.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ),
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 26.0,
              letterSpacing: 1.8,
              height: 1.1,
              color: colors.ink,
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(_gutter, 2.0, _gutter, 14.0),
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
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: _gutter),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final skin in items) ...[
              if (skin != items.first) const SizedBox(width: 12.0),
              SizedBox(width: cardWidth, child: card(skin)),
            ],
          ],
        ),
      ),
    ];

    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440.0),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // So many cards across, the last one cut off at the edge
                // to show there are more.
                double cardWidth(double across) =>
                    (constraints.maxWidth - _gutter - 12.0 * across.floor()) /
                    across;

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
                      child: BundleCarousel(
                        skins: kBundleItems,
                        saving: ownsAll ? null : purchases.bundleSaving,
                        onTap: (front) {
                          AppHaptics.selectionClick();
                          BundleDetailSheet.show(context, front);
                        },
                      ),
                    ),
                    ...section(
                      'MATERIALS',
                      'Look, sound and haptics, made as one set.',
                      kMaterials,
                      cardWidth(1.75),
                    ),
                    ...section(
                      'PREMIUM SKINS',
                      'A new face for every numeral and key.',
                      kSkins.where((s) => s.premium).toList(),
                      cardWidth(2.3),
                    ),
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

/// "Everything" bundle banner: every premium skin and material fanned on an
/// endless wheel
/// that turns by itself, one skin at a time. The box takes on the colours of
/// the skin at the front. Swiping also steps it; tapping opens the bundle.
class BundleCarousel extends StatefulWidget {
  /// How long each skin stays at the front before the wheel turns.
  static const dwell = Duration(milliseconds: 2200);

  final List<SkinInfo> skins;

  /// The percent the bundle saves, shown in the corner; null hides it.
  final int? saving;

  /// Tapping the banner; gets the skin at the front at that moment.
  final ValueChanged<SkinInfo> onTap;

  const BundleCarousel({
    super.key,
    required this.skins,
    required this.onTap,
    this.saving,
  });

  @override
  State<BundleCarousel> createState() => BundleCarouselState();
}

class BundleCarouselState extends State<BundleCarousel>
    with SingleTickerProviderStateMixin {
  // All as fractions of the box width, so the fan keeps its shape.
  static const _aspect = 1.72; // the banner is a wide rectangle
  static const _frontSize = 0.3; // the front card
  static const _sideScale = 0.64; // its neighbours, relative to the front
  static const _slotFraction = 0.205; // front card to its neighbour
  static const _drop = 0.1; // how far each step sinks down the curve

  /// Position on the wheel in cards. Unbounded, so it never runs out:
  /// whole numbers put a skin at the front, and it wraps round the list.
  late final AnimationController _position = AnimationController.unbounded(
    vsync: this,
    value: (widget.skins.length ~/ 2).toDouble(),
  );
  Timer? _auto;
  double _slot = 100.0;
  int _dragFrom = 0;
  double _dragged = 0.0;

  /// The skin currently at (or nearest) the front.
  SkinInfo get front => _skinAt(_position.value.round());

  SkinInfo _skinAt(int index) => widget.skins[index % widget.skins.length];

  @override
  void initState() {
    super.initState();
    _startAuto();
  }

  @override
  void dispose() {
    _auto?.cancel();
    _position.dispose();
    super.dispose();
  }

  void _startAuto() {
    _auto?.cancel();
    _auto = Timer.periodic(BundleCarousel.dwell, (_) {
      _turnTo(
        _position.value.round() + 1,
        const Duration(milliseconds: 520),
        Curves.easeInOutCubic,
      );
    });
  }

  void _turnTo(int index, Duration duration, Curve curve) {
    _position.animateTo(index.toDouble(), duration: duration, curve: curve);
  }

  void _onDragStart(DragStartDetails details) {
    _auto?.cancel();
    _position.stop();
    _dragFrom = _position.value.round();
    _dragged = 0.0;
  }

  // The cards follow the finger, but never further than the next skin.
  void _onDragUpdate(DragUpdateDetails details) {
    _dragged += details.delta.dx;
    _position.value = (_dragFrom - _dragged / _slot).clamp(
      _dragFrom - 1.0,
      _dragFrom + 1.0,
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    final threshold = _slot * 0.25;
    var target = _dragFrom;
    if (_dragged < -threshold || velocity < -300.0) {
      target++;
    } else if (_dragged > threshold || velocity > 300.0) {
      target--;
    }
    if (target != _dragFrom) AppHaptics.detent();
    _turnTo(target, const Duration(milliseconds: 280), Curves.easeOutCubic);
    _startAuto();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _position,
      builder: (context, _) {
        final position = _position.value;
        final from = _skinAt(position.floor()).colors;
        final to = _skinAt(position.ceil()).colors;
        final t = position - position.floor();
        Color mix(Color Function(ThemeColors) pick) =>
            Color.lerp(pick(from), pick(to), t)!;
        // A deeper tone of the skin, so its own mockup stands out on it.
        final box = mix((c) => Color.lerp(c.bg, c.extrudeSide, 0.4)!);
        final ink = mix((c) => c.ink);
        final accent = mix((c) => c.accent);

        return GestureDetector(
          key: const ValueKey('bundle-wheel'),
          behavior: HitTestBehavior.opaque,
          onTap: () => widget.onTap(front),
          onHorizontalDragStart: _onDragStart,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: AspectRatio(
            aspectRatio: _aspect,
            child: Container(
              key: const ValueKey('bundle-box'),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: box,
                borderRadius: BorderRadius.circular(22.0),
                border: Border.all(
                  color: accent.withValues(alpha: 0.7),
                  width: 1.5,
                ),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  _slot = width * _slotFraction;
                  return Stack(
                    children: [
                      Positioned.fill(child: _wheel(position, width)),
                      if (widget.saving != null)
                        Positioned(
                          top: width * 0.04,
                          right: width * 0.04,
                          child: SavingChip(
                            percent: widget.saving!,
                            color: accent,
                            onColor: box,
                            fontSize: width * 0.044,
                          ),
                        ),
                      Positioned(
                        left: 0.0,
                        right: 0.0,
                        bottom: width * 0.04,
                        child: Column(
                          children: [
                            Text(
                              'EVERYTHING',
                              style: TextStyle(
                                fontFamily: 'BebasNeue',
                                fontSize: width * 0.075,
                                letterSpacing: 2.0,
                                height: 1.05,
                                color: ink,
                              ),
                            ),
                            Text(
                              'All skins and materials',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: width * 0.036,
                                height: 1.2,
                                color: ink.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Cards fanned along a curve: the front one upright and clearly the
  /// largest, the rest smaller, leaning outwards and sinking to each side.
  Widget _wheel(double position, double width) {
    final card = width * _frontSize;
    final nearest = position.round();
    final indices = [for (var k = -4; k <= 4; k++) nearest + k]
      // Furthest first, so the front card is painted on top.
      ..sort((a, b) => (b - position).abs().compareTo((a - position).abs()));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (final index in indices)
          () {
            final delta = index - position;
            final d = delta.abs();
            // Shrinks quickly over the first step, gently after it.
            final scale = d <= 1.0
                ? 1.0 - (1.0 - _sideScale) * Curves.easeOut.transform(d)
                : _sideScale - 0.06 * (d - 1.0);
            // Packed close, each card tucked a little behind the one in
            // front of it, and bunching up slightly towards the edges.
            final x =
                delta.sign *
                width *
                (_slotFraction * d - 0.012 * d * (d - 1.0));
            // Rounded at the top of the curve, straighter down the sides.
            final y = width * _drop * (math.sqrt(d * d + 0.2) - math.sqrt(0.2));
            return Positioned(
              left: width / 2 + x - card / 2,
              top: width * 0.035 + y,
              width: card,
              height: card,
              child: Transform.rotate(
                angle: delta * 0.17,
                child: Transform.scale(
                  scale: scale,
                  child: SkinMockup(
                    skin: _skinAt(index),
                    borderColor: Colors.white.withValues(
                      alpha: d < 0.5 ? 1.0 : 0.6,
                    ),
                    // Keeps the border a constant thickness on screen.
                    borderWidth: 2.5 / scale,
                    radius: card * 0.17,
                  ),
                ),
              ),
            );
          }(),
      ],
    );
  }
}
