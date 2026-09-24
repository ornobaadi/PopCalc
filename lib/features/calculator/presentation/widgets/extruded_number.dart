import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// Renders ultra-smooth continuous 3D extruded numerals.
/// Uses many sub-pixel micro-steps for silky gradient side walls — no staircase effect.
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

// ─── Layout cache ─────────────────────────────────────────────────────────────
// Keyed by text+size+theme so multiple instances work correctly and only
// re-layout when something actually changes.
final _painterCache = <String, _LayoutCache>{};

class _LayoutCache {
  final TextPainter frontPainter;
  final TextPainter? shadowPainter;
  final TextPainter? chamferPainter;
  final double fontSize;

  _LayoutCache({
    required this.frontPainter,
    this.shadowPainter,
    this.chamferPainter,
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
      '${text}_${size.width.toInt()}_${size.height.toInt()}_${colors.extrudeTop.toARGB32()}_$isLite';

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

    final maxAllowedWidth = size.width - 36.0;
    if (measurePainter.width > maxAllowedWidth) {
      final scaleFactor = maxAllowedWidth / measurePainter.width;
      targetFontSize = (targetFontSize * scaleFactor).clamp(40.0, 200.0);
    }

    final fittedStyle = baseStyle.copyWith(fontSize: targetFontSize);

    final frontPainter = TextPainter(
      text: TextSpan(text: text, style: fittedStyle.copyWith(color: colors.extrudeTop)),
      textDirection: TextDirection.ltr,
    )..layout();

    TextPainter? shadowPainter;
    TextPainter? chamferPainter;

    if (!isLite) {
      shadowPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: fittedStyle.copyWith(
            foreground: Paint()
              ..color = colors.extrudeShadow
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14.0),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      chamferPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: fittedStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = colors.extrudeChamfer.withValues(alpha: 0.55),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    }

    return _LayoutCache(
      frontPainter: frontPainter,
      shadowPainter: shadowPainter,
      chamferPainter: chamferPainter,
      fontSize: targetFontSize,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final key = _cacheKey(size);
    _painterCache[key] ??= _buildCache(size);
    // Keep cache from growing unbounded
    if (_painterCache.length > 14) {
      _painterCache.remove(_painterCache.keys.first);
    }

    final cache = _painterCache[key]!;
    final textWidth = cache.frontPainter.width;
    final textHeight = cache.frontPainter.height;

    // Extrusion vector — moderate magnitude for clean look
    final double maxOffset = (isLite ? 7.0 : 13.0) * depth;
    final double dirX = (-maxOffset * 0.65) + tilt.dx;
    final double dirY = (maxOffset * 0.90) + tilt.dy;

    final double startX = (textAlign == TextAlign.center)
        ? (size.width - textWidth) / 2 - (dirX * 0.5)
        : size.width - textWidth - maxOffset.abs() - 20.0;
    final double startY = (size.height - textHeight) / 2 - (dirY * 0.5);

    final frontOffset = Offset(startX, startY);

    // ─── 1. Drop shadow (maskFilter blur, no saveLayer) ───────────────────────
    if (!isLite && depth > 0.05 && cache.shadowPainter != null) {
      cache.shadowPainter!.paint(
        canvas,
        Offset(startX + dirX * 1.4, startY + dirY * 1.4),
      );
    }

    // ─── 2. Smooth extrusion side walls ──────────────────────────────────────
    //
    // Paint from BACK to FRONT with many sub-pixel steps (no visible staircase).
    // 22 steps at sub-pixel increments = smooth continuous volume appearance.
    // Each layer has a smoothly interpolated color from dark (back) to mid (front).
    //
    final int steps = isLite ? 8 : 22;
    final side = colors.extrudeSide;

    for (int i = steps; i >= 0; i--) {
      final t = i / steps; // 1.0 = back, 0.0 = front edge
      final layerOffset = Offset(
        frontOffset.dx + dirX * t,
        frontOffset.dy + dirY * t,
      );

      // Smooth dark→medium color gradient along extrusion depth
      final double darken = t * 0.20;
      final layerColor = Color.fromARGB(
        side.a.toInt(),
        (side.r * (1.0 - darken)).round().clamp(0, 255),
        (side.g * (1.0 - darken)).round().clamp(0, 255),
        (side.b * (1.0 - darken)).round().clamp(0, 255),
      );

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
      )..layout();
      tp.paint(canvas, layerOffset);
    }

    // ─── 3. Front face ────────────────────────────────────────────────────────
    cache.frontPainter.paint(canvas, frontOffset);

    // ─── 4. Chamfer bevel rim highlight ──────────────────────────────────────
    if (!isLite && cache.chamferPainter != null) {
      cache.chamferPainter!.paint(canvas, frontOffset);
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
