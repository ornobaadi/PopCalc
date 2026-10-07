import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';

/// Scientific keys in a soft tray above the keypad.
///
/// Row one holds the everyday keys (2nd, xʸ, √, brackets, π) and stays
/// visible; row two (trig, logs, !) folds away with the handle so the
/// answer keeps its room. "2nd" flips every key to its inverse.
class ScientificTray extends ConsumerStatefulWidget {
  final ThemeColors colors;

  const ScientificTray({super.key, required this.colors});

  /// Height of one key row, shared with the screen's layout maths.
  static const double rowHeight = 46.0;

  @override
  ConsumerState<ScientificTray> createState() => _ScientificTrayState();
}

class _ScientificTrayState extends ConsumerState<ScientificTray> {
  bool _second = false;

  void _setExpanded(bool value) {
    final settings = ref.read(settingsProvider);
    if (settings.scientificExpanded == value) return;
    AppHaptics.shift(value);
    AppSounds.shift(value);
    ref.read(settingsProvider.notifier).setScientificExpanded(value);
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(calculatorProvider.notifier);
    final expanded = ref.watch(
      settingsProvider.select((s) => s.scientificExpanded),
    );
    final colors = widget.colors;

    void fn(String name) =>
        controller.onOpener(Token(TokenType.function, '$name('));

    // A 2nd-layer key drops back to the primary layer once used.
    VoidCallback once(VoidCallback action) => () {
      action();
      if (_second) setState(() => _second = false);
    };

    _TrayKey key(
      String label,
      VoidCallback onTap, {
      required String semantic,
      String? sup,
      String? index,
      bool accent = false,
      required _Feel feel,
    }) => _TrayKey(
      label: label,
      feel: feel,
      sup: sup,
      index: index,
      semantic: semantic,
      color: accent ? colors.accent : colors.ink,
      pressColor: colors.accent,
      onTap: onTap,
    );

    final secondKey = _TrayKey(
      label: '2nd',
      feel: _second ? _Feel.shiftOff : _Feel.shiftOn,
      semantic: _second ? 'Primary functions' : 'Second functions',
      color: _second ? colors.accent : colors.inkSoft,
      pressColor: colors.accent,
      selected: _second,
      onTap: () => setState(() => _second = !_second),
    );

    final row1 = _second
        ? [
            secondKey,
            key(
              'x',
              once(controller.onSquare),
              sup: '2',
              semantic: 'Square',
              feel: _Feel.power,
              accent: true,
            ),
            key(
              '√',
              once(() => fn('∛')),
              index: '3',
              semantic: 'Cube root',
              feel: _Feel.function,
            ),
            key(
              '(',
              () => controller.onOpener(const Token(TokenType.leftParen, '(')),
              semantic: 'Open bracket',
              feel: _Feel.bracketOpen,
            ),
            key(
              ')',
              controller.onRightParen,
              semantic: 'Close bracket',
              feel: _Feel.bracketClose,
            ),
            key(
              'e',
              once(() => controller.onConstant('e')),
              semantic: 'Euler number',
              feel: _Feel.constant,
            ),
          ]
        : [
            secondKey,
            key(
              'x',
              () => controller.onOperator(TokenType.power, '^'),
              sup: 'y',
              semantic: 'Power',
              feel: _Feel.power,
              accent: true,
            ),
            key(
              '√',
              () => fn('√'),
              semantic: 'Square root',
              feel: _Feel.function,
            ),
            key(
              '(',
              () => controller.onOpener(const Token(TokenType.leftParen, '(')),
              semantic: 'Open bracket',
              feel: _Feel.bracketOpen,
            ),
            key(
              ')',
              controller.onRightParen,
              semantic: 'Close bracket',
              feel: _Feel.bracketClose,
            ),
            key(
              'π',
              () => controller.onConstant('π'),
              semantic: 'Pi',
              feel: _Feel.constant,
            ),
          ];

    final row2 = _second
        ? [
            key(
              'sin',
              once(() => fn('sin⁻¹')),
              sup: '-1',
              semantic: 'Inverse sine',
              feel: _Feel.function,
            ),
            key(
              'cos',
              once(() => fn('cos⁻¹')),
              sup: '-1',
              semantic: 'Inverse cosine',
              feel: _Feel.function,
            ),
            key(
              'tan',
              once(() => fn('tan⁻¹')),
              sup: '-1',
              semantic: 'Inverse tangent',
              feel: _Feel.function,
            ),
            key(
              'e',
              once(controller.onExpE),
              sup: 'x',
              semantic: 'e to the power',
              feel: _Feel.power,
            ),
            key(
              '10',
              once(controller.onExp10),
              sup: 'x',
              semantic: 'Ten to the power',
              feel: _Feel.power,
            ),
            key(
              '!',
              controller.onFactorial,
              semantic: 'Factorial',
              feel: _Feel.power,
            ),
          ]
        : [
            key('sin', () => fn('sin'), semantic: 'Sine', feel: _Feel.function),
            key(
              'cos',
              () => fn('cos'),
              semantic: 'Cosine',
              feel: _Feel.function,
            ),
            key(
              'tan',
              () => fn('tan'),
              semantic: 'Tangent',
              feel: _Feel.function,
            ),
            key(
              'ln',
              () => fn('ln'),
              semantic: 'Natural log',
              feel: _Feel.function,
            ),
            key(
              'log',
              () => fn('log'),
              semantic: 'Log base ten',
              feel: _Feel.function,
            ),
            key(
              '!',
              controller.onFactorial,
              semantic: 'Factorial',
              feel: _Feel.power,
            ),
          ];

    Widget row(List<Widget> keys) => SizedBox(
      height: ScientificTray.rowHeight,
      child: Row(children: [for (final k in keys) Expanded(child: k)]),
    );

    return GestureDetector(
      // Swipe the tray up to open the second row, down to fold it.
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -150) _setExpanded(true);
        if (v > 150) _setExpanded(false);
      },
      child: Container(
        decoration: BoxDecoration(
          color: colors.ink.withValues(alpha: colors.isDark ? 0.07 : 0.04),
          borderRadius: BorderRadius.circular(24.0),
        ),
        padding: const EdgeInsets.fromLTRB(6.0, 0.0, 6.0, 6.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Handle(
              colors: colors,
              expanded: expanded,
              onTap: () => _setExpanded(!expanded),
            ),
            row(row1),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: expanded
                  ? row(row2)
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

/// How a key sounds and feels: openers rise, closers fall, powers step
/// up, constants sparkle, and 2nd climbs or drops with its state.
enum _Feel {
  function(AppHaptics.function, AppSounds.function),
  bracketOpen(AppHaptics.bracketOpen, AppSounds.bracketOpen),
  bracketClose(AppHaptics.bracketClose, AppSounds.bracketClose),
  constant(AppHaptics.constant, AppSounds.constant),
  power(AppHaptics.power, AppSounds.power),
  shiftOn(_shiftOnHaptic, _shiftOnSound),
  shiftOff(_shiftOffHaptic, _shiftOffSound);

  final void Function() haptic;
  final void Function() sound;
  const _Feel(this.haptic, this.sound);
}

void _shiftOnHaptic() => AppHaptics.shift(true);
void _shiftOffHaptic() => AppHaptics.shift(false);
void _shiftOnSound() => AppSounds.shift(true);
void _shiftOffSound() => AppSounds.shift(false);

/// Grab handle along the tray's top edge.
class _Handle extends StatelessWidget {
  final ThemeColors colors;
  final bool expanded;
  final VoidCallback onTap;

  const _Handle({
    required this.colors,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expanded
          ? 'Show fewer scientific keys'
          : 'Show more scientific keys',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: 16.0,
          width: double.infinity,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: expanded ? 28.0 : 40.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: colors.inkSoft.withValues(alpha: expanded ? 0.3 : 0.55),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A compact pill key: springs down on touch, with the same haptic and
/// sound as the keypad's utility keys.
class _TrayKey extends StatefulWidget {
  final String label;

  /// Raised exponent after the label (xʸ, sin⁻¹). The display fonts have
  /// no superscript glyphs, so they are drawn.
  final String? sup;

  /// Raised root index before the label (∛).
  final String? index;
  final String semantic;
  final _Feel feel;
  final Color color;
  final Color pressColor;
  final bool selected;
  final VoidCallback onTap;

  const _TrayKey({
    required this.label,
    this.sup,
    this.index,
    required this.semantic,
    required this.feel,
    required this.color,
    required this.pressColor,
    this.selected = false,
    required this.onTap,
  });

  @override
  State<_TrayKey> createState() => _TrayKeyState();
}

class _TrayKeyState extends State<_TrayKey> {
  bool _pressed = false;

  void _down(TapDownDetails details) {
    widget.feel.haptic();
    final width = MediaQuery.sizeOf(context).width;
    final pan = width > 0
        ? (details.globalPosition.dx / width - 0.5) * 0.6
        : 0.0;
    AppSounds.panned(pan, widget.feel.sound);
    setState(() => _pressed = true);
  }

  @override
  Widget build(BuildContext context) {
    // Bebas Neue is caps-only; "E" would read as an exponent, so the
    // constant keeps its lowercase in Antonio.
    final isE = widget.label == 'e';
    TextStyle style(double size) => TextStyle(
      fontFamily: isE ? 'Antonio' : 'BebasNeue',
      fontSize: isE ? size * 0.85 : size,
      color: widget.color,
      letterSpacing: 0.6,
      height: 1.0,
    );

    final highlight = _pressed || widget.selected;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semantic,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: (_) {
          setState(() => _pressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: Duration(milliseconds: _pressed ? 70 : 140),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 3.0),
            decoration: BoxDecoration(
              color: highlight
                  ? widget.pressColor.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14.0),
            ),
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.index != null)
                    Transform.translate(
                      offset: const Offset(2.0, -5.0),
                      child: Text(widget.index!, style: style(13.0)),
                    ),
                  Text(widget.label, style: style(22.0)),
                  if (widget.sup != null)
                    Transform.translate(
                      offset: const Offset(1.0, -5.0),
                      child: Text(widget.sup!, style: style(13.0)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
