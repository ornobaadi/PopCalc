import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';

/// Scientific keys in a soft tray above the keypad.
///
/// Row one holds the everyday keys (swap, xʸ, √, brackets, π) and stays
/// visible; row two (trig, logs, !) folds away with the handle so the
/// answer keeps its room. The swap key (⇄) flips every key to its inverse.
///
/// With [grid] (the sideways layout) there is room for everything, so both
/// layers are laid out at once in a 4 × 5 block and nothing needs swapping.
class ScientificTray extends ConsumerStatefulWidget {
  final ThemeColors colors;
  final bool grid;

  const ScientificTray({super.key, required this.colors, this.grid = false});

  /// Height of one key row, shared with the screen's layout maths.
  static const double rowHeight = 46.0;

  @override
  ConsumerState<ScientificTray> createState() => _ScientificTrayState();
}

class _ScientificTrayState extends ConsumerState<ScientificTray> {
  bool _second = false;

  /// Sideways layout: every function on show, primary and inverse together,
  /// plus the angle unit, so there is no second layer to swap to.
  Widget _grid(
    _KeyBuilder key,
    void Function(String name) fn,
    CalculatorController controller,
  ) {
    final colors = widget.colors;
    final unit = ref.watch(settingsProvider.select((s) => s.angleUnit));
    final isDeg = unit == AngleUnit.degrees;

    final rows = <List<Widget>>[
      [
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
        key(
          'e',
          () => controller.onConstant('e'),
          semantic: 'Euler number',
          feel: _Feel.constant,
        ),
      ],
      [
        key(
          'x',
          controller.onSquare,
          sup: '2',
          semantic: 'Square',
          feel: _Feel.power,
          accent: true,
        ),
        key(
          'x',
          () => controller.onOperator(TokenType.power, '^'),
          sup: 'y',
          semantic: 'Power',
          feel: _Feel.power,
          accent: true,
        ),
        key('√', () => fn('√'), semantic: 'Square root', feel: _Feel.root),
        key(
          '√',
          () => fn('∛'),
          index: '3',
          semantic: 'Cube root',
          feel: _Feel.root,
        ),
      ],
      [
        key('sin', () => fn('sin'), semantic: 'Sine', feel: _Feel.trig),
        key('cos', () => fn('cos'), semantic: 'Cosine', feel: _Feel.trig),
        key('tan', () => fn('tan'), semantic: 'Tangent', feel: _Feel.trig),
        _TrayKey(
          label: isDeg ? 'DEG' : 'RAD',
          feel: isDeg ? _Feel.shiftOn : _Feel.shiftOff,
          semantic: isDeg
              ? 'Angles in degrees. Tap for radians'
              : 'Angles in radians. Tap for degrees',
          color: colors.accent,
          pressColor: colors.accent,
          outlined: true,
          onTap: () => ref
              .read(settingsProvider.notifier)
              .setAngleUnit(isDeg ? AngleUnit.radians : AngleUnit.degrees),
        ),
      ],
      [
        key(
          'sin',
          () => fn('sin⁻¹'),
          sup: '-1',
          semantic: 'Inverse sine',
          feel: _Feel.trig,
        ),
        key(
          'cos',
          () => fn('cos⁻¹'),
          sup: '-1',
          semantic: 'Inverse cosine',
          feel: _Feel.trig,
        ),
        key(
          'tan',
          () => fn('tan⁻¹'),
          sup: '-1',
          semantic: 'Inverse tangent',
          feel: _Feel.trig,
        ),
        key(
          '!',
          controller.onFactorial,
          semantic: 'Factorial',
          feel: _Feel.factorial,
        ),
      ],
      [
        key('ln', () => fn('ln'), semantic: 'Natural log', feel: _Feel.log),
        key('log', () => fn('log'), semantic: 'Log base ten', feel: _Feel.log),
        key(
          'e',
          controller.onExpE,
          sup: 'x',
          semantic: 'e to the power',
          feel: _Feel.power,
        ),
        key(
          '10',
          controller.onExp10,
          sup: 'x',
          semantic: 'Ten to the power',
          feel: _Feel.power,
        ),
      ],
    ];

    return Container(
      decoration: BoxDecoration(
        color: colors.ink.withValues(alpha: colors.isDark ? 0.07 : 0.04),
        borderRadius: BorderRadius.circular(24.0),
      ),
      padding: const EdgeInsets.all(6.0),
      child: Column(
        children: [
          for (final keys in rows)
            Expanded(
              child: Row(children: [for (final k in keys) Expanded(child: k)]),
            ),
        ],
      ),
    );
  }

