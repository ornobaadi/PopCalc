import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

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

/// Store tile for one skin: square mockup with a small caption under it,
/// in the store's own (current skin) colours.
class SkinCard extends StatelessWidget {
  /// Height taken by the caption under the square mockup.
  static const captionHeight = 50.0;

  final SkinInfo skin;
  final ThemeColors colors;
  final String status; // price, FREE, OWNED or ACTIVE
  final bool locked;
  final bool active;
  final VoidCallback onTap;

  const SkinCard({
    super.key,
    required this.skin,
    required this.colors,
    required this.status,
    required this.locked,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkinMockup(
            skin: skin,
            borderColor: active
                ? colors.accent
                : colors.ink.withValues(alpha: 0.16),
            borderWidth: active ? 2.5 : 1.5,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4.0, 7.0, 4.0, 0.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skin.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 18.0,
                    letterSpacing: 1.0,
                    height: 1.1,
                    color: colors.ink,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skin.modelCode,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10.5,
                          letterSpacing: 1.2,
                          height: 1.3,
                          color: colors.inkSoft,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6.0),
                    if (locked)
                      Padding(
                        padding: const EdgeInsets.only(right: 3.0),
                        child: Icon(
                          Icons.lock_rounded,
                          size: 11.0,
                          color: colors.accent,
                        ),
                      ),
                    Text(
                      status,
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 14.0,
                        letterSpacing: 1.0,
                        height: 1.2,
                        color: colors.accent,
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
