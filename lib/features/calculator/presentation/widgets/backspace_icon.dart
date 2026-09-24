import 'package:flutter/material.dart';

/// Custom angular backspace icon: an elongated horizontal hexagon containing an 'x',
/// matching the exact aesthetic of (NOT BORING) Calculator.
class BackspaceIcon extends StatelessWidget {
  final Color color;
  final double size;

  const BackspaceIcon({
    super.key,
    required this.color,
    this.size = 28.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size * 1.25, size),
      painter: _BackspacePainter(color: color),
    );
  }
}

class _BackspacePainter extends CustomPainter {
  final Color color;

  _BackspacePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final strokeWidth = h * 0.08;

    final outlinePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    // Angular tag/hexagon pointing to the left
    final tipX = strokeWidth;
    final arrowX = w * 0.28;
    final rightX = w - strokeWidth;
    final topY = strokeWidth;
    final midY = h / 2;
    final botY = h - strokeWidth;

    path.moveTo(arrowX, topY);
    path.lineTo(rightX, topY);
    path.lineTo(rightX, botY);
    path.lineTo(arrowX, botY);
    path.lineTo(tipX, midY);
    path.close();

    canvas.drawPath(path, outlinePaint);

    // Draw the inner 'x'
    final xCenterX = arrowX + (rightX - arrowX) / 2;
    final xCenterY = midY;
    final xRadius = h * 0.18;

    final xPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(xCenterX - xRadius, xCenterY - xRadius),
      Offset(xCenterX + xRadius, xCenterY + xRadius),
      xPaint,
    );

    canvas.drawLine(
      Offset(xCenterX + xRadius, xCenterY - xRadius),
      Offset(xCenterX - xRadius, xCenterY + xRadius),
      xPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _BackspacePainter oldDelegate) =>
      oldDelegate.color != color;
}
