import 'dart:math';
import 'package:flutter/material.dart';

/// Comic-style "speed line" burst that radiates from behind the result when
/// an answer lands. Fires once each time [trigger] increases.
class CelebrationBurst extends StatefulWidget {
  final int trigger;
  final Color color;

  const CelebrationBurst({
    super.key,
    required this.trigger,
    required this.color,
  });

  @override
  State<CelebrationBurst> createState() => _CelebrationBurstState();
}

class _CelebrationBurstState extends State<CelebrationBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  List<_Ray> _rays = const [];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
  }

  @override
  void didUpdateWidget(covariant CelebrationBurst oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger > oldWidget.trigger) {
      _rays = _generateRays();
      _controller.forward(from: 0.0);
    }
  }

  /// Fresh random rays each time so no two bursts look identical.
  List<_Ray> _generateRays() {
    const count = 22;
    return List.generate(count, (i) {
      final baseAngle = (i / count) * 2 * pi;
      return _Ray(
        angle: baseAngle + (_random.nextDouble() - 0.5) * 0.25,
        startRadius: 0.35 + _random.nextDouble() * 0.2,
        length: 0.18 + _random.nextDouble() * 0.28,
        width: 2.0 + _random.nextDouble() * 3.0,
        delay: _random.nextDouble() * 0.18,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (!_controller.isAnimating) return const SizedBox.expand();
          return CustomPaint(
            size: Size.infinite,
            painter: _BurstPainter(
              rays: _rays,
              progress: _controller.value,
              color: widget.color,
            ),
          );
        },
      ),
    );
  }
}

class _Ray {
  final double angle;
  final double startRadius; // fraction of half-diagonal
  final double length; // fraction of half-diagonal
  final double width;
  final double delay; // 0..1 fraction of the timeline

  const _Ray({
    required this.angle,
    required this.startRadius,
    required this.length,
    required this.width,
    required this.delay,
  });
}

class _BurstPainter extends CustomPainter {
  final List<_Ray> rays;
  final double progress;
  final Color color;

  _BurstPainter({
    required this.rays,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final reach = size.shortestSide * 0.5 + size.longestSide * 0.35;
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final ray in rays) {
      final t = ((progress - ray.delay) / (1.0 - ray.delay)).clamp(0.0, 1.0);
      if (t <= 0.0) continue;

      // Shoot outward fast, then the tail catches up to the head.
      final head = Curves.easeOutExpo.transform(t);
      final tail = Curves.easeInCubic.transform(t);
      final r0 = reach * (ray.startRadius + tail * (ray.length + 0.3));
      final r1 = reach * (ray.startRadius + head * (ray.length + 0.3));
      if (r1 <= r0) continue;

      final dir = Offset(cos(ray.angle), sin(ray.angle));
      final fade = t < 0.7 ? 1.0 : 1.0 - (t - 0.7) / 0.3;
      paint
        ..color = color.withValues(alpha: 0.9 * fade)
        ..strokeWidth = ray.width * (1.0 - t * 0.5);
      canvas.drawLine(center + dir * r0, center + dir * r1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) =>
      old.progress != progress || old.rays != rays || old.color != color;
}
