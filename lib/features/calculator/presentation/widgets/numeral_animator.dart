import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'extruded_number.dart';

/// Manages physical motion, springs, tactile animations, interactive 3D touch rotation,
/// and real-time physical device tilt via accelerometer for the hero extruded numerals.
///
/// The number is one solid block on one spring. Dragging turns it after the
/// finger, as if you held a real object; letting go eases it home with a
/// single soft overshoot, and a flick adds a little swing. Past the edge of
/// the turn it pulls like rubber.
class AnimatedExtrudedNumber extends StatefulWidget {
  final String text;
  final bool isEvaluated;
  final bool hasError;
  final ThemeColors colors;
  final Offset tilt;
  final bool isLite;
  final bool isZero;

  /// Increments on each successful `=`, triggering the result pop.
  final int celebrationId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AnimatedExtrudedNumber({
    super.key,
    required this.text,
    this.isEvaluated = false,
    this.hasError = false,
    required this.colors,
    this.tilt = Offset.zero,
    this.isLite = false,
    this.isZero = false,
    this.celebrationId = 0,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<AnimatedExtrudedNumber> createState() => _AnimatedExtrudedNumberState();
}

class _AnimatedExtrudedNumberState extends State<AnimatedExtrudedNumber>
    with TickerProviderStateMixin {
  late final AnimationController _depthController;
  late final AnimationController _shakeController;
  late final AnimationController _scaleController;
  late final AnimationController _idleController;
  late final AnimationController _typeController;
  late final AnimationController _celebrateController;

  /// Leading characters that were already on screen before the last key;
  /// the rest turn into place. Null when nothing is being typed in.
  int? _stableLength;

  late Animation<double> _depthAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

  // The block's spring, stepped by a ticker that sleeps once it settles.
  late final _motionTicker = createTicker(_onMotionTick);
  final _motionFrame = ValueNotifier<int>(0);
  Duration _lastTick = Duration.zero;
  Offset _pos = Offset.zero; // the turn, in swing units
  Offset _vel = Offset.zero;

  bool _dragging = false;
  Offset _rawDrag = Offset.zero; // finger travel, in swing units (110 px)
  Offset _drag = Offset.zero; // the same, rubber-banded past the edge
  bool _pastEdge = false;
  double _totalDragDist = 0.0;

  // Real-time device tilt tracking via accelerometer
  StreamSubscription<AccelerometerEvent>? _sensorSub;
  double _sensorTiltX = 0.0;
  double _sensorTiltY = 0.0;

  @override
  void initState() {
    super.initState();

    // 1. Depth controller: snappy physical spring
    _depthController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _depthAnimation = CurvedAnimation(
      parent: _depthController,
      curve: Curves.easeOutBack,
    );
    _depthController.value = 1.0;

    // 2. Scale controller on digit entry
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
    _scaleController.value = 1.0;

    // 3. Error shake controller
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _shakeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _shakeController, curve: Curves.linear));

    // 4. Subtle idle breathing loop
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // 5. The block's spring for drag and device tilt. Touch the ticker
    // here so it is created while the context is live, not in dispose().
    _motionTicker.stop();

    // 6. Typing: the new digit turns into place; the rest stay still
    _typeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    )..value = 1.0;

