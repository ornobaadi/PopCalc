import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The first-time nudge for a limited drop's hidden moment: a soft ring that
/// breathes over the place to hold, and "HOLD HERE" under it. Shown until the
/// moment has been found once ([EggHint.markFound]), then never again.
class EggHint extends StatefulWidget {
  final Offset at;
  final Color color;

  const EggHint({super.key, required this.at, required this.color});

  static String _key(String egg) => 'egg_found_$egg';

  /// Whether the hint should still show for [egg] (`mirage`, `reckoning`).
  static Future<bool> pending(String egg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return !(prefs.getBool(_key(egg)) ?? false);
    } catch (_) {
      return false;
    }
  }

  static Future<void> markFound(String egg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(egg), true);
    } catch (_) {}
  }

  @override
  State<EggHint> createState() => _EggHintState();
}

class _EggHintState extends State<EggHint> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const box = 140.0;
    return Positioned(
      left: widget.at.dx - box / 2,
      top: widget.at.dy - box / 2,
      width: box,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (_, _) {
            final t = _pulse.value;
            final breathe = 0.5 + 0.5 * math.sin(t * 2 * math.pi);
            return Column(
              key: const ValueKey('egg-hint'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: box,
                  height: box,
                  child: CustomPaint(painter: _RingPainter(t, widget.color)),
                ),
                Opacity(
                  opacity: 0.55 + 0.35 * breathe,
                  child: Text(
                    'HOLD HERE',
                    style: TextStyle(
                      fontFamily: 'BebasNeue',
                      fontSize: 15.0,
                      letterSpacing: 3.0,
                      color: widget.color,
                      shadows: [Shadow(color: widget.color, blurRadius: 10.0)],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double t;
  final Color color;
  _RingPainter(this.t, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final max = size.width / 2;
    // A soft glow in the middle and a ring that keeps opening outward.
    canvas.drawCircle(
      c,
      max * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: c, radius: max * 0.55)),
    );
    for (final offset in [0.0, 0.5]) {
      final p = (t + offset) % 1.0;
      canvas.drawCircle(
        c,
        max * (0.25 + 0.7 * p),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0
          ..color = color.withValues(alpha: 0.55 * (1 - p)),
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.t != t;
}
