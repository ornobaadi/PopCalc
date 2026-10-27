import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// How much a [DropBackdrop] moves.
enum DropMotion {
  /// Painted once (store cards, mockups).
  still,

  /// Alive: drifting dunes and sand, a clock that really ticks.
  live,

  /// Lite mode: nothing drifts, the clock only moves once a second.
  calm,
}

/// Where the doomsday clock's hub sits, as fractions of the screen. The hold
/// that warps time starts there (see `DoomIncursion`).
const kClockHub = Offset(0.5, 0.34);

/// The state of the hold-the-clock egg, shared between the overlay that runs
/// it and the clock it spins.
class DoomWarp extends ChangeNotifier {
  /// 0..1 while the hold charges.
  double charge = 0.0;

  /// Extra turn, in radians, added to the hands and rings.
  double phase = 0.0;

  /// True from the boom until the clock comes back: hands stop at one tick
  /// short of twelve.
  bool frozen = false;

  void set({double? charge, double? phase, bool? frozen}) {
    this.charge = charge ?? this.charge;
    this.phase = phase ?? this.phase;
    this.frozen = frozen ?? this.frozen;
    notifyListeners();
  }

  void reset() => set(charge: 0.0, phase: 0.0, frozen: false);
}

/// The clock the dunes follow; tests swap it to stand at dusk.
DateTime Function() duneNow = DateTime.now;

/// Where the sun (by day) or the main moon (by night) hangs over the dunes,
/// from the clock alone: the sun is taken to rise at 6 and set at 18, and the
/// dark is full from about 19:00 to 5:00. An estimate, so no location is ever
/// asked for. The hold that wakes the worm starts on [body].
class DuneSky {
  final double night;
  final bool sunUp;
  final double golden;
  final double noon;
  final Offset sun;
  final Offset moon;

  const DuneSky._(
    this.night,
    this.sunUp,
    this.golden,
    this.noon,
    this.sun,
    this.moon,
  );

  Offset get body => sunUp ? sun : moon;

  static double _smooth(double x) {
    final k = x.clamp(0.0, 1.0);
    return k * k * (3 - 2 * k);
  }

  static double _night(double h) {
    if (h >= 19.2 || h <= 4.8) return 1.0;
    if (h > 18.0) return _smooth((h - 18.0) / 1.2);
    if (h < 6.0) return _smooth((6.0 - h) / 1.2);
    return 0.0;
  }

  static DuneSky at(DateTime n, Size size) {
    final hr = n.hour + n.minute / 60.0 + n.second / 3600.0;
    final up = hr >= 6.0 && hr <= 18.0;
    final u = ((hr - 6.0) / 12.0).clamp(0.0, 1.0);
    return DuneSky._(
      _night(hr),
      up,
      math.max(0.0, 1 - math.min((hr - 6.0).abs(), (hr - 18.0).abs()) / 1.6),
      up ? math.sin(math.pi * u) : 0.0,
      Offset(
        (0.14 + 0.72 * u) * size.width,
        (0.42 - 0.26 * math.sin(math.pi * u)) * size.height,
      ),
      Offset(size.width * 0.72, size.height * 0.17),
    );
  }
}

/// The scenery behind a limited drop: dunes under a low sun for
/// [SkinFinish.dune], a doomsday clock running on the phone's own time for
/// [SkinFinish.doom]. Every other skin gets nothing. Must sit directly in a
/// [Stack].
class DropBackdrop extends StatefulWidget {
  final ThemeColors colors;
  final DropMotion motion;
  final DoomWarp? warp;

  const DropBackdrop({
    super.key,
    required this.colors,
    this.motion = DropMotion.still,
    this.warp,
  });

  @override
  State<DropBackdrop> createState() => _DropBackdropState();
}

