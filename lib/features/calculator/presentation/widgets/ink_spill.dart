import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The newsroom hunt's finale: ink floods out from [origin] until the screen
/// is black, [onCovered] swaps the skin underneath, then the ink dries away
/// into halftone dots that shrink from the origin outwards.
class InkSpill extends StatefulWidget {
  final Offset origin;
  final VoidCallback onCovered;
  final VoidCallback onDone;

  /// Lite mode: a plain fade to ink and back, nothing drawn per dot.
  final bool isLite;

  const InkSpill({
    super.key,
    required this.origin,
    required this.onCovered,
    required this.onDone,
    this.isLite = false,
  });

  static const ink = Color(0xFF141414);

  @override
  State<InkSpill> createState() => _InkSpillState();
}

class _InkSpillState extends State<InkSpill>
    with SingleTickerProviderStateMixin {
  // Flood until 0.42, hold black until 0.5 (the skin swaps there), dry out.
  static const _covered = 0.5;

  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _swapped = false;

  @override
  void initState() {
    super.initState();
    _c.addListener(() {
      if (!_swapped && _c.value >= _covered) {
        _swapped = true;
        widget.onCovered();
      }
    });
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          if (widget.isLite) {
            final t = _c.value;
            final a = t < _covered ? t / _covered : (1 - t) / (1 - _covered);
            return ColoredBox(
              color: InkSpill.ink.withValues(alpha: a.clamp(0.0, 1.0)),
              child: const SizedBox.expand(),
            );
          }
          return CustomPaint(
            painter: _InkPainter(_c.value, widget.origin),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _InkPainter extends CustomPainter {
  final double t;
  final Offset origin;

  _InkPainter(this.t, this.origin);

  // Fixed blobs so every frame of the spill is the same splash.
  static final _blobs = () {
    final r = math.Random(7);
    return List.generate(9, (i) {
      final angle = i / 9 * math.pi * 2 + r.nextDouble() * 0.6;
      return (
        dir: Offset(math.cos(angle), math.sin(angle)),
        reach: 0.15 + r.nextDouble() * 0.35,
        size: 0.45 + r.nextDouble() * 0.45,
        delay: r.nextDouble() * 0.25,
      );
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = InkSpill.ink;
    // Far enough to cover the farthest corner from the origin.
    final far = [
      Offset.zero,
      Offset(size.width, 0),
      Offset(0, size.height),
      Offset(size.width, size.height),
    ].map((c) => (c - origin).distance).reduce(math.max);

    if (t < 0.42) {
      final flood = t / 0.42;
      for (final b in _blobs) {
        final p = ((flood - b.delay) / (1 - b.delay)).clamp(0.0, 1.0);
        final e = Curves.easeInCubic.transform(p);
        final centre = origin + b.dir * (far * b.reach * e);
        canvas.drawCircle(centre, far * b.size * e * 1.3, paint);
      }
      canvas.drawCircle(origin, far * Curves.easeIn.transform(flood), paint);
      return;
    }
    if (t < 0.5) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Drying: each dot of a halftone grid shrinks, the origin's first.
    final dry = (t - 0.5) / 0.5;
    const cell = 14.0;
    for (var y = 0.0; y < size.height + cell; y += cell) {
      for (var x = 0.0; x < size.width + cell; x += cell) {
        final c = Offset(x, y);
        final d = (c - origin).distance / far;
        final local = (dry * 1.7 - d * 0.7).clamp(0.0, 1.0);
        final radius = cell * 0.75 * (1 - Curves.easeOut.transform(local));
        if (radius > 0.2) canvas.drawCircle(c, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.t != t;
}
