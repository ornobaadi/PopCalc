import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'extruded_number.dart';

/// Manages physical motion, springs, tactile animations, interactive 3D touch rotation,
/// and real-time physical device tilt via accelerometer for the hero extruded numerals.
class AnimatedExtrudedNumber extends StatefulWidget {
  final String text;
  final bool isEvaluated;
  final bool hasError;
  final ThemeColors colors;
  final Offset tilt;
  final bool isLite;
  final bool isZero;
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
  late final AnimationController _dragSpringController;

  late Animation<double> _depthAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;
  late Animation<Offset> _dragSpringAnimation;

  Offset _dragOffset = Offset.zero;
  Offset _accumulatedDelta = Offset.zero;
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
    _shakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.linear),
    );

    // 4. Subtle idle breathing loop
    _idleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // 5. Interactive 3D drag release spring-back controller
    _dragSpringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _dragSpringAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _dragSpringController,
        curve: Curves.elasticOut,
      ),
    );

    // 6. Real-time physical device accelerometer tilt
    _initDeviceMotionSensor();
  }

  void _initDeviceMotionSensor() {
    try {
      _sensorSub = accelerometerEventStream().listen(
        (AccelerometerEvent event) {
          // In portrait orientation:
          // event.x: tilt left/right (typically -9.8 to +9.8)
          // event.y: tilt up/down (typically ~6.0 when naturally held in hand at ~55°)
          final targetX = (-event.x / 5.5).clamp(-1.0, 1.0);
          final targetY = ((event.y - 6.0) / 5.5).clamp(-1.0, 1.0);

          // Exponential moving average filter for buttery-smooth, jitter-free motion
          _sensorTiltX = _sensorTiltX * 0.86 + targetX * 0.14;
          _sensorTiltY = _sensorTiltY * 0.86 + targetY * 0.14;

          if (mounted) setState(() {});
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
    } else if (widget.text != oldWidget.text) {
      _scaleController.forward(from: 0.0);
      _depthController.forward(from: 0.5);
    }

    if (widget.isEvaluated && !oldWidget.isEvaluated) {
      _depthController.forward(from: 0.2);
    }
  }

  @override
  void dispose() {
    _sensorSub?.cancel();
    _depthController.dispose();
    _shakeController.dispose();
    _scaleController.dispose();
    _idleController.dispose();
    _dragSpringController.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _idleController.stop();
    _dragSpringController.stop();
    _totalDragDist = 0.0;
    _accumulatedDelta = _dragOffset * 100.0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _totalDragDist += details.delta.distance;
    _accumulatedDelta += details.delta;

    final normX = (_accumulatedDelta.dx / 110.0).clamp(-1.0, 1.0);
    final normY = (_accumulatedDelta.dy / 110.0).clamp(-1.0, 1.0);

    setState(() {
      _dragOffset = Offset(normX, normY);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_totalDragDist < 7.0) {
      widget.onTap?.call();
      _snapBack();
      return;
    }
    _snapBack();
  }

  void _onPanCancel() {
    _snapBack();
  }

  void _snapBack() {
    HapticFeedback.lightImpact();
    _dragSpringAnimation = Tween<Offset>(
      begin: _dragOffset,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _dragSpringController,
        curve: Curves.elasticOut,
      ),
    );
    _dragSpringController.forward(from: 0.0).then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = Offset.zero;
          _accumulatedDelta = Offset.zero;
        });
        _idleController.repeat(reverse: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
          _dragSpringController,
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
          final currentDepth = (_depthAnimation.value * idleMod).clamp(0.0, 1.15);

          // Current active touch offset
          final activeTouchOffset = _dragSpringController.isAnimating
              ? _dragSpringAnimation.value
              : _dragOffset;

          // Seamless fusion of touch dragging + physical device orientation movement
          final double combinedX = (activeTouchOffset.dx + _sensorTiltX * 0.45).clamp(-1.2, 1.2);
          final double combinedY = (activeTouchOffset.dy + _sensorTiltY * 0.45).clamp(-1.2, 1.2);

          // 3D perspective tilt angles for thick physical block motion
          final rotateY = combinedX * 0.28;
          final rotateX = -combinedY * 0.28;

          // Dynamic extrusion lighting angle reacting to device orientation and touch
          final dynamicTilt = widget.tilt +
              Offset(combinedX * 12.0, combinedY * 12.0);

          return Transform.translate(
            offset: Offset(shakeOffsetX, 0.0),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0010) // Natural camera perspective
                  ..rotateX(rotateX)
                  ..rotateY(rotateY),
                child: ExtrudedNumber(
                  text: widget.text,
                  depth: currentDepth,
                  colors: widget.colors,
                  tilt: dynamicTilt,
                  isLite: widget.isLite,
                  isZero: widget.isZero,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