class _DropBackdropState extends State<DropBackdrop>
    with SingleTickerProviderStateMixin {
  /// Seconds since the backdrop appeared; what the painters repaint on.
  final _time = ValueNotifier<double>(0.0);
  Ticker? _ticker;
  double _lastPaint = -1.0;

  bool get _hasScenery =>
      widget.colors.finish == SkinFinish.dune ||
      widget.colors.finish == SkinFinish.doom;

  @override
  void initState() {
    super.initState();
    _syncTicker();
  }

  @override
  void didUpdateWidget(DropBackdrop old) {
    super.didUpdateWidget(old);
    _syncTicker();
  }

  void _syncTicker() {
    final run = _hasScenery && widget.motion != DropMotion.still;
    if (run && _ticker == null) {
      _ticker = createTicker((elapsed) {
        final t = elapsed.inMicroseconds / 1e6;
        // Calm mode repaints once a second; dunes stand still there.
        if (widget.motion == DropMotion.calm && t - _lastPaint < 1.0) return;
        _lastPaint = t;
        _time.value = t;
      })..start();
    } else if (!run && _ticker != null) {
      _ticker!.dispose();
      _ticker = null;
    }
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final live = widget.motion == DropMotion.live;
    final painter = switch (c.finish) {
      SkinFinish.dune => _DunePainter(
        c,
        _time,
        live,
        widget.motion != DropMotion.still,
        widget.warp,
      ),
      SkinFinish.doom => _ClockPainter(c, _time, live, widget.warp),
      _ => null,
    };
    if (painter == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: IgnorePointer(
        child: RepaintBoundary(child: CustomPaint(painter: painter)),
      ),
    );
  }
}

class _DunePainter extends CustomPainter {
  final ThemeColors c;
  final ValueNotifier<double> time;
  final bool live;

  /// True when the sky follows the phone's clock (the calculator); the store
  /// cards keep one fixed, golden look.
  final bool daylight;

  /// The hold that wakes the worm: its charge makes the dunes tremble and the
  /// sun or moon glow.
  final DoomWarp? warp;

  /// Grains of blown sand: where along the ridge line, how high, how fast.
  static final _grains = () {
    final r = math.Random(11);
    return List.generate(
      70,
      (_) => (r.nextDouble(), 0.5 + r.nextDouble() * 0.42, 0.012 + r.nextDouble() * 0.05),
    );
  }();

  /// Fixed stars for the night sky.
  static final _stars = () {
    final r = math.Random(3);
    return List.generate(46, (_) => (r.nextDouble(), r.nextDouble() * 0.42));
  }();

  _DunePainter(this.c, this.time, this.live, this.daylight, this.warp)
    : super(repaint: Listenable.merge([time, ?warp]));

