import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show SoundHandle;
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'drop_backdrop.dart';

/// Mirage's hidden moment. Press and hold the sun (or the moon, after
/// dark): a drumbeat starts in your hand and speeds up, the screen shudders
/// and the dunes tremble. Let go and a great sand worm rises out of the
/// desert, opens its petalled mouth to the sky, hums, and sinks back under.
///
/// The worm is our own: ringed armour, a rounded head and a mouth that opens
/// like a flower, drawn warm and calm rather than frightening.
///
/// Must sit directly in a [Stack], above the calculator, which it covers only
/// while the sequence plays.
class SandWormEgg extends StatefulWidget {
  final DoomWarp warp;

  /// Screen shake, applied by the calculator to everything it draws.
  final ValueNotifier<Offset> shake;
  final bool lite;
  final ValueChanged<bool>? onBusy;

  const SandWormEgg({
    super.key,
    required this.warp,
    required this.shake,
    this.lite = false,
    this.onBusy,
  });

  @override
  State<SandWormEgg> createState() => _SandWormEggState();
}

enum _Phase { idle, charging, fizzle, rising }

class _SandWormEggState extends State<SandWormEgg>
    with SingleTickerProviderStateMixin {
  static const _folder = 'mirage';
  static const _chargeSeconds = 2.0;
  static const _minCharge = 0.35;
  static const _zone = 110.0;
  static const _leave = 5.0; // where the worm starts to sink
  static const _total = 8.0;

  late final Ticker _ticker = createTicker(_tick);
  final _t = ValueNotifier<double>(0.0);
  _Phase _phase = _Phase.idle;
  Duration _last = Duration.zero;
  double _held = 0.0;
  Size _size = Size.zero;
  Timer? _pulse;
  Timer? _arm;
  SoundHandle? _chargeHandle;
  bool _rumbled1 = false;
  bool _rumbled2 = false;

  @override
  void initState() {
    super.initState();
    AppSounds.warmExtras(_folder, const ['worm_charge', 'worm_rise']);
  }

  @override
  void dispose() {
    _pulse?.cancel();
    _arm?.cancel();
    _ticker.dispose();
    _t.dispose();
    AppSounds.stopExtra(_chargeHandle);
    widget.shake.value = Offset.zero;
    widget.warp
      ..charge = 0.0
      ..phase = 0.0
      ..frozen = false;
    super.dispose();
  }

  /// The sun by day, the moon after dark: where the hold must start.
  Offset get _body => DuneSky.at(duneNow(), _size).body;

  void _down(PointerDownEvent e) {
    if (_phase != _Phase.idle || _size.isEmpty) return;
    if ((e.localPosition - _body).distance > _zone) return;
    _arm?.cancel();
    // A quick tap is just a tap; the charge starts once the finger stays.
    _arm = Timer(const Duration(milliseconds: 250), _begin);
  }

  void _begin() {
    if (_phase != _Phase.idle) return;
    _phase = _Phase.charging;
    _held = 0.0;
    _rumbled1 = false;
    _rumbled2 = false;
    widget.onBusy?.call(true);
    widget.warp.set(charge: 0.0, phase: 0.0, frozen: false);
    _chargeHandle = AppSounds.playExtra(_folder, 'worm_charge');
    _last = Duration.zero;
    _ticker.start();
    _schedulePulse();
  }

  /// A beat under the finger, faster and heavier as the charge climbs.
  void _schedulePulse() {
    _pulse?.cancel();
    final c = widget.warp.charge;
    _pulse = Timer(Duration(milliseconds: (330 - 230 * c).round()), () {
      if (_phase != _Phase.charging) return;
      AppHaptics.mediumImpact();
      _schedulePulse();
    });
  }

  void _up(PointerEvent _) {
    _arm?.cancel();
    if (_phase != _Phase.charging) return;
    _pulse?.cancel();
    AppSounds.stopExtra(_chargeHandle);
    _chargeHandle = null;
    if (widget.warp.charge >= _minCharge) {
      setState(() => _phase = _Phase.rising);
      _t.value = 0.0;
      widget.warp.set(charge: 1.0);
      AppSounds.playExtra(_folder, 'worm_rise');
      AppHaptics.boom();
    } else {
      _phase = _Phase.fizzle;
      AppHaptics.selectionClick();
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero
        ? 0.0
        : (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    final warp = widget.warp;
    switch (_phase) {
      case _Phase.charging:
        _held += dt;
        final c = (_held / _chargeSeconds).clamp(0.0, 1.0);
        warp.set(charge: c);
        final amp = 0.8 + 3.2 * c;
        widget.shake.value = Offset(
          math.sin(_held * 61) * amp,
          math.cos(_held * 47) * amp,
        );
      case _Phase.fizzle:
        final c = warp.charge - dt * 2.5;
        if (c <= 0) {
          _finish();
        } else {
          warp.set(charge: c);
          widget.shake.value = Offset(math.sin(_held * 61) * 2 * c, 0);
        }
      case _Phase.rising:
        _t.value += dt;
        final t = _t.value;
        // The ground settles as the worm comes up.
        warp.set(charge: (1 - t / 3.5).clamp(0.0, 1.0));
        final amp = 9.0 * math.exp(-t * 1.6) + (t < 2.6 ? 0.6 : 0.0);
        widget.shake.value = Offset(
          math.sin(t * 53) * amp,
          math.cos(t * 41) * amp,
        );
        if (t >= 1.0 && !_rumbled1) {
          _rumbled1 = true;
          AppHaptics.rumble();
        }
        if (t >= 2.6 && !_rumbled2) {
          _rumbled2 = true;
          AppHaptics.rumble();
        }
        if (t >= _total) _finish();
      case _Phase.idle:
        break;
    }
  }

  void _finish() {
    _ticker.stop();
    _pulse?.cancel();
    widget.warp.reset();
    widget.shake.value = Offset.zero;
    _phase = _Phase.idle;
    widget.onBusy?.call(false);
    if (mounted) setState(() {});
  }

  /// A tap once the worm is up sends it back down early.
  void _skip() {
    if (_t.value > 2.6 && _t.value < _leave) _t.value = _leave;
  }

  @override
  Widget build(BuildContext context) {
    final rising = _phase == _Phase.rising;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          _size = box.biggest;
          return Stack(
            children: [
              // Translucent, so the calculator under it still hears the same
              // touch; only a hold that starts on the sun or moon counts.
              Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: _down,
                onPointerUp: _up,
                onPointerCancel: _up,
                child: const SizedBox.expand(),
              ),
              if (rising)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skip,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _t,
                      builder: (_, t, _) => CustomPaint(
                        size: Size.infinite,
                        painter: _WormPainter(
                          t,
                          _body.dx > _size.width / 2 ? 1.0 : -1.0,
                          widget.lite,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

double _smooth(double a, double b, double t) {
  final x = ((t - a) / (b - a)).clamp(0.0, 1.0);
  return x * x * (3 - 2 * x);
}

class _WormPainter extends CustomPainter {
  final double t;

  /// +1 when the light (sun or moon) is on the right of the screen, else -1.
  final double lightX;
  final bool lite;

  _WormPainter(this.t, this.lightX, this.lite);

  static const _segments = 46;

  static final _grains = () {
    final r = math.Random(21);
    return List.generate(
      90,
      (_) => (r.nextDouble(), r.nextDouble() - 0.5, r.nextDouble()),
    );
  }();

  Offset _spine(double s, Size size, double sway, double lean) {
    final w = size.width;
    final h = size.height;
    final p0 = Offset(w * 0.5, h * 0.97);
    final p1 = Offset(w * 0.4 + sway * 0.5, h * 0.72);
    final p2 = Offset(w * 0.64 + sway, h * 0.5);
    final p3 = Offset(w * 0.5 + sway * 1.6 + lean, h * 0.24);
    final u = 1 - s;
    return p0 * (u * u * u) +
        p1 * (3 * u * u * s) +
        p2 * (3 * u * s * s) +
        p3 * (s * s * s);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final full = Offset.zero & size;
    final base = Offset(w * 0.5, h * 0.9);

    // The scene dims a little so the worm reads against the sky.
    final dim = _smooth(0.1, 1.2, t) * (1 - _smooth(6.4, 8.0, t));
    canvas.drawRect(full, Paint()..color = Color.fromRGBO(10, 4, 0, 0.32 * dim));

    // Rise, then sink: how much of the spine is out of the sand.
    final up = Curves.easeOutCubic.transform(((t - 0.15) / 2.45).clamp(0.0, 1.0));
    final down = Curves.easeInCubic.transform(((t - 5.6) / 1.8).clamp(0.0, 1.0));
    final e = (up * (1 - down)).clamp(0.0, 1.0);
    final sway = math.sin(t * 0.9) * w * 0.035;
    final lean = -w * 0.1 * down + math.sin(t * 0.5) * w * 0.01;

    // Dust first, behind the body.
    _dust(canvas, size, base);

    if (e > 0.01) {
      // The body: a ringed tube along the spine, lit from the side of the sun.
      final pts = <Offset>[];
      final nor = <Offset>[];
      final half = <double>[];
      for (var i = 0; i <= _segments; i++) {
        final s = e * i / _segments;
        final p = _spine(s, size, sway, lean);
        final a = _spine((s + 0.004).clamp(0.0, 1.0), size, sway, lean);
        final b = _spine((s - 0.004).clamp(0.0, 1.0), size, sway, lean);
        var tan = a - b;
        tan = tan / (tan.distance == 0 ? 1 : tan.distance);
        pts.add(p);
        nor.add(Offset(-tan.dy, tan.dx));
        // Stout, tapering a little, then swelling into the head.
        final f = i / _segments;
        half.add(w * (0.165 - 0.03 * f + 0.045 * math.exp(-math.pow((f - 1.0) / 0.12, 2))));
      }
      const dark = Color(0xFF2B1A0E);
      const mid = Color(0xFF7A5230);
      const lit = Color(0xFFD9A468);
      for (var i = 0; i < _segments; i++) {
        final l0 = pts[i] - nor[i] * half[i];
        final r0 = pts[i] + nor[i] * half[i];
        final l1 = pts[i + 1] - nor[i + 1] * half[i + 1];
        final r1 = pts[i + 1] + nor[i + 1] * half[i + 1];
        final quad = Path()
          ..moveTo(l0.dx, l0.dy)
          ..lineTo(l1.dx, l1.dy)
          ..lineTo(r1.dx, r1.dy)
          ..lineTo(r0.dx, r0.dy)
          ..close();
        // Which edge of the tube faces the light.
        final towardLight = nor[i].dx * lightX >= 0 ? r0 : l0;
        final away = nor[i].dx * lightX >= 0 ? l0 : r0;
        canvas.drawPath(
          quad,
          Paint()
            ..shader = ui.Gradient.linear(
              away,
              towardLight,
              const [dark, mid, lit],
              const [0.0, 0.55, 1.0],
            ),
        );
        // Armour rings: a groove every third band, a slightly paler plate
        // between.
        if (i % 3 == 0) {
          canvas.drawLine(
            l0,
            r0,
            Paint()
              ..color = const Color(0x66200F05)
              ..strokeWidth = 2.2,
          );
        } else if (i % 3 == 1) {
          canvas.drawPath(quad, Paint()..color = const Color(0x14FFE6B8));
        }
      }
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0x99160A03);
      final left = Path()..moveTo(pts[0].dx - nor[0].dx * half[0], pts[0].dy - nor[0].dy * half[0]);
      final right = Path()..moveTo(pts[0].dx + nor[0].dx * half[0], pts[0].dy + nor[0].dy * half[0]);
      for (var i = 1; i <= _segments; i++) {
        left.lineTo(pts[i].dx - nor[i].dx * half[i], pts[i].dy - nor[i].dy * half[i]);
        right.lineTo(pts[i].dx + nor[i].dx * half[i], pts[i].dy + nor[i].dy * half[i]);
      }
      canvas
        ..drawPath(left, edge)
        ..drawPath(right, edge);

      // The head: the mouth opens like a flower to the sky.
      final open = _smooth(2.3, 3.5, t) * (1 - _smooth(5.0, 5.7, t));
      final tip = pts[_segments];
      var tanTip = pts[_segments] - pts[_segments - 2];
      tanTip = tanTip / (tanTip.distance == 0 ? 1 : tanTip.distance);
      _mouth(canvas, tip, nor[_segments], tanTip, half[_segments], open);

      // Sand running off the body.
      final dropPts = <double>[];
      for (final (s0, jitter, seed) in _grains) {
        final cyc = (t * 0.7 + seed * 3.1) % 1.0;
        final p = _spine(s0 * e, size, sway, lean);
        dropPts
          ..add(p.dx + jitter * w * 0.26)
          ..add(p.dy + cyc * h * 0.16);
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(dropPts),
        Paint()
          ..color = const Color(0x99F0C888)
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );
    }

    // The mound the worm comes out of, over its base.
    final mound = _smooth(0.0, 0.4, t) * (1 - _smooth(7.0, 8.0, t));
    if (mound > 0) {
      final path = Path()
        ..moveTo(-w * 0.05, h)
        ..quadraticBezierTo(w * 0.2, h * 0.9, w * 0.5, h * 0.865)
        ..quadraticBezierTo(w * 0.8, h * 0.9, w * 1.05, h)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, h * 0.86), Offset(0, h), [
            const Color(0xFF7A5230).withValues(alpha: mound),
            const Color(0xFF1C0E05).withValues(alpha: mound),
          ]),
      );
    }

    // Rings in the sand where it went under.
    final ripple = _smooth(6.3, 6.6, t) * (1 - _smooth(7.0, 8.0, t));
    if (ripple > 0) {
      for (var k = 0; k < 3; k++) {
        final r = w * (0.12 + 0.13 * k + 0.2 * _smooth(6.3, 8.0, t));
        canvas.drawOval(
          Rect.fromCenter(center: base, width: r * 2, height: r * 0.55),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.0
            ..color = const Color(0xFFE8BE82).withValues(alpha: 0.5 * ripple * (1 - k * 0.25)),
        );
      }
    }
  }

  void _dust(Canvas canvas, Size size, Offset base) {
    final w = size.width;
    final burst = _smooth(0.0, 0.5, t) * (1 - _smooth(2.2, 5.0, t));
    final again = _smooth(5.8, 6.4, t) * (1 - _smooth(6.4, 8.0, t));
    final a = math.max(burst, again * 0.8);
    if (a <= 0) return;
    for (final (dx, r) in const [(-0.2, 0.22), (0.0, 0.3), (0.2, 0.22)]) {
      final c = base + Offset(dx * w, -w * 0.03);
      final rad = w * r * (0.7 + 0.5 * a);
      canvas.drawCircle(
        c,
        rad,
        Paint()
          ..shader = ui.Gradient.radial(c, rad, [
            const Color(0xFFE0B070).withValues(alpha: 0.42 * a),
            const Color(0x00E0B070),
          ]),
      );
    }
  }

  void _mouth(Canvas canvas, Offset tip, Offset nor, Offset tan, double half, double open) {
    canvas.save();
    canvas.translate(tip.dx, tip.dy);
    canvas.rotate(math.atan2(nor.dy, nor.dx));
    final yAxis = Offset(-nor.dy, nor.dx);
    // Which way "forward" points once the frame is turned.
    final fy = (tan.dx * yAxis.dx + tan.dy * yAxis.dy) >= 0 ? 1.0 : -1.0;
    final rx = half * 1.04;
    final ry = rx * (0.3 + 0.5 * open);

    void petal(double phi) {
      final p = Offset(rx * math.cos(phi), ry * math.sin(phi));
      final d = Offset(math.cos(phi) * 0.6, fy * 0.75 + math.sin(phi) * 0.35);
      final dir = d / d.distance;
      final len = rx * (0.06 + 0.4 * open);
      final r = rx * 0.105;
      final end = p + dir * len;
      canvas.drawLine(
        p,
        end,
        Paint()
          ..color = const Color(0xFFB08A5C)
          ..strokeWidth = r * 2.3
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        p,
        end,
        Paint()
          ..color = const Color(0xFFEBD6AA)
          ..strokeWidth = r * 1.8
          ..strokeCap = StrokeCap.round,
      );
    }

    const n = 15;
    final order = List.generate(n, (k) => k * 2 * math.pi / n + 0.2)
      ..sort((a, b) => (math.sin(a) * fy).compareTo(math.sin(b) * fy));
    final backCount = order.where((a) => math.sin(a) * fy < 0).length;
    for (var k = 0; k < backCount; k++) {
      petal(order[k]);
    }
    // The throat: a warm light inside.
    final throat = Rect.fromCenter(center: Offset.zero, width: rx * 1.84, height: ry * 2.0);
    canvas.drawOval(
      throat,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, rx, [
          Color.lerp(const Color(0xFF8A3A14), const Color(0xFFFFC25A), open * (0.8 + 0.2 * math.sin(t * 3)))!,
          const Color(0xFF3A1606),
        ], const [0.0, 1.0]),
    );
    for (var k = backCount; k < n; k++) {
      petal(order[k]);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_WormPainter old) => old.t != t;
}
