import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// "64% OFF": how much the everything bundle saves.
class SavingChip extends StatelessWidget {
  final int percent;
  final Color color;
  final Color onColor;
  final double fontSize;

  const SavingChip({
    super.key,
    required this.percent,
    required this.color,
    required this.onColor,
    this.fontSize = 14.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.6,
        vertical: fontSize * 0.15,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(fontSize),
      ),
      child: Text(
        '$percent% OFF',
        style: TextStyle(
          fontFamily: 'BebasNeue',
          fontSize: fontSize,
          letterSpacing: fontSize * 0.08,
          height: 1.2,
          color: onColor,
        ),
      ),
    );
  }
}

/// Gives a little under the finger, like a key.
class Pressable extends StatefulWidget {
  final VoidCallback? onTap;
  final Widget child;

  const Pressable({super.key, required this.onTap, required this.child});

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (widget.onTap != null && _down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      child: AnimatedScale(
        scale: _down ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// The wide button at the foot of a product sheet. Filled for the main
/// action, outlined otherwise; faded when [onTap] is null.
class StoreButton extends StatelessWidget {
  final ThemeColors colors;
  final VoidCallback? onTap;
  final bool filled;
  final Widget child;

  const StoreButton({
    super.key,
    required this.colors,
    required this.onTap,
    required this.child,
    this.filled = true,
  });

  /// The lettering for a button, in the right colour for its kind.
  static TextStyle textStyle(ThemeColors colors, {bool filled = true}) =>
      TextStyle(
        fontFamily: 'BebasNeue',
        fontSize: 19.0,
        letterSpacing: 1.8,
        height: 1.2,
        color: filled ? colors.bg : colors.ink,
      );

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 54.0,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 18.0),
        decoration: BoxDecoration(
          color: filled
              ? colors.accent.withValues(alpha: onTap == null ? 0.35 : 1.0)
              : colors.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(27.0),
        ),
        // Prices come from Play in any currency and length, so the
        // lettering shrinks to fit.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: DefaultTextStyle.merge(
            style: textStyle(colors, filled: filled),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The rounded card every product sheet sits in: a drag handle, the
/// [body] (which scrolls if the phone is too short for it) and the
/// [footer] with the buttons, which always stays in view.
class StoreSheet extends StatelessWidget {
  final ThemeColors colors;
  final List<Widget> body;
  final List<Widget> footer;

  const StoreSheet({
    super.key,
    required this.colors,
    required this.body,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.sizeOf(context).height;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(10.0, 0.0, 10.0, 10.0),
        constraints: BoxConstraints(maxHeight: screen * 0.9),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: BorderRadius.circular(32.0),
          border: Border.all(
            color: colors.ink.withValues(alpha: 0.12),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36.0,
                height: 4.0,
                margin: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                decoration: BoxDecoration(
                  color: colors.inkSoft.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24.0, 16.0, 24.0, 18.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: body,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: footer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
