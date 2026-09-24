import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'extruded_number.dart';

/// Manages physical motion, springs, tactile animations, and interactive
/// 3D touch rotation for the hero extruded numerals.
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
  }

  @override
  void didUpdateWidget(covariant AnimatedExtrudedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.hasError && !oldWidget.hasError) {
      _shakeController.forward(from: 0.0);
    } else if (widget.text != oldWidget.text) {
      // Digit entered or changed: trigger punchy scale & spring depth
      _scaleController.forward(from: 0.0);
      _depthController.forward(from: 0.5);
    }

    if (widget.isEvaluated && !oldWidget.isEvaluated) {
      // Equals pressed: deeper tactile extrusion spring
      _depthController.forward(from: 0.2);
    }
  }

  @override
  void dispose() {
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

          // Current active 3D touch offset
          final activeOffset = _dragSpringController.isAnimating
              ? _dragSpringAnimation.value
              : _dragOffset;

          // 3D rotation angles (radians)
          final rotateY = activeOffset.dx * 0.42;
          final rotateX = -activeOffset.dy * 0.42;

          // Dynamic extrusion lighting angle reacting to tilt
          final dynamicTilt = widget.tilt +
              Offset(activeOffset.dx * 24.0, activeOffset.dy * 24.0);

          return Transform.translate(
            offset: Offset(shakeOffsetX, 0.0),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0015) // perspective projection
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
