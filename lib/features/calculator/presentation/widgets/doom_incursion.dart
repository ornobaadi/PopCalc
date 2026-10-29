import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_soloud/flutter_soloud.dart' show SoundHandle;
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'drop_backdrop.dart';
import 'egg_hint.dart';
import 'doom_mask.dart';

/// Reckoning's hidden moment. Press and hold the hub of the doomsday clock:
/// the hands race, the rings spin up and the phone ticks faster and harder.
/// Let go after the charge has built and the clock stops dead, the screen
/// splits with green light, goes dark, and an iron-masked figure rises out of
/// it with a line for you. Let go too early and the charge just fades.
///
/// Must sit directly in a [Stack], above the calculator, which it covers only
/// while the sequence plays.
class DoomIncursion extends StatefulWidget {
  final DoomWarp warp;
  final Color light;
  final bool lite;

  /// Screen shake, applied by the calculator to everything it draws.
  final ValueNotifier<Offset>? shake;

  /// True while a hold or the sequence is running, so the calculator under it
  /// can ignore the taps and long presses that same touch also makes.
  final ValueChanged<bool>? onBusy;

  const DoomIncursion({
    super.key,
    required this.warp,
    required this.light,
    this.lite = false,
    this.shake,
    this.onBusy,
  });

  /// The line the figure speaks.
  static const line = 'HELL ANSWERS TO ME';

  @override
  State<DoomIncursion> createState() => _DoomIncursionState();
}

enum _Phase { idle, charging, fizzle, boom }