    // 7. Answer celebration pop
    _celebrateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    )..value = 1.0;

    // 8. Real-time physical device accelerometer tilt
    _initDeviceMotionSensor();
  }

  void _initDeviceMotionSensor() {
    try {
      // Game rate (~50 Hz) rather than the default 5 Hz: the springs smooth
      // it, and the digits follow the hand without stepping.
      _sensorSub =
          accelerometerEventStream(
            samplingPeriod: SensorInterval.gameInterval,
          ).listen(
            (AccelerometerEvent event) {
              // In portrait orientation:
              // event.x: tilt left/right (typically -9.8 to +9.8)
              // event.y: tilt up/down (typically ~6.0 when naturally held in hand at ~55°)
              final targetX = (-event.x / 5.5).clamp(-1.0, 1.0);
              final targetY = ((event.y - 6.0) / 5.5).clamp(-1.0, 1.0);

              // Exponential moving average to take out hand tremor
              final x = _sensorTiltX * 0.9 + targetX * 0.1;
              final y = _sensorTiltY * 0.9 + targetY * 0.1;
              final moved = (x - _sensorTiltX).abs() + (y - _sensorTiltY).abs();
              _sensorTiltX = x;
              _sensorTiltY = y;

              if (moved > 0.0015 && mounted) _wake();
            },
            onError: (_) {
              // Graceful fallback for devices/platforms without accelerometer
            },
          );
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant AnimatedExtrudedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0.0);
      AppHaptics.error();
      AppSounds.error();
    } else if (widget.celebrationId > oldWidget.celebrationId) {
      _celebrateController.forward(from: 0.0);
      AppHaptics.success();
      AppSounds.success();
      _depthController.forward(from: 0.0);
    } else if (widget.text != oldWidget.text) {
      final typed = widget.text.length >= oldWidget.text.length;
      if (typed && !widget.isLite) {
        // Usually the old text plus one digit. When formatting reshuffles
        // it ("999" to "1,000") only the last digit counts as new.
        _stableLength =
            widget.text.startsWith(oldWidget.text) &&
                widget.text.length > oldWidget.text.length
            ? oldWidget.text.length
            : widget.text.length - 1;
        _typeController.forward(from: 0.0);
      } else {
        _stableLength = null;
      }
      // A small give in the block's depth is all the rest of it does.
      _depthController.forward(from: typed ? 0.75 : 0.8);
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _motionTicker.dispose();
    _motionFrame.dispose();
    _depthController.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    _idleController.dispose();
    _typeController.dispose();
    _celebrateController.dispose();
    super.dispose();
  }

  void _wake() {
    if (_motionTicker.isActive || widget.isLite) return;
    _lastTick = Duration.zero;
    _motionTicker.start();
  }

  void _onMotionTick(Duration elapsed) {
    final dt = _lastTick == Duration.zero
        ? 1.0 / 60.0
        : ((elapsed - _lastTick).inMicroseconds / 1e6).clamp(
            1.0 / 240.0,
            1.0 / 30.0,
          );
    _lastTick = elapsed;

    final sensor = Offset(_sensorTiltX, _sensorTiltY) * 0.45;
    // Held: follows the finger closely with a hint of weight. Let go: comes
    // home with one soft overshoot, not a wobble.
    final target = _dragging ? _drag + sensor : sensor;
    final stiffness = _dragging ? 320.0 : 150.0;
    final damping = _dragging ? 0.9 : 0.62;
    final c = 2.0 * damping * sqrt(stiffness);
    _vel += ((target - _pos) * stiffness - _vel * c) * dt;
    final p = _pos + _vel * dt;
    _pos = Offset(p.dx.clamp(-1.4, 1.4), p.dy.clamp(-1.4, 1.4));
    if (!_dragging &&
        (target - _pos).distance < 0.002 &&
        _vel.distance < 0.02) {
      _pos = sensor;
      _vel = Offset.zero;
      _motionTicker.stop();
    }
    _motionFrame.value++;
  }

  /// Past the edge of the swing the digits still follow, but heavily.
  static double _rubber(double x) {
    final a = x.abs();
    final r = a <= 1.0 ? a : 1.0 + (1.0 - 1.0 / (1.0 + (a - 1.0) * 1.5)) * 0.35;
    return x.isNegative ? -r : r;
  }

  void _onPanStart(DragStartDetails details) {
    _idleController.stop();
    _dragging = true;
    _totalDragDist = 0.0;
    _pastEdge = false;
    _rawDrag = Offset.zero;
    _drag = Offset.zero;
    _wake();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _totalDragDist += details.delta.distance;
    _rawDrag += details.delta / 110.0;
    _drag = Offset(_rubber(_rawDrag.dx), _rubber(_rawDrag.dy));

    // A small click as the number reach the end of their swing.
    final pastEdge = _rawDrag.dx.abs() > 1.0 || _rawDrag.dy.abs() > 1.0;
    if (pastEdge && !_pastEdge) AppHaptics.selectionClick();
    _pastEdge = pastEdge;
    _wake();
  }

  void _onPanEnd(DragEndDetails details) {
    if (_totalDragDist < 7.0) {
      widget.onTap?.call();
      _release(Offset.zero);
      return;
    }
    _release(details.velocity.pixelsPerSecond / 110.0);
  }

  void _onPanCancel() => _release(Offset.zero);

  void _release(Offset velocity) {
    if (!_dragging) return;
    final dragged = _totalDragDist >= 7.0;
    _dragging = false;
    _rawDrag = Offset.zero;
    _drag = Offset.zero;
    // A flick carries the turn on a little before it eases home.
    _vel +=
        Offset(velocity.dx.clamp(-10.0, 10.0), velocity.dy.clamp(-10.0, 10.0)) *
        0.18;
    if (dragged) AppHaptics.lightImpact();
    _wake();
    if (!_idleController.isAnimating) _idleController.repeat(reverse: true);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // A tap that never moves past the drag slop never starts a pan, so
      // the tap has its own recogniser rather than relying on _onPanEnd.
      onTap: widget.onTap,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      onLongPress: widget.onLongPress,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: Listenable.merge([
          _depthController,
          _scaleController,
          _shakeController,
          _idleController,
          _motionFrame,
          _typeController,
          _celebrateController,
        ]),
        builder: (context, _) {
          // Compute shake offset
          double shakeOffsetX = 0.0;
          if (_shakeController.isAnimating) {
            final progress = _shakeAnimation.value;
            final decay = 1.0 - progress;
            shakeOffsetX = sin(progress * pi * 6) * 12.0 * decay;
          }

          // Idle breathing subtle modulation (0.97 to 1.0)
          final idleMod = 0.97 + (_idleController.value * 0.03);
          // An error's line is words, not a result: a shallower, much
          // smaller block, so it cannot be mistaken for a number.
          final currentDepth =
              (_depthAnimation.value * idleMod).clamp(0.0, 1.15) *
              (widget.hasError ? 0.4 : 1.0);

          // One turn for every digit (lite mode stays flat), and the block
          // drifting a touch after the finger.
          final n = max(1, widget.text.characters.length);
          final glyphTilts = widget.isLite ? null : List.filled(n, _pos);
          final follow = widget.isLite
              ? Offset.zero
              : Offset(_pos.dx * 6.0, _pos.dy * 4.0);

          // Celebration: punch in from small, overshoot, settle with a wobble
          final c = _celebrateController.value;
          final celebrateScale = c >= 1.0
              ? 1.0
              : 0.55 + 0.45 * Curves.elasticOut.transform(c);
          final celebrateTilt = c >= 1.0
              ? 0.0
              : sin(c * pi * 3) * (1.0 - c) * 0.06;

          final extruded = ExtrudedNumber(
            text: widget.text,
            depth: currentDepth,
            colors: widget.colors,
            tilt: widget.tilt,
            glyphTilts: glyphTilts,
            isLite: widget.isLite,
            isZero: widget.isZero,
            textAlign: TextAlign.center,
            stableLength: _stableLength,
            enterProgress: _typeController.value,
            maxFontSize: widget.hasError ? 60.0 : 200.0,
          );

          // The 3D turn happens inside the painter, which turns the digits
          // together about the number's centre.
          return Transform.translate(
            offset: Offset(shakeOffsetX, 0.0) + follow,
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(
                celebrateScale * _scaleAnimation.value,
                celebrateScale * _scaleAnimation.value,
                1.0,
              )..rotateZ(celebrateTilt),
              child: extruded,
            ),
          );
        },
      ),
    );
  }
}
