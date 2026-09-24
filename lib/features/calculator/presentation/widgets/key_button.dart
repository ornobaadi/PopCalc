import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyButton extends StatefulWidget {
  final Widget? child;
  final String? label;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double fontSize;
  final FontWeight fontWeight;

  const KeyButton({
    super.key,
    this.child,
    this.label,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.fontSize = 42.0,
    this.fontWeight = FontWeight.w400,
  }) : assert(child != null || label != null);

  @override
  State<KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<KeyButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 70),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    HapticFeedback.selectionClick();
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    setState(() => _isPressed = false);
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isPressed
                      ? widget.color.withValues(alpha: 0.16)
                      : Colors.transparent,
                ),
                child: child,
              ),
            );
          },
          child: widget.child ??
              Text(
                widget.label!,
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: widget.fontSize,
                  fontWeight: widget.fontWeight,
                  color: widget.color,
                  letterSpacing: 0.5,
                  height: 1.0,
                ),
              ),
        ),
      ),
    );
  }
}
