import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// Renders tactile 3D extruded numerals inspired by (NOT BORING) Calculator.
/// Uses layered 2D text painting with Bebas Neue block typography,
/// directional drop shadow, and chamfer bevel rim highlighting.
class ExtrudedNumber extends StatelessWidget {
  final String text;
  final double depth; // 0.0 (flat) to 1.0 (full depth)
  final ThemeColors colors;
  final Offset tilt;
  final bool isLite;
  final TextAlign textAlign;

  const ExtrudedNumber({
    super.key,
    required this.text,
    this.depth = 1.0,
    required this.colors,
    this.tilt = Offset.zero,
    this.isLite = false,
    this.textAlign = TextAlign.center,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, constraints.maxHeight),
            painter: _ExtrudedNumberPainter(
              text: text,
              depth: depth,
              colors: colors,
              tilt: tilt,
              isLite: isLite,
              textAlign: textAlign,
            ),
          );
        },
      ),
    );
  }
}

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

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    // Calculate hero font size: For 1-3 characters, scale up to 180-210sp!
    // As text gets longer, auto-fit gracefully down to fit screen width.
    double targetFontSize = size.height * 0.88;
    if (targetFontSize > 200.0) targetFontSize = 200.0;
    if (targetFontSize < 64.0) targetFontSize = 64.0;

    final baseStyle = TextStyle(
      fontFamily: 'BebasNeue',
      fontSize: targetFontSize,
      fontWeight: FontWeight.w400, // Bebas Neue is bold condensed display
      letterSpacing: 1.0,
      height: 1.0,
    );

    // Auto-fit measurement
    var textPainter = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    final maxAllowedWidth = size.width - 36.0;
    if (textPainter.width > maxAllowedWidth) {
      final scaleFactor = maxAllowedWidth / textPainter.width;
      final fittedFontSize = (targetFontSize * scaleFactor).clamp(40.0, 200.0);
      final fittedStyle = baseStyle.copyWith(fontSize: fittedFontSize);
      textPainter = TextPainter(
        text: TextSpan(text: text, style: fittedStyle),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
    }

    final textWidth = textPainter.width;
    final textHeight = textPainter.height;

    // Extrusion vector (down and slightly left, matching the Not Boring light angle)
    // Leftwards extrusion gives the exact sculptural depth seen on 12%
    final double maxOffset = (isLite ? 8.0 : 16.0) * depth;
    final double dirX = (-maxOffset * 0.70) + tilt.dx;
    final double dirY = (maxOffset * 0.95) + tilt.dy;

    // Center horizontally in the available hero area
    double startX;
    if (textAlign == TextAlign.center) {
      startX = (size.width - textWidth) / 2 - (dirX * 0.5);
    } else {
      startX = size.width - textWidth - maxOffset.abs() - 20.0;
    }
    final double startY = (size.height - textHeight) / 2 - (dirY * 0.5);

    final numLayers = isLite ? 4 : 16;

    // 1. Directional Base Drop Shadow
    if (!isLite && depth > 0.05) {
      final shadowOffset = Offset(
        startX + (dirX * 1.35),
        startY + (dirY * 1.35),
      );
      final shadowPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(
            fontSize: textPainter.text!.style!.fontSize,
            color: colors.extrudeShadow,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      shadowPainter.layout();

      canvas.save();
      final shadowPaint = Paint()
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 16.0 * depth);
      canvas.saveLayer(null, shadowPaint);
      shadowPainter.paint(canvas, shadowOffset);
      canvas.restore();
      canvas.restore();
    }

    // 2. Extrusion Side Wall Layers (stacked from back to front)
    for (int i = 0; i < numLayers; i++) {
      final progress = i / numLayers; // 0.0 (back) to 1.0 (front)
      final layerOffsetX = startX + (dirX * (1.0 - progress));
      final layerOffsetY = startY + (dirY * (1.0 - progress));

      // Shaded transition from deep ambient side tone to front rim
      final layerColor = Color.lerp(
        colors.extrudeSide.withValues(alpha: 0.95),
        colors.extrudeSide,
        progress,
      )!;

      final sidePainter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(
            fontSize: textPainter.text!.style!.fontSize,
            color: layerColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      sidePainter.layout();
      sidePainter.paint(canvas, Offset(layerOffsetX, layerOffsetY));
    }

    // 3. Front Face
    final frontOffset = Offset(startX, startY);
    final frontPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: baseStyle.copyWith(
          fontSize: textPainter.text!.style!.fontSize,
          color: colors.extrudeTop,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    frontPainter.layout();
    frontPainter.paint(canvas, frontOffset);

    // 4. Subtle Chamfer / Inner Edge Bevel Highlight
    if (!isLite) {
      final chamferPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: baseStyle.copyWith(
            fontSize: textPainter.text!.style!.fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.4
              ..color = colors.extrudeChamfer.withValues(alpha: 0.45),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      chamferPainter.layout();
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
