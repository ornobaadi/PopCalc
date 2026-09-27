import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'numeral_glyphs.dart';
import 'numeral_renderer.dart';
import 'vec_math.dart';

/// Loads the numeral shader once. [program] stays null if shaders are
/// unavailable, and callers fall back to the 2D numerals.
class Numeral3DProgram {
  static ui.FragmentProgram? program;
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= () async {
        try {
          program = await ui.FragmentProgram.fromAsset('shaders/numeral3d.frag');
        } catch (_) {}
      }();
}

/// One glyph's physical state. Positions are em relative to the string
/// centre; orientation is world space.
class _Body {
  final String char;
  final NumeralGlyph glyph;
  double targetX;
  double x;
  double vx = 0;
  double y = 0; // em offset from the baseline slot
  double vy = 0;
  double s = 1; // pop scale
  double vs = 0;
  Quat q = Quat.identity;
  Vec3 w = Vec3.zero;

  /// Seconds until a queued celebration spin kicks in; negative when none.
  double kickIn = -1;

  _Body(this.char, this.glyph, this.targetX) : x = targetX;
}

/// Interactive 3D numerals.
///
/// Drag to spin any way you like; fling to keep it spinning. Released glyphs
/// snap back to face front with a magnetic wobble, and neighbours follow the
/// touched glyph in a wave. New digits flip up into place, `=` spins the
/// answer, errors shake, and the phone's tilt gives a gentle parallax.
class Numeral3DView extends StatefulWidget {
  final String text;
  final NumeralMaterial material;
  final double opacity;
  final bool hasError;
  final int celebrationId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const Numeral3DView({
    super.key,
    required this.text,
    required this.material,
    this.opacity = 1.0,
    this.hasError = false,
    this.celebrationId = 0,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<Numeral3DView> createState() => _Numeral3DViewState();
}

class _Numeral3DViewState extends State<Numeral3DView>
    with SingleTickerProviderStateMixin {
  static const _radPerPx = 0.012;
  static const _step = 1 / 240;

  final _repaint = _Repaint();
  late final Ticker _ticker = createTicker(_onTick);
  Duration _lastTick = Duration.zero;

  NumeralRenderer? _renderer;
  List<_Body> _bodies = [];
  double _layoutWidth = 1;

  Size _size = Size.zero;
  double _em = 0;
  double _emV = 0;

  int? _lead;
  bool _dragging = false;
  double _shakeT = 1;

  StreamSubscription<AccelerometerEvent>? _sensorSub;
  double _tiltX = 0, _tiltY = 0;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void initState() {
    super.initState();
    _setText(widget.text, animate: false);
    try {
      _sensorSub = accelerometerEventStream().listen((e) {
        if (_reduceMotion) return;
        final tx = (-e.x / 5.5).clamp(-1.0, 1.0);
        final ty = ((e.y - 6.0) / 5.5).clamp(-1.0, 1.0);
        final nx = _tiltX * 0.86 + tx * 0.14;
        final ny = _tiltY * 0.86 + ty * 0.14;
        // Ignore sensor noise so a phone lying still costs no frames.
        if ((nx - _tiltX).abs() + (ny - _tiltY).abs() < 0.003) return;
        _tiltX = nx;
        _tiltY = ny;
        _wake();
      }, onError: (_) {});
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant Numeral3DView old) {
    super.didUpdateWidget(old);
    if (widget.text != old.text) {
      _setText(widget.text, animate: !_reduceMotion);
    }
    if (widget.hasError && !old.hasError) {
      AppHaptics.error();
      AppSounds.error();
      if (!_reduceMotion) _shakeT = 0;
    } else if (widget.celebrationId > old.celebrationId) {
      AppHaptics.success();
      AppSounds.success();
      if (!_reduceMotion) {
        for (var i = 0; i < _bodies.length; i++) {
          _bodies[i].kickIn = i * 0.05;
        }
      }
    }
    _wake();
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  /// Rebuilds the glyph list, keeping the physical state of glyphs that are
  /// unchanged (matched from the right, where typing happens).
  void _setText(String text, {required bool animate}) {
    final layout = NumeralLayout.of(text);
    if (layout == null) return;
    final old = _bodies;
    final next = <_Body>[];
    final n = layout.glyphs.length;
    for (var i = 0; i < n; i++) {
      final g = layout.glyphs[i];
      final oi = old.length - (n - i);
      final prev = oi >= 0 && old[oi].char == g.char ? old[oi] : null;
      if (prev != null) {
        prev.targetX = g.x;
        next.add(prev);
        continue;
      }
      final b = _Body(g.char, g.glyph, g.x);
      if (animate) {
        // Flip up from lying back, rising and growing into place.
        b.s = 0.35;
        b.y = -0.35;
        b.q = Quat.axisAngle(const Vec3(1, 0, 0), -1.1);
      }
      next.add(b);
    }
    _bodies = next;
    _layoutWidth = layout.width;
    _lead = null;
    _dragging = false;
  }

  double _targetEm() {
    if (_size.isEmpty) return 0;
    return math.min(_size.width * 0.92 / _layoutWidth, _size.height * 0.72);
  }

  void _wake() {
    if (!_ticker.isActive) {
      _lastTick = Duration.zero;
      _ticker.start();
    }
    _repaint.ping();
  }

  void _onTick(Duration elapsed) {
    var dt = _lastTick == Duration.zero
        ? 1 / 60
        : (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;
    dt = dt.clamp(0.0, 1 / 20);
    var steps = (dt / _step).ceil();
    final h = dt / math.max(steps, 1);
    var moving = false;
    for (; steps > 0; steps--) {
      moving = _integrate(h);
    }
    _repaint.ping();
    if (!moving && !_dragging) _ticker.stop();
  }

  static double _smooth(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  /// Advances the simulation by [h] seconds. Returns whether anything is
  /// still moving.
  bool _integrate(double h) {
    var moving = false;

    final te = _targetEm();
    if (_em == 0) _em = te;
    _emV += (180 * (te - _em) - 26 * _emV) * h;
    _em += _emV * h;
    if ((te - _em).abs() > 0.2 || _emV.abs() > 0.5) moving = true;

    if (_shakeT < 1) {
      _shakeT = math.min(1, _shakeT + h / 0.36);
      moving = true;
    }

    for (var i = 0; i < _bodies.length; i++) {
      final b = _bodies[i];

      b.vx += (320 * (b.targetX - b.x) - 30 * b.vx) * h;
      b.x += b.vx * h;
      b.vy += (360 * -b.y - 22 * b.vy) * h;
      b.y += b.vy * h;
      b.vs += (420 * (1 - b.s) - 20 * b.vs) * h;
      b.s += b.vs * h;

      if (b.kickIn >= 0) {
        b.kickIn -= h;
        if (b.kickIn < 0) {
          b.w = b.w + const Vec3(0, 15, 0);
          b.vs += 4;
        }
        moving = true;
      }

      if (_dragging && i == _lead) {
        moving = true;
        continue;
      }

      // Followers chase their neighbour towards the touched glyph; everyone
      // else is pulled home by a spring that goes slack while spinning fast.
      Quat target = Quat.identity;
      double k, c;
      final lead = _lead;
      if (lead != null && i != lead) {
        target = _bodies[i < lead ? i + 1 : i - 1].q;
        k = 240;
        c = 20;
      } else {
        final fast = _smooth(4, 9, b.w.length);
        k = 95 + (4 - 95) * fast;
        c = 10 + (1.1 - 10) * fast;
      }
      final e = (target * b.q.conjugate).toRotationVector();
      b.w = b.w + (e * k - b.w * c) * h;
      b.q = (Quat.fromRotationVector(b.w * h) * b.q).normalized();

      if (e.length > 0.002 ||
          b.w.length > 0.02 ||
          (b.x - b.targetX).abs() > 0.002 ||
          b.y.abs() > 0.002 ||
          (b.s - 1).abs() > 0.002 ||
          b.vs.abs() > 0.01) {
        moving = true;
      }
    }

    // Once nobody is spinning, forget the lead so the wave coupling ends.
    if (!_dragging && !moving) _lead = null;
    return moving;
  }

  int _nearest(Offset local) {
    final x = (local.dx - _size.width / 2) / math.max(_em, 1);
    var best = 0;
    for (var i = 1; i < _bodies.length; i++) {
      if ((_bodies[i].x - x).abs() < (_bodies[best].x - x).abs()) best = i;
    }
    return best;
  }

  void _onPanDown(DragDownDetails d) {
    if (_bodies.isEmpty) return;
    final i = _nearest(d.localPosition);
    final b = _bodies[i];
    // Poke: the glyph tips away from the finger like it was pressed.
    final rx = (d.localPosition.dx - _size.width / 2) / _em - b.x;
    final ry = (_size.height / 2 - d.localPosition.dy) / _em;
    b.w = Vec3(-ry * 6, rx * 6, 0);
    _wake();
  }

  void _onPanStart(DragStartDetails d) {
    if (_bodies.isEmpty) return;
    _lead = _nearest(d.localPosition);
    _dragging = true;
    _bodies[_lead!].w = Vec3.zero;
    _wake();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final lead = _lead;
    if (lead == null) return;
    final b = _bodies[lead];
    final delta = Quat.fromRotationVector(
      Vec3(d.delta.dy * _radPerPx, d.delta.dx * _radPerPx, 0),
    );
    b.q = (delta * b.q).normalized();
    _wake();
  }

  void _onPanEnd(DragEndDetails d) {
    final lead = _lead;
    _dragging = false;
    if (lead == null) return;
    final v = d.velocity.pixelsPerSecond;
    _bodies[lead].w = Vec3(v.dy * _radPerPx, v.dx * _radPerPx, 0);
    AppHaptics.lightImpact();
    _wake();
  }

  List<GlyphInstance> _instances() {
    final view = _reduceMotion
        ? Quat.identity
        : Quat.fromRotationVector(Vec3(-_tiltY * 0.22, _tiltX * 0.28, 0));
    final shake = _shakeT < 1
        ? math.sin(_shakeT * math.pi * 6) * 12 * (1 - _shakeT)
        : 0.0;
    return [
      for (final b in _bodies)
        GlyphInstance(
          glyph: b.glyph,
          position: view.rotate(Vec3(
                b.x * _em,
                (b.glyph.pivotY - 0.5 + b.y) * _em,
                0,
              )) +
              Vec3(shake, 0, 0),
          rotation: (view * b.q).normalized(),
          scale: _em * b.s.clamp(0.0, 2.0),
          opacity: widget.opacity,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    _renderer ??= NumeralRenderer(Numeral3DProgram.program!);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      if (size != _size) {
        _size = size;
        if (_em == 0) _em = _targetEm();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _wake();
        });
      }
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        onPanDown: _onPanDown,
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        onPanCancel: () {
          _dragging = false;
          _wake();
        },
        child: CustomPaint(
          size: size,
          painter: _Painter(this, dpr),
        ),
      );
    });
  }
}

class _Painter extends CustomPainter {
  final _Numeral3DViewState state;
  final double dpr;

  _Painter(this.state, this.dpr) : super(repaint: state._repaint);

  @override
  void paint(Canvas canvas, Size size) {
    state._renderer!.paint(
      canvas,
      size,
      state._instances(),
      state.widget.material,
      devicePixelRatio: dpr,
    );
  }

  @override
  bool shouldRepaint(_Painter old) => true;
}

class _Repaint extends ChangeNotifier {
  void ping() => notifyListeners();
}
