import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

import 'package:popcalc/features/calculator/presentation/widgets/backspace_icon.dart';
import 'package:popcalc/features/calculator/presentation/widgets/extruded_number.dart';

import 'store_widgets.dart';

/// The calculator wearing [skin], as a small phone: top bar, a sum, the 3D
/// answer and the keypad, all drawn live in the skin's colours with the real
/// numeral painter. Nothing in it responds to touch. Always [size]; scale it
/// with a FittedBox.
class SkinPhone extends StatelessWidget {
  static const size = Size(228.0, 470.0);

  final SkinInfo skin;
  const SkinPhone({super.key, required this.skin});

  static const _rows = [
    ['C', '%', '<', '÷'],
    ['7', '8', '9', '×'],
    ['4', '5', '6', '−'],
    ['1', '2', '3', '+'],
    ['0', '.', '±', '='],
  ];

  @override
  Widget build(BuildContext context) {
    final c = skin.colors;
    final keycaps = c.finish == SkinFinish.keycap;
    // A frame that reads against the card whatever the skin's own tone.
    final frame = c.isDark
        ? Color.lerp(c.bg, Colors.white, 0.2)!
        : const Color(0xFF1B1B1F);

    TextStyle bebas(double size, Color color) => TextStyle(
      fontFamily: 'BebasNeue',
      fontSize: size,
      height: 1.0,
      letterSpacing: 0.4,
      color: color,
    );

    Widget legend(String key) {
      final Widget child;
      if (key == '<') {
        child = BackspaceIcon(color: c.inkSoft, size: 13.0);
      } else {
        final color = '÷×−+='.contains(key)
            ? c.accent
            : 'C%±'.contains(key)
            ? c.inkSoft
            : c.ink;
        child = Text(key, style: bebas(key == '±' ? 20.0 : 24.0, color));
      }
      if (!keycaps) return Center(child: child);
      // Mechanical: every key is a little keycap.
      return Padding(
        padding: const EdgeInsets.all(2.5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color.lerp(c.bg, Colors.black, 0.5),
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Container(
            margin: const EdgeInsets.fromLTRB(2.0, 1.0, 2.0, 5.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Color.lerp(c.bg, c.ink, 0.18),
              borderRadius: BorderRadius.circular(6.0),
            ),
            child: child,
          ),
        ),
      );
    }

    return IgnorePointer(
      child: Container(
        width: size.width,
        height: size.height,
        padding: const EdgeInsets.all(6.0),
        decoration: BoxDecoration(
          color: frame,
          borderRadius: BorderRadius.circular(36.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x59000000),
              blurRadius: 26.0,
              offset: Offset(0.0, 14.0),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.2, -0.3),
                radius: 1.3,
                colors: [c.bgShade, c.bg],
              ),
            ),
            child: Stack(
              children: [
                if (c.finish == SkinFinish.wireframe)
                  Positioned.fill(
                    child: GridPaper(
                      color: c.ink.withValues(alpha: 0.14),
                      interval: 54.0,
                      divisions: 1,
                      subdivisions: 4,
                    ),
                  ),
                Column(
                  children: [
                    const SizedBox(height: 16.0),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final icon in const [
                            Icons.access_time_rounded,
                            Icons.tune_rounded,
                          ])
                            Icon(
                              icon,
                              size: 12.0,
                              color: c.inkSoft.withValues(alpha: 0.65),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6.0),
                    Text.rich(
                      TextSpan(
                        text: '32 ',
                        children: [
                          TextSpan(
                            text: '× ',
                            style: TextStyle(color: c.accent),
                          ),
                          const TextSpan(text: '4 '),
                          TextSpan(
                            text: '=',
                            style: TextStyle(color: c.accent),
                          ),
                        ],
                      ),
                      style: bebas(21.0, c.ink),
                    ),
                    SizedBox(
                      height: 132.0,
                      child: ExtrudedNumber(text: '128', colors: c),
                    ),
                    const SizedBox(height: 6.0),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 12.0),
                        child: Column(
                          children: [
                            for (final row in _rows)
                              Expanded(
                                child: Row(
                                  children: [
                                    for (final key in row)
                                      Expanded(child: legend(key)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A skin's shop window: its [SkinPhone], leaning a little, on a backdrop
/// in a deeper tone of the skin's own colours. The phone runs off the
/// bottom edge, so how much keypad shows depends on [aspectRatio].
class SkinSwatch extends StatelessWidget {
  final SkinInfo skin;
  final Color borderColor;
  final double borderWidth;
  final double radius;

  /// Width over height. Square by default.
  final double aspectRatio;

  const SkinSwatch({
    super.key,
    required this.skin,
    required this.borderColor,
    this.borderWidth = 1.5,
    this.radius = 20.0,
    this.aspectRatio = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final c = skin.colors;
    // Deeper than the skin itself, so the phone stands out on it.
    final tone = Color.lerp(c.bg, c.extrudeSide, 0.5)!;
    const width = 300.0;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: Container(
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(tone, Colors.white, 0.12)!,
              Color.lerp(tone, Colors.black, 0.18)!,
            ],
          ),
        ),
        // Laid out at one size and scaled, so it looks the same from a
        // thumbnail to a full card.
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: width,
            height: width / aspectRatio,
            child: Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned(
                  left: (width - SkinPhone.size.width) / 2 + 6.0,
                  top: 34.0,
                  child: Transform.rotate(
                    angle: -0.07,
                    alignment: Alignment.topCenter,
                    child: SkinPhone(skin: skin),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Where a skin stands for the person looking at the store.
enum SkinStanding { active, owned, forSale, notForSale }

/// Store tile for one skin: its swatch, the name, and a pill that
/// says what it costs or that it is already theirs. Drawn in the store's
/// own (current skin) colours.
class SkinCard extends StatelessWidget {
  /// Height taken by the caption under the swatch.
  static const captionHeight = 58.0;

  /// The swatch's width over its height.
  static const swatchAspect = 0.82;

  final SkinInfo skin;
  final ThemeColors colors;

  /// The price as Play gives it, or the word that stands in for one.
  final String status;
  final SkinStanding standing;
  final VoidCallback onTap;

  const SkinCard({
    super.key,
    required this.skin,
    required this.colors,
    required this.status,
    required this.standing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = standing == SkinStanding.active;
    return Pressable(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkinSwatch(
            skin: skin,
            radius: 24.0,
            aspectRatio: swatchAspect,
            borderColor: active
                ? colors.accent
                : colors.ink.withValues(alpha: 0.1),
            borderWidth: active ? 2.5 : 1.0,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 10.0, 2.0, 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skin.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 20.0,
                    letterSpacing: 1.2,
                    height: 1.1,
                    color: colors.ink,
                  ),
                ),
                const SizedBox(height: 3.0),
                Row(
                  children: [
                    Text(
                      skin.modelCode,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.0,
                        letterSpacing: 1.4,
                        height: 1.3,
                        color: colors.inkSoft,
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    // A price comes from Play in any currency and length,
                    // so it gets the rest of the line and shrinks to fit.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: _StandingPill(
                          text: status,
                          standing: standing,
                          colors: colors,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StandingPill extends StatelessWidget {
  final String text;
  final SkinStanding standing;
  final ThemeColors colors;

  const _StandingPill({
    required this.text,
    required this.standing,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    final (Color fill, Color ink, IconData? icon) = switch (standing) {
      SkinStanding.forSale => (colors.accent, colors.bg, Icons.lock_rounded),
      SkinStanding.notForSale => (
        colors.ink.withValues(alpha: 0.08),
        colors.inkSoft,
        Icons.lock_rounded,
      ),
      SkinStanding.owned => (
        Colors.transparent,
        colors.inkSoft,
        Icons.check_rounded,
      ),
      SkinStanding.active => (Colors.transparent, colors.accent, null),
    };
    final bare = fill == Colors.transparent;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: bare ? 0.0 : 8.0,
        vertical: 2.0,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 3.0),
              child: Icon(icon, size: 11.0, color: ink),
            ),
          Text(
            text,
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 14.0,
              letterSpacing: 1.0,
              height: 1.2,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}