  void _setExpanded(bool value) {
    final settings = ref.read(settingsProvider);
    if (settings.scientificExpanded == value) return;
    AppHaptics.shift(value);
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

    if (widget.grid) return _grid(key, fn, controller);

    final secondKey = _TrayKey(
      label: '',
      icon: Icons.swap_horiz_rounded,
      feel: _second ? _Feel.shiftOff : _Feel.shiftOn,
      semantic: _second ? 'Primary functions' : 'More functions',
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
              feel: _Feel.root,
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
            key('√', () => fn('√'), semantic: 'Square root', feel: _Feel.root),
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
              feel: _Feel.trig,
            ),
            key(
              'cos',
              once(() => fn('cos⁻¹')),
              sup: '-1',
              semantic: 'Inverse cosine',
              feel: _Feel.trig,
            ),
            key(
              'tan',
              once(() => fn('tan⁻¹')),
              sup: '-1',
              semantic: 'Inverse tangent',
              feel: _Feel.trig,
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
              feel: _Feel.factorial,
            ),
          ]
        : [
            key('sin', () => fn('sin'), semantic: 'Sine', feel: _Feel.trig),
            key('cos', () => fn('cos'), semantic: 'Cosine', feel: _Feel.trig),
            key('tan', () => fn('tan'), semantic: 'Tangent', feel: _Feel.trig),
            key('ln', () => fn('ln'), semantic: 'Natural log', feel: _Feel.log),
            key(
              'log',
              () => fn('log'),
              semantic: 'Log base ten',
              feel: _Feel.log,
            ),
            key(
              '!',
              controller.onFactorial,
              semantic: 'Factorial',
              feel: _Feel.factorial,
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

/// Signature of the tray's key factory, shared by both layouts.
typedef _KeyBuilder = _TrayKey Function(
  String label,
  VoidCallback onTap, {
  required String semantic,
  String? sup,
  String? index,
  bool accent,
  required _Feel feel,
});

/// How a key sounds and feels. Each kind of key has its own short figure
/// (trig waves, logs settle, powers climb, roots step down, brackets open
/// up and close down, constants sparkle, ! knocks), with a matching haptic.
enum _Feel {
  trig(AppHaptics.trig, Sfx.trig),
  log(AppHaptics.log, Sfx.log),
  power(AppHaptics.power, Sfx.power),
  root(AppHaptics.root, Sfx.root),
  bracketOpen(AppHaptics.bracketOpen, Sfx.bracketOpen),
  bracketClose(AppHaptics.bracketClose, Sfx.bracketClose),
  constant(AppHaptics.constant, Sfx.constant),
  factorial(AppHaptics.factorial, Sfx.factorial),
  shiftOn(_shiftOnHaptic, Sfx.shiftOn),
  shiftOff(_shiftOffHaptic, Sfx.shiftOff);

  final void Function() haptic;
  final Sfx sound;
  const _Feel(this.haptic, this.sound);
}

void _shiftOnHaptic() => AppHaptics.shift(true);
void _shiftOffHaptic() => AppHaptics.shift(false);

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

  /// Drawn instead of [label]; turns half a circle while [selected].
  final IconData? icon;

  /// A thin border, for a key that shows a setting (DEG / RAD).
  final bool outlined;
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
    this.icon,
    this.outlined = false,
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
    AppSounds.panned(pan, () => AppSounds.play(widget.feel.sound));
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
              border: widget.outlined
                  ? Border.all(
                      color: widget.color.withValues(alpha: 0.5),
                      width: 1.5,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: widget.icon != null
                ? AnimatedRotation(
                    turns: widget.selected ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: Icon(widget.icon, color: widget.color, size: 26.0),
                  )
                : FittedBox(
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
