import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';

import 'key_button.dart';

/// Two compact rows of scientific keys shown above the keypad in
/// Advanced mode. "2nd" flips them to inverse functions.
class ScientificStrip extends ConsumerStatefulWidget {
  final ThemeColors colors;

  const ScientificStrip({super.key, required this.colors});

  @override
  ConsumerState<ScientificStrip> createState() => _ScientificStripState();
}

class _ScientificStripState extends ConsumerState<ScientificStrip> {
  bool _second = false;

  @override
  Widget build(BuildContext context) {
    final controller = ref.read(calculatorProvider.notifier);
    final colors = widget.colors;

    /// [sup] draws a raised exponent, since the display fonts have no
    /// superscript glyphs (xʸ, sin⁻¹).
    Widget key(
      String label,
      VoidCallback onTap, {
      String? sup,
      String? index,
      String? semantic,
      Color? color,
    }) {
      final keyColor = color ?? colors.inkSoft;
      // Bebas Neue has no lowercase, and "E" would read as an exponent.
      final custom = sup != null || index != null || label == 'e';
      return Expanded(
        child: KeyButton(
          label: custom ? null : label,
          color: keyColor,
          fontSize: 24.0,
          semanticLabel: semantic ?? label,
          haptic: AppHaptics.utility,
          sound: AppSounds.utility,
          onTap: onTap,
          child: !custom
              ? null
              : _Superscript(
                  base: label,
                  sup: sup,
                  index: index,
                  color: keyColor,
                ),
        ),
      );
    }

    void fn(String name) =>
        controller.onOpener(Token(TokenType.function, '$name('));

    // After a 2nd-row key fires, drop back to the primary row like most
    // scientific calculators do.
    VoidCallback once(VoidCallback action) => () {
      action();
      if (_second) setState(() => _second = false);
    };

    final row1 = _second
        ? [
            key(
              'sin',
              once(() => fn('sin⁻¹')),
              sup: '-1',
              semantic: 'Inverse sine',
            ),
            key(
              'cos',
              once(() => fn('cos⁻¹')),
              sup: '-1',
              semantic: 'Inverse cosine',
            ),
            key(
              'tan',
              once(() => fn('tan⁻¹')),
              sup: '-1',
              semantic: 'Inverse tangent',
            ),
          ]
        : [
            key('sin', () => fn('sin'), semantic: 'Sine'),
            key('cos', () => fn('cos'), semantic: 'Cosine'),
            key('tan', () => fn('tan'), semantic: 'Tangent'),
          ];

    final row2 = _second
        ? [
            key('x', once(controller.onSquare), sup: '2', semantic: 'Square'),
            key('√', once(() => fn('∛')), index: '3', semantic: 'Cube root'),
            key(
              'e',
              once(controller.onExpE),
              sup: 'x',
              semantic: 'e to the power',
            ),
            key(
              '10',
              once(controller.onExp10),
              sup: 'x',
              semantic: 'Ten to the power',
            ),
            key(
              'e',
              once(() => controller.onConstant('e')),
              semantic: 'Euler number',
            ),
          ]
        : [
            key(
              'x',
              () => controller.onOperator(TokenType.power, '^'),
              sup: 'y',
              semantic: 'Power',
              color: colors.accent,
            ),
            key('√', () => fn('√'), semantic: 'Square root'),
            key('ln', () => fn('ln'), semantic: 'Natural log'),
            key('log', () => fn('log'), semantic: 'Log base ten'),
            key('π', () => controller.onConstant('π'), semantic: 'Pi'),
          ];

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeyButton(
                  label: '2nd',
                  color: _second ? colors.accent : colors.inkSoft,
                  fontSize: 24.0,
                  semanticLabel: _second
                      ? 'Primary functions'
                      : 'Second functions',
                  haptic: AppHaptics.selectionClick,
                  onTap: () => setState(() => _second = !_second),
                ),
              ),
              ...row1,
              key(
                '(',
                () =>
                    controller.onOpener(const Token(TokenType.leftParen, '(')),
                semantic: 'Open bracket',
              ),
              key(')', controller.onRightParen, semantic: 'Close bracket'),
            ],
          ),
        ),
        Expanded(
          child: Row(
            children: [
              ...row2,
              key('!', controller.onFactorial, semantic: 'Factorial'),
            ],
          ),
        ),
      ],
    );
  }
}

/// A key label with a raised exponent after it ([sup], as in xʸ) or a
/// raised root index before it ([index], as in ∛).
class _Superscript extends StatelessWidget {
  final String base;
  final String? sup;
  final String? index;
  final Color color;

  const _Superscript({
    required this.base,
    this.sup,
    this.index,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle style(double size) => TextStyle(
      fontFamily: base == 'e' ? 'Antonio' : 'BebasNeue',
      fontSize: size,
      color: color,
      letterSpacing: 0.5,
      height: 1.0,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (index != null)
            Transform.translate(
              offset: const Offset(2.0, -6.0),
              child: Text(index!, style: style(15.0)),
            ),
          Text(base, style: style(24.0)),
          if (sup != null)
            Transform.translate(
              offset: const Offset(1.0, -6.0),
              child: Text(sup!, style: style(15.0)),
            ),
        ],
      ),
    );
  }
}
