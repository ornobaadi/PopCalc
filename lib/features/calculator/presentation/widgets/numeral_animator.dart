import 'dart:math';
import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'extruded_number.dart';

/// Manages physical motion, springs, and tactile animations for the hero 3D numeral.
class AnimatedExtrudedNumber extends StatefulWidget {
  final String text;
  final bool isEvaluated;
  final bool hasError;
  final ThemeColors colors;
  final Offset tilt;
  final bool isLite;

  const AnimatedExtrudedNumber({
    super.key,
    required this.text,
    this.isEvaluated = false,
    this.hasError = false,
    required this.colors,
    this.tilt = Offset.zero,
    this.isLite = false,
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

  late Animation<double> _depthAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shakeAnimation;

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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _depthController,
        _scaleController,
        _shakeController,
        _idleController,
      ]),
      builder: (context, _) {
        // Compute shake offset
        double shakeOffsetX = 0.0;
        if (_shakeController.isAnimating) {
          // 3 oscillation cycles with decaying amplitude
          final progress = _shakeAnimation.value;
          final decay = 1.0 - progress;
          shakeOffsetX = sin(progress * pi * 6) * 12.0 * decay;
        }

        // Idle breathing subtle modulation (0.97 to 1.0)
        final idleMod = 0.97 + (_idleController.value * 0.03);
        final currentDepth = (_depthAnimation.value * idleMod).clamp(0.0, 1.15);

        return Transform.translate(
          offset: Offset(shakeOffsetX, 0.0),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: ExtrudedNumber(
              text: widget.text,
              depth: currentDepth,
              colors: widget.colors,
              tilt: widget.tilt,
              isLite: widget.isLite,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
