import 'package:flutter/material.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// Put above a group of [KeyButton]s to draw them as keycaps in [colors]
/// (the Mechanical material). Without it keys are bare legends.
class KeycapScope extends InheritedWidget {
  final ThemeColors colors;

  const KeycapScope({super.key, required this.colors, required super.child});

  /// Wraps [child] only when [colors] asks for keycaps.
  static Widget wrap({required ThemeColors colors, required Widget child}) =>
      colors.finish == SkinFinish.keycap
      ? KeycapScope(colors: colors, child: child)
      : child;

  static ThemeColors? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<KeycapScope>()?.colors;

  @override
  bool updateShouldNotify(KeycapScope oldWidget) => colors != oldWidget.colors;
}

class KeyButton extends StatefulWidget {
  final Widget? child;
  final String? label;
  final Color color;
  final VoidCallback onTap;
  final String? semanticLabel;
  final double fontSize;
  final FontWeight fontWeight;
  /// Haptic fired on touch-down. Defaults to a light digit tick.
  final VoidCallback haptic;
  /// Sound fired on touch-down, in sync with the haptic.
  final VoidCallback? sound;

  const KeyButton({
    super.key,
    this.child,
    this.label,
    required this.color,
    required this.onTap,
    this.semanticLabel,
    this.fontSize = 42.0,
    this.fontWeight = FontWeight.w400,
    this.haptic = AppHaptics.digit,
    this.sound,
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

  void _onTapDown(TapDownDetails details) {
    widget.haptic();
    final sound = widget.sound;
    if (sound != null) {
      // Pan the sound toward the side of the screen that was tapped.
      final width = MediaQuery.sizeOf(context).width;
      final pan = width > 0 ? (details.globalPosition.dx / width - 0.5) * 0.6 : 0.0;
      AppSounds.panned(pan, sound);
    }
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

  /// A keycap: a dark skirt with a lighter top face that sinks when pressed.
  Widget _keycap(ThemeColors colors, Widget legend) {
    final top = Color.lerp(colors.bg, colors.ink, 0.16)!;
    final skirt = Color.lerp(colors.bg, Colors.black, 0.5)!;
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: skirt,
          borderRadius: BorderRadius.circular(13.0),
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 60),
          padding: EdgeInsets.fromLTRB(
            3.0,
            _isPressed ? 5.0 : 2.0,
            3.0,
            _isPressed ? 3.0 : 7.0,
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10.0),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color.lerp(top, Colors.white, 0.1)!, top],
              ),
            ),
            child: Center(child: legend),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keycap = KeycapScope.maybeOf(context);
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
            if (keycap != null) return _keycap(keycap, child!);
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