class _DoomIncursionState extends State<DoomIncursion>
    with SingleTickerProviderStateMixin {
  static const _folder = 'reckoning';
  static const _chargeSeconds = 2.0;
  static const _minCharge = 0.35;
  static const _hold = 5.2; // where the figure starts to leave
  static const _total = 6.6;

  late final Ticker _ticker = createTicker(_tick);
  final _t = ValueNotifier<double>(0.0);
  _Phase _phase = _Phase.idle;
  Duration _last = Duration.zero;
  double _held = 0.0;
  Timer? _pulse;
  Timer? _arm;
  SoundHandle? _chargeHandle;
  /// First-time "HOLD HERE" nudge, until the moment has been found once.
  bool _hint = false;
  bool _voiced = false;
  bool _rumbled = false;

  @override
  void initState() {
    super.initState();
    EggHint.pending('reckoning').then((show) {
      if (mounted && show) setState(() => _hint = true);
    });
    AppSounds.warmExtras(_folder, const ['warp_charge', 'warp_boom', 'warp_voice']);
  }

  @override
  void dispose() {
    _pulse?.cancel();
    _arm?.cancel();
    _ticker.dispose();
    _t.dispose();
    AppSounds.stopExtra(_chargeHandle);
    widget.warp
      ..charge = 0.0
      ..phase = 0.0
      ..frozen = false;
    super.dispose();
  }

  /// A quick tap on the hub is just a tap; the charge starts once the finger
  /// has stayed down for a moment.
  void _down(PointerDownEvent _) {
    if (_phase != _Phase.idle) return;
    _arm?.cancel();
    _arm = Timer(const Duration(milliseconds: 250), _begin);
  }

  void _begin() {
    if (_phase != _Phase.idle) return;
    _phase = _Phase.charging;
    _held = 0.0;
    _voiced = false;
    _rumbled = false;
    widget.onBusy?.call(true);
    widget.warp.set(charge: 0.0, phase: 0.0, frozen: false);
    _chargeHandle = AppSounds.playExtra(_folder, 'warp_charge');
    _last = Duration.zero;
    _ticker.start();
    _schedulePulse();
  }

  /// A tick under the finger, faster and harder as the charge climbs.
  void _schedulePulse() {
    _pulse?.cancel();
    final c = widget.warp.charge;
    _pulse = Timer(Duration(milliseconds: (190 - 130 * c).round()), () {
      if (_phase != _Phase.charging) return;
      AppHaptics.charge(widget.warp.charge);
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
      setState(() => _phase = _Phase.boom);
      if (_hint) {
        _hint = false;
        EggHint.markFound('reckoning');
      }
      _t.value = 0.0;
      widget.warp.set(charge: 1.0, frozen: true);
      AppSounds.playExtra(_folder, 'warp_boom');
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
        warp.set(charge: c, phase: warp.phase + dt * (2 + 44 * c * c));
      case _Phase.fizzle:
        final c = warp.charge - dt * 2.5;
        if (c <= 0) {
          _finish();
        } else {
          warp.set(charge: c, phase: warp.phase + dt * 10 * c);
        }
      case _Phase.boom:
        _t.value += dt;
        final t = _t.value;
        final amp = 14.0 * math.exp(-t * 3.2);
        widget.shake?.value = Offset(math.sin(t * 57) * amp, math.cos(t * 43) * amp);
        if (t >= 1.5 && !_voiced) {
          _voiced = true;
          AppSounds.playExtra(_folder, 'warp_voice');
        }
        if (t >= 2.0 && !_rumbled) {
          _rumbled = true;
          AppHaptics.rumble();
        }
        if (t >= 5.6 && warp.frozen) {
          // Hidden under the dark: the clock goes back to the time it is.
          warp.reset();
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
    widget.shake?.value = Offset.zero;
    _phase = _Phase.idle;
    widget.onBusy?.call(false);
    if (mounted) setState(() {});
  }

  /// A tap once the figure has appeared sends it away early.
  void _skip() {
    if (_t.value > 2.4 && _t.value < _hold) _t.value = _hold;
  }

  @override
  Widget build(BuildContext context) {
    final boom = _phase == _Phase.boom;
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final hub = Offset(size.width * kClockHub.dx, size.height * kClockHub.dy);
          final maskSize = size.width * 0.78;
          final maskCentre = Offset(size.width / 2, size.height * 0.4);
          return Stack(
            children: [
              // The charge, glowing out of the hub.
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: widget.warp,
                  builder: (_, _) => widget.warp.charge <= 0.0 || boom
                      ? const SizedBox.expand()
                      : CustomPaint(
                          size: Size.infinite,
                          painter: _ChargePainter(
                            widget.warp.charge,
                            hub,
                            widget.light,
                            _held,
                          ),
                        ),
                ),
              ),
              // The place to hold: the hub of the clock. Translucent, so the
              // calculator under it still hears the same touch.
              Positioned(
                left: hub.dx - 110.0,
                top: hub.dy - 110.0,
                width: 220.0,
                height: 220.0,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: _down,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: const SizedBox.expand(),
                ),
              ),
              if (_hint && _phase == _Phase.idle)
                EggHint(at: hub, color: widget.light),
              if (boom) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _skip,
                    child: ValueListenableBuilder<double>(
                      valueListenable: _t,
                      builder: (_, t, _) => CustomPaint(
                        size: Size.infinite,
                        painter: _BoomPainter(
                          t,
                          hub,
                          maskCentre,
                          maskSize,
                          widget.light,
                          widget.lite,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0.0,
                  right: 0.0,
                  top: maskCentre.dy + maskSize * 0.66 + 10.0,
                  child: IgnorePointer(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _t,
                      builder: (_, t, _) {
                        final a = _smooth(2.9, 3.5, t) * (1 - _smooth(_hold, 5.8, t));
                        return Opacity(
                          opacity: a,
                          // One line, always: it shrinks to fit a narrow
                          // screen instead of breaking in two.
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                DoomIncursion.line,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 32.0,
                                  height: 1.0,
                                  letterSpacing: 12.0 - 7.0 * _smooth(2.9, 4.4, t),
                                  color: const Color(0xFFE8FFF1),
                                  shadows: [
                                    Shadow(color: widget.light, blurRadius: 18.0),
                                    Shadow(color: widget.light, blurRadius: 40.0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
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

class _ChargePainter extends CustomPainter {
  final double charge;
  final Offset hub;
  final Color light;
  final double held;

  _ChargePainter(this.charge, this.hub, this.light, this.held);

  @override
  void paint(Canvas canvas, Size size) {
    final r = 40.0 + 230.0 * charge;
    canvas.drawCircle(
      hub,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Color.lerp(light, const Color(0xFFE8FFF1), charge)!.withValues(alpha: 0.65 * charge),
            light.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: hub, radius: r)),
    );
    // Near full charge the edges of the screen start to burn.
    if (charge > 0.6) {
      final a = (charge - 0.6) / 0.4 * (0.25 + 0.1 * math.sin(held * 30));
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            radius: 0.9,
            colors: [light.withValues(alpha: 0.0), light.withValues(alpha: a)],
          ).createShader(Offset.zero & size),
      );
    }
  }

  @override
  bool shouldRepaint(_ChargePainter old) => true;
}

class _BoomPainter extends CustomPainter {
  final double t;
  final Offset hub;
  final Offset maskCentre;
  final double maskSize;
  final Color light;
  final bool lite;

  _BoomPainter(this.t, this.hub, this.maskCentre, this.maskSize, this.light, this.lite);

  /// Fault lines running out of the hub: 16 jagged rays with a branch each,
  /// as unit offsets so they scale to any screen.
  static final List<List<Offset>> _rays = () {
    final r = math.Random(9);
    final rays = <List<Offset>>[];
    for (var i = 0; i < 16; i++) {
      var a = i * 2 * math.pi / 16 + (r.nextDouble() - 0.5) * 0.3;
      var p = Offset.zero;
      final pts = <Offset>[p];
      for (var s = 0; s < 9; s++) {
        a += (r.nextDouble() - 0.5) * 0.7;
        p += Offset(math.cos(a), math.sin(a)) * (0.07 + r.nextDouble() * 0.05);
        pts.add(p);
      }
      rays.add(pts);
    }
    return rays;
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    final diag = size.longestSide;

    // The dark that comes after the flash.
    final dark = _smooth(0.7, 1.6, t) * 0.95 * (1 - _smooth(5.6, 6.6, t));
    canvas.drawRect(full, Paint()..color = Color.fromRGBO(2, 6, 4, dark));
    // A green sickness at the edges while it is darkest.
    canvas.drawRect(
      full,
      Paint()
        ..shader = RadialGradient(
          radius: 0.85,
          colors: [
            light.withValues(alpha: 0.0),
            light.withValues(alpha: 0.22 * dark),
          ],
        ).createShader(full),
    );

    // The cracks race out, then settle to a faint web behind the figure.
    final grow = Curves.easeOut.transform((t / 1.0).clamp(0.0, 1.0));
    final fade = 1 - 0.75 * _smooth(1.8, 3.4, t) - 0.25 * _smooth(_BoomLimits.leave, 6.2, t);
    if (grow > 0 && fade > 0) {
      final glow = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 7.0
        ..color = light.withValues(alpha: 0.22 * fade);
      final core = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.7
        ..color = const Color(0xFFD9FFE8).withValues(alpha: 0.9 * fade);
      for (final ray in _rays) {
        final upto = (ray.length - 1) * grow;
        final path = Path()..moveTo(hub.dx, hub.dy);
        for (var i = 1; i <= upto.floor(); i++) {
          path.lineTo(hub.dx + ray[i].dx * diag, hub.dy + ray[i].dy * diag);
        }
        final k = upto.floor();
        if (k < ray.length - 1) {
          final f = upto - k;
          final p = Offset.lerp(ray[k], ray[k + 1], f)!;
          path.lineTo(hub.dx + p.dx * diag, hub.dy + p.dy * diag);
        }
        if (!lite) canvas.drawPath(path, glow);
        canvas.drawPath(path, core);
      }
    }

    // The figure.
    final eyes = _smooth(1.7, 2.4, t) * (0.9 + 0.1 * math.sin(t * 37));
    final alpha = _smooth(2.0, 3.0, t) * (1 - _smooth(_BoomLimits.leave, 6.0, t));
    final scale = 0.94 + 0.06 * Curves.easeOut.transform(_smooth(2.0, 3.8, t));
    final breathe = 1 + 0.008 * math.sin(t * 1.7);
    paintDoomMask(
      canvas,
      maskCentre,
      maskSize * scale * breathe,
      glow: eyes.clamp(0.0, 1.0),
      alpha: alpha,
      light: light,
      soft: !lite,
    );

    // The flash, first of all.
    final flash = math.pow(1 - (t / 0.4).clamp(0.0, 1.0), 2).toDouble();
    if (flash > 0) {
      canvas.drawRect(full, Paint()..color = const Color(0xFFE8FFF1).withValues(alpha: 0.95 * flash));
    }
  }

  @override
  bool shouldRepaint(_BoomPainter old) => old.t != t;
}

class _BoomLimits {
  static const leave = _DoomIncursionState._hold;
}
