import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

import 'store_widgets.dart';

/// Square store mockup of a skin (pre-rendered by
/// `tool/generate_skin_mockups.dart`) inside a rounded border.
class SkinMockup extends StatelessWidget {
  final SkinInfo skin;
  final Color borderColor;
  final double borderWidth;
  final double radius;

  const SkinMockup({
    super.key,
    required this.skin,
    required this.borderColor,
    this.borderWidth = 1.5,
    this.radius = 20.0,
  });

  static String assetOf(SkinInfo skin) => 'assets/skins/${skin.mode.name}.png';

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.0,
      child: Container(
        clipBehavior: Clip.antiAlias,
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        decoration: BoxDecoration(
          color: skin.colors.bg,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Image.asset(assetOf(skin), fit: BoxFit.cover),
      ),
    );
  }
}

/// Where a skin stands for the person looking at the store.
enum SkinStanding { active, owned, forSale, notForSale }

/// Store tile for one skin: its square mockup, the name, and a pill that
/// says what it costs or that it is already theirs. Drawn in the store's
/// own (current skin) colours.
class SkinCard extends StatelessWidget {
  /// Height taken by the caption under the square mockup.
  static const captionHeight = 58.0;

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
          SkinMockup(
            skin: skin,
            radius: 24.0,
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
