import 'dart:math';
import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// Renders a thick, solid 3D extruded numeral block.
/// The extrusion direction follows device tilt + touch drag for a natural
/// "physical object" feel. Sub-pixel stamping with a gradient-shaded side wall
/// gives the illusion of a real engraved block with zero visible staircase.
class ExtrudedNumber extends StatelessWidget {
  final String text;
  final double depth; // 0.0 (flat) to 1.0 (full depth)
  final ThemeColors colors;
  final Offset tilt;
  final bool isLite;
  final TextAlign textAlign;
  final bool isZero;

  const ExtrudedNumber({
    super.key,
    required this.text,
    this.depth = 1.0,
    required this.colors,
    this.tilt = Offset.zero,
    this.isLite = false,
    this.textAlign = TextAlign.center,
    this.isZero = false,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Opacity(
            opacity: isZero ? 0.28 : 1.0,
            child: CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _ExtrudedNumberPainter(
                text: text,
                depth: isZero ? 0.35 : depth,
                colors: colors,
                tilt: tilt,
                isLite: isLite,
                textAlign: textAlign,
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── Layout Cache ─────────────────────────────────────────────────────────────
final _painterCache = <String, _LayoutCache>{};

class _LayoutCache {
  final TextPainter frontPainter;
  final TextPainter shadowPainter;
  final double fontSize;

  _LayoutCache({
    required this.frontPainter,
    required this.shadowPainter,
    required this.fontSize,
  });
}

// ─── Painter ──────────────────────────────────────────────────────────────────
class _ExtrudedNumberPainter extends CustomPainter {
  final String text;
  final double depth;
  final ThemeColors colors;
  final Offset tilt;
  final bool isLite;
  final TextAlign textAlign;

  _ExtrudedNumberPainter({
    required this.text,
    required this.depth,
    required this.colors,
    required this.tilt,
    required this.isLite,
    required this.textAlign,
  });

  String _cacheKey(Size size) =>
      '${text}_${size.width.toInt()}_${size.height.toInt()}_${colors.extrudeTop.toARGB32()}_${colors.extrudeSide.toARGB32()}_$isLite';

  _LayoutCache _buildCache(Size size) {
    double targetFontSize = size.height * 0.88;
    if (targetFontSize > 200.0) targetFontSize = 200.0;
    if (targetFontSize < 64.0) targetFontSize = 64.0;

    const baseStyle = TextStyle(
      fontFamily: 'BebasNeue',
      fontFamilyFallback: ['Antonio', 'sans-serif'],
      fontWeight: FontWeight.w400,
      letterSpacing: 1.0,
      height: 1.0,
    );

    var measurePainter = TextPainter(
      text: TextSpan(text: text, style: baseStyle.copyWith(fontSize: targetFontSize)),
      textDirection: TextDirection.ltr,
    )..layout();

    final maxAllowedWidth = size.width - 40.0;
    if (measurePainter.width > maxAllowedWidth) {
      final scaleFactor = maxAllowedWidth / measurePainter.width;
      targetFontSize = (targetFontSize * scaleFactor).clamp(40.0, 200.0);
    }

    final fittedStyle = baseStyle.copyWith(fontSize: targetFontSize);

    // Front face numeral
    final frontPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: fittedStyle.copyWith(color: colors.extrudeTop),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // Soft ambient contact shadow
    final shadowPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: fittedStyle.copyWith(
          foreground: Paint()
            ..color = colors.extrudeShadow
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18.0),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    return _LayoutCache(
      frontPainter: frontPainter,
      shadowPainter: shadowPainter,
      fontSize: targetFontSize,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final key = _cacheKey(size);
    _painterCache[key] ??= _buildCache(size);
    if (_painterCache.length > 16) {
      _painterCache.remove(_painterCache.keys.first);
    }

    final cache = _painterCache[key]!;
    final textWidth = cache.frontPainter.width;
    final textHeight = cache.frontPainter.height;

    // ── Extrusion direction ──
    // Base direction: lower-right (classic block-letter look).
    // tilt.dx / tilt.dy are in [-12, 12] range from touch+sensor combined.
    // Tilt shifts the direction so as you tilt the device, the "light source"
    // appears to shift naturally — left/right and up/down.
    final double maxOffset = (isLite ? 10.0 : 18.0) * depth;

    // Natural base direction at rest: lower-right shadow
    final double baseDirX = maxOffset * 0.55;
    final double baseDirY = maxOffset * 0.82;

    // Tilt shifts the direction — normalised so tilt of ±12 ≈ ±half offset
    final double tiltInfluence = isLite ? 0.4 : 0.55;
    final double dirX = baseDirX + (tilt.dx * tiltInfluence);
    final double dirY = baseDirY + (tilt.dy * tiltInfluence);

    // Center the text so the block appears centered in the widget
    final double startX = (textAlign == TextAlign.center)
        ? (size.width - textWidth) / 2 - (dirX * 0.5)
        : size.width - textWidth - maxOffset.abs() - 20.0;
    final double startY = (size.height - textHeight) / 2 - (dirY * 0.5);

    final frontOffset = Offset(startX, startY);

    // ─── 1. Soft ambient contact drop shadow ──────────────────────────────────
    if (!isLite && depth > 0.05) {
      cache.shadowPainter.paint(
        canvas,
        Offset(startX + dirX * 1.5, startY + dirY * 1.5),
      );
    }

    // ─── 2. Gradient-shaded 3D block wall ─────────────────────────────────────
    // Sub-pixel stamping with gradient colour lerp creates smooth bevel.
    // t=0 (far layers): deep shadow colour  
    // t=1 (near face):  slightly lighter rim, mimicking a real thick block edge
    final double dist = sqrt(dirX * dirX + dirY * dirY);
    final int steps = isLite ? 18 : (dist / 0.28).clamp(36, 64).toInt();

    final Color deepColor = colors.extrudeSide;
    final Color rimColor = Color.lerp(colors.extrudeSide, colors.extrudeTop, 0.28)!;

    for (int i = 0; i < steps; i++) {
      final t = i / (steps - 1.0);
      final layerOffset = Offset(
        frontOffset.dx + dirX * (1.0 - t),
        frontOffset.dy + dirY * (1.0 - t),
      );

      final lerpT = Curves.easeInCubic.transform(t);
      final layerColor = Color.lerp(deepColor, rimColor, lerpT)!;

      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontFamilyFallback: const ['Antonio', 'sans-serif'],
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
            height: 1.0,
            fontSize: cache.fontSize,
            color: layerColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      tp.paint(canvas, layerOffset);
    }

    // ─── 3. Crisp front face numeral ──────────────────────────────────────────
    cache.frontPainter.paint(canvas, frontOffset);

    // ─── 4. Subtle bevel highlight at face rim ────────────────────────────────
    if (!isLite && colors.extrudeChamfer != Colors.transparent) {
      final chamferPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontFamilyFallback: const ['Antonio', 'sans-serif'],
            fontWeight: FontWeight.w400,
            letterSpacing: 1.0,
            height: 1.0,
            fontSize: cache.fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1
              ..color = colors.extrudeChamfer,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      chamferPainter.paint(canvas, frontOffset);
    }
  }

  @override
  bool shouldRepaint(covariant _ExtrudedNumberPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.depth != depth ||
        oldDelegate.colors != colors ||
        oldDelegate.tilt != tilt ||
        oldDelegate.isLite != isLite ||
        oldDelegate.textAlign != textAlign;
  }
}


