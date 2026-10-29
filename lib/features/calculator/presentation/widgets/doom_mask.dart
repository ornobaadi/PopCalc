import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// An iron-masked sovereign in a deep hood, drawn from a few polygons. Our own
/// design: a split faceplate with a seam of light down the middle, a broken
/// right cheek, vent slits for a nose and a grille for a mouth. [size] is the
/// width of the hood; [glow] (0..1) is how bright the eyes and the seam burn;
/// [alpha] fades the whole figure.
void paintDoomMask(
  Canvas canvas,
  Offset centre,
  double size, {
  required double glow,
  required double alpha,
  required Color light,
  bool soft = true,
}) {
  if (alpha <= 0) return;
  canvas.save();
  canvas.translate(centre.dx, centre.dy);
  canvas.scale(size / 2, size / 2);
  final layer = Paint()..color = Color.fromRGBO(0, 0, 0, alpha);
  canvas.saveLayer(const Rect.fromLTWH(-1.4, -1.5, 2.8, 3.0), layer);

  Path poly(List<double> p) {
    final path = Path()..moveTo(p[0], p[1]);
    for (var i = 2; i < p.length; i += 2) {
      path.lineTo(p[i], p[i + 1]);
    }
    return path..close();
  }

  // The hood: a high peak, shoulders falling away into the dark.
  final hood = Path()
    ..moveTo(-1.05, 1.3)
    ..quadraticBezierTo(-1.0, 0.4, -0.84, -0.2)
    ..quadraticBezierTo(-0.62, -0.95, 0.0, -1.28)
    ..quadraticBezierTo(0.62, -0.95, 0.84, -0.2)
    ..quadraticBezierTo(1.0, 0.4, 1.05, 1.3)
    ..close();
  canvas.drawPath(
    hood,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(0, -1.3), const Offset(0, 1.3), [
        const Color(0xFF16231B),
        const Color(0xFF050907),
      ]),
  );
  canvas.drawPath(
    hood,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.025
      ..color = light.withValues(alpha: 0.18 + 0.2 * glow),
  );
  // Cowl folds under the chin.
  for (final y in [0.82, 1.0, 1.18]) {
    canvas.drawPath(
      Path()
        ..moveTo(-0.9, y)
        ..quadraticBezierTo(0, y + 0.22, 0.9, y),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.022
        ..color = const Color(0xFF000000).withValues(alpha: 0.55),
    );
  }

  // The faceplate.
  final plate = poly([
    0.0, -0.64, //
    0.4, -0.52, 0.47, -0.16, 0.42, 0.26, 0.3, 0.64, 0.0, 0.96, //
    -0.3, 0.64, -0.42, 0.26, -0.47, -0.16, -0.4, -0.52,
  ]);
  canvas.drawPath(
    plate,
    Paint()
      ..shader = ui.Gradient.linear(const Offset(-0.45, -0.6), const Offset(0.45, 0.9), [
        const Color(0xFFA7B4AC),
        const Color(0xFF55625B),
        const Color(0xFF1F2924),
      ], const [0.0, 0.5, 1.0]),
  );
  canvas.drawPath(
    plate,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.03
      ..strokeJoin = StrokeJoin.round
      ..color = const Color(0xFFD7E2DB).withValues(alpha: 0.5),
  );

  // Heavy brow, a V pressed over the eyes.
  final dark = Paint()..color = const Color(0xFF0B100E);
  canvas.drawPath(poly([-0.47, -0.26, -0.03, -0.1, -0.03, 0.01, -0.43, -0.12]), dark);
  canvas.drawPath(poly([0.47, -0.26, 0.03, -0.1, 0.03, 0.01, 0.43, -0.12]), dark);

  // Vent slits for a nose, a grille for a mouth.
  for (final y in [0.2, 0.27, 0.34]) {
    canvas.drawRect(Rect.fromLTRB(-0.07, y, 0.07, y + 0.03), dark);
  }
  for (var i = -3; i <= 3; i++) {
    canvas.drawRect(Rect.fromLTWH(i * 0.055 - 0.012, 0.56, 0.024, 0.11), dark);
  }

  // The seam: the plate is split down the middle, light leaking through.
  final seam = Path()
    ..moveTo(0.0, -0.64)
    ..lineTo(0.015, -0.2)
    ..lineTo(-0.012, 0.2)
    ..lineTo(0.01, 0.6)
    ..lineTo(0.0, 0.96);
  // The broken right cheek.
  final crack = Path()
    ..moveTo(0.43, -0.02)
    ..lineTo(0.3, 0.12)
    ..lineTo(0.36, 0.24)
    ..lineTo(0.2, 0.4)
    ..lineTo(0.27, 0.58);
  for (final path in [seam, crack]) {
    if (soft) {
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.07
          ..color = light.withValues(alpha: 0.35 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.04),
      );
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.018
        ..color = Color.lerp(const Color(0xFF05130B), light, glow)!,
    );
  }

  // The eyes: two narrow slits that ignite.
  final eyeL = poly([-0.4, 0.0, -0.13, 0.05, -0.15, 0.11, -0.37, 0.07]);
  final eyeR = poly([0.4, 0.0, 0.13, 0.05, 0.15, 0.11, 0.37, 0.07]);
  for (final eye in [eyeL, eyeR]) {
    if (soft) {
      canvas.drawPath(
        eye,
        Paint()
          ..color = light.withValues(alpha: 0.55 * glow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.09),
      );
    }
    canvas.drawPath(
      eye,
      Paint()..color = Color.lerp(const Color(0xFF0B100E), const Color(0xFFE8FFF1), glow)!,
    );
  }

  canvas.restore();
  canvas.restore();
}

/// A still of the masked figure with its eyes lit: the store's glimpse of
/// Reckoning's hidden moment.
class MaskGlimpse extends StatelessWidget {
  final Color light;
  const MaskGlimpse({super.key, required this.light});

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GlimpsePainter(light), size: Size.infinite);
}

class _GlimpsePainter extends CustomPainter {
  final Color light;
  _GlimpsePainter(this.light);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xD9020604),
    );
    paintDoomMask(
      canvas,
      Offset(size.width / 2, size.height * 0.46),
      size.width * 0.78,
      glow: 1.0,
      alpha: 1.0,
      light: light,
    );
  }

  @override
  bool shouldRepaint(_GlimpsePainter old) => old.light != light;
}