  @override
  void paint(Canvas canvas, Size size) {
    final t = live ? time.value : 0.0;
    final w = size.width;
    final h = size.height;
    final charge = warp?.charge ?? 0.0;

    var night = 0.0;
    var golden = 0.0;
    var noon = 0.0;
    var sunUp = true;
    var sun = Offset(w * 0.74, h * 0.2);
    var moon = Offset(w * 0.72, h * 0.17);
    if (daylight) {
      final sky = DuneSky.at(duneNow(), size);
      night = sky.night;
      golden = sky.golden;
      noon = sky.noon;
      sunUp = sky.sunUp;
      sun = sky.sun;
      moon = sky.moon;
    }

    // The sky's mood over the whole scene: blue dark, copper hours, pale noon.
    final full = Offset.zero & size;
    if (night > 0) {
      canvas.drawRect(full, Paint()..color = Color.fromRGBO(8, 14, 44, 0.58 * night));
    }
    if (golden > 0) {
      canvas.drawRect(full, Paint()..color = Color.fromRGBO(255, 120, 40, 0.1 * golden));
    }
    if (noon > 0) {
      canvas.drawRect(full, Paint()..color = Color.fromRGBO(255, 241, 208, 0.07 * noon));
    }

    if (night > 0.2) {
      final pts = Float32List(_stars.length * 2);
      for (var i = 0; i < _stars.length; i++) {
        pts[i * 2] = _stars[i].$1 * w;
        pts[i * 2 + 1] = _stars[i].$2 * h;
      }
      canvas.drawRawPoints(
        ui.PointMode.points,
        pts,
        Paint()
          ..color = Color.fromRGBO(220, 232, 255, 0.7 * night)
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round,
      );
    }

    // The sun and the moon breathe a little, a hint for anyone who looks;
    // held, they blaze.
    final breathe = live ? 0.5 + 0.5 * math.sin(t * 1.4) : 0.5;
    if (sunUp) {
      // A low, hazy sun that breathes a little in the dust; fatter and
      // redder as it nears the horizon.
      final glow = 0.85 + 0.15 * math.sin(t * 0.5);
      final halo = w * (0.34 + 0.12 * golden + 0.1 * charge);
      final warm = Color.lerp(const Color(0xFFFFC27A), const Color(0xFFFF8A3D), golden)!;
      canvas.drawCircle(
        sun,
        halo,
        Paint()
          ..shader = ui.Gradient.radial(sun, halo, [
            warm.withValues(alpha: 0.34 * glow),
            warm.withValues(alpha: 0.0),
          ]),
      );
      final core = w * (0.075 + 0.02 * golden);
      canvas.drawCircle(
        sun,
        core,
        Paint()..color = Color.lerp(const Color(0xFFFFE2B0), warm, golden)!.withValues(alpha: 0.4 * glow),
      );
      final ring = core * (1.9 + 0.5 * breathe);
      canvas.drawCircle(
        sun,
        ring,
        Paint()
          ..shader = ui.Gradient.radial(sun, ring, [
            const Color(0xFFFFF0CC).withValues(alpha: 0.1 + 0.1 * breathe + 0.45 * charge),
            const Color(0x00FFF0CC),
          ]),
      );
    }
    if (night > 0.02) {
      // One pale moon, breathing a little: the hold that wakes the worm starts
      // here after dark.
      const mr = 0.032;
      final halo = mr * w * (3.2 + 1.2 * breathe + 2.5 * charge);
      canvas.drawCircle(
        moon,
        halo,
        Paint()
          ..shader = ui.Gradient.radial(moon, halo, [
            Color.fromRGBO(190, 210, 255, (0.22 + 0.1 * breathe + 0.4 * charge) * night),
            const Color(0x00BED2FF),
          ]),
      );
      canvas.drawCircle(moon, mr * w, Paint()..color = Color.fromRGBO(226, 234, 255, 0.85 * night));
    }

    // Three ridges, each darker and nearer; the far ones drift slowest.
    const ridges = [
      (0.62, 0.05, 0.0, 0.04, Color(0x2EFF9A4A)),
      (0.74, 0.06, 1.6, 0.07, Color(0x4D3A1706)),
      (0.87, 0.05, 3.1, 0.1, Color(0x80150802)),
    ];
    // Something large moves beneath the middle ridge, crossing every minute.
    final wormX = ((t / 55.0) % 1.5 - 0.25) * w;
    for (var k = 0; k < ridges.length; k++) {
      final (top, amp, phase, drift, color) = ridges[k];
      final p = phase + t * drift;
      final path = Path()..moveTo(0.0, h);
      for (var x = 0.0; x <= w; x += 6.0) {
        final u = x / w;
        var y =
            h *
            (top +
                amp * math.sin(u * math.pi * 1.4 + p) +
                amp * 0.4 * math.sin(u * math.pi * 3.3 + p * 2));
        if (live && k == 1) {
          final d = (x - wormX) / (w * 0.13);
          y -= h * 0.03 * math.exp(-d * d);
        }
        // Held, the ground shivers.
        if (charge > 0) y += math.sin(t * 38 + x * 0.05 + k) * h * 0.005 * charge;
        path.lineTo(x, y);
      }
      path
        ..lineTo(w, h)
        ..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    if (!live) return;
    // Sand carried on the wind, low over the dunes (and thrown up by a hold).
    final pts = Float32List(_grains.length * 2);
    for (var i = 0; i < _grains.length; i++) {
      final (x0, y0, speed) = _grains[i];
      pts[i * 2] = ((x0 + t * speed) % 1.0) * w;
      pts[i * 2 + 1] =
          h * y0 +
          math.sin(t * 1.3 + i) * h * 0.008 -
          charge * h * 0.03 * (0.5 + 0.5 * math.sin(t * 23 + i * 7));
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      pts,
      Paint()
        ..color = const Color(0x66FFD9A0)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_DunePainter old) =>
      old.c != c || old.live != live || old.daylight != daylight;
}

class _ClockPainter extends CustomPainter {
  final ThemeColors c;
  final ValueNotifier<double> time;
  final bool live;
  final DoomWarp? warp;

  _ClockPainter(this.c, this.time, this.live, this.warp)
    : super(repaint: Listenable.merge([time, ?warp]));

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final now = DateTime.now();
    final centre = Offset(size.width * kClockHub.dx, size.height * kClockHub.dy);
    final r = size.width * 0.62;
    final charge = warp?.charge ?? 0.0;
    final spin = warp?.phase ?? 0.0;
    final frozen = warp?.frozen ?? false;

    // The face: sixty ticks, the twelve lit.
    final tick = Paint()..strokeCap = StrokeCap.round;
    for (var i = 0; i < 60; i++) {
      final a = i * math.pi / 30 - math.pi / 2;
      final big = i % 5 == 0;
      tick
        ..strokeWidth = big ? 3.0 : 1.2
        ..color = c.accent.withValues(
          alpha: i == 0 ? 0.5 + 0.5 * charge : 0.16 + 0.3 * charge,
        );
      final inner = r * (big ? 0.9 : 0.95);
      canvas.drawLine(
        centre + Offset(math.cos(a), math.sin(a)) * inner,
        centre + Offset(math.cos(a), math.sin(a)) * r,
        tick,
      );
    }
    canvas.drawCircle(
      centre,
      r * 0.86,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..color = c.accent.withValues(alpha: 0.1),
    );

    // Rings of green energy turning around the face, opposite ways.
    if (live) {
      void arcs(double radius, double turn, int count, double alpha) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 2.0
          ..color = c.accent.withValues(alpha: alpha);
        final span = 2 * math.pi / count;
        for (var i = 0; i < count; i++) {
          canvas.drawArc(
            Rect.fromCircle(center: centre, radius: radius),
            turn + i * span,
            span * 0.38,
            false,
            paint,
          );
        }
      }

      final pulse = 0.5 + 0.5 * math.sin(t * 1.4);
      arcs(r * 1.04, t * 0.12 + spin * 0.3, 3, 0.1 + 0.08 * pulse + 0.5 * charge);
      arcs(r * 0.78, -t * 0.2 - spin * 0.45, 5, 0.07 + 0.05 * pulse + 0.4 * charge);
    }

    // The hands tell the phone's own time. The second hand ticks with a
    // tiny overshoot, like a mechanism, instead of gliding.
    final ms = now.millisecond / 1000.0;
    final step = live && ms < 0.18 ? _backOut(ms / 0.18) : 1.0;
    var sec = now.second + step;
    var minute = now.minute + sec / 60.0;
    var hour = (now.hour % 12) + minute / 60.0;
    if (frozen) {
      // Stopped one tick short of twelve.
      sec = 59.9;
      minute = 59.98;
      hour = 11.999;
    } else if (spin != 0.0) {
      // Held: the hands race, the second hand fastest.
      const turn = 1 / (2 * math.pi);
      sec += spin * turn * 60;
      minute += spin * turn * 12;
      hour += spin * turn * 2;
    }

    void hand(double turn, double length, double width, double alpha) {
      final a = turn * 2 * math.pi - math.pi / 2;
      final tip = centre + Offset(math.cos(a), math.sin(a)) * r * length;
      // A wide soft stroke under the hand stands in for a glow.
      canvas.drawLine(
        centre,
        tip,
        Paint()
          ..color = c.accent.withValues(alpha: alpha * 0.25)
          ..strokeWidth = width * 3.2
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        centre,
        tip,
        Paint()
          ..color = c.accent.withValues(alpha: alpha)
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    final boost = 1.0 + charge;
    hand(hour / 12, 0.5, 5.0, math.min(1.0, 0.26 * boost));
    hand(minute / 60, 0.8, 3.0, math.min(1.0, 0.32 * boost));
    hand(sec / 60, 0.9, 1.6, math.min(1.0, 0.6 * boost));
    // The hub breathes a little: the place to hold, for anyone who looks.
    final breathe = live ? 0.5 + 0.5 * math.sin(t * 1.6) : 0.5;
    final glowR = 24.0 + 8.0 * breathe + 60.0 * charge;
    canvas.drawCircle(
      centre,
      glowR,
      Paint()
        ..shader = ui.Gradient.radial(centre, glowR, [
          c.accent.withValues(alpha: 0.12 + 0.1 * breathe + 0.4 * charge),
          c.accent.withValues(alpha: 0.0),
        ]),
    );
    canvas.drawCircle(centre, 6.0, Paint()..color = c.accent.withValues(alpha: 0.45));
  }

  /// Ease that overshoots a little before settling.
  static double _backOut(double x) {
    const k = 2.2;
    final u = x - 1.0;
    return 1.0 + (k + 1.0) * u * u * u + k * u * u;
  }

  @override
  bool shouldRepaint(_ClockPainter old) => old.c != c || old.live != live;
}
