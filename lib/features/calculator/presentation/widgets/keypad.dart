import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'backspace_icon.dart';
import 'key_button.dart';

class Keypad extends ConsumerWidget {
  final ThemeColors colors;
  /// When true, the next digit press replaces the current result.
  final bool highlightMode;
  final VoidCallback? onHighlightConsumed;

  const Keypad({
    super.key,
    required this.colors,
    this.highlightMode = false,
    this.onHighlightConsumed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(calculatorProvider.notifier);

    void pressDigit(String digit) {
      if (highlightMode) {
        onHighlightConsumed?.call();
      }
      controller.onDigit(digit);
    }

    void pressDecimal() {
      if (highlightMode) {
        onHighlightConsumed?.call();
      }
      controller.onDecimal();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Row 1: C, %, Backspace, ÷
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeyButton(
                  label: 'C',
                  color: colors.inkSoft,
                  fontSize: 42.0,
                  semanticLabel: 'Clear',
                  onTap: () => controller.onClear(),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '%',
                  color: colors.inkSoft,
                  fontSize: 40.0,
                  semanticLabel: 'Percent',
                  onTap: () => controller.onPercent(),
                ),
              ),
              Expanded(
                child: KeyButton(
                  color: colors.inkSoft,
                  semanticLabel: 'Backspace',
                  onTap: () => controller.onBackspace(),
                  child: BackspaceIcon(color: colors.inkSoft, size: 28),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '÷',
                  color: colors.accent,
                  fontSize: 46.0,
                  semanticLabel: 'Divide',
                  onTap: () => controller.onOperator(TokenType.divide, '÷'),
                ),
              ),
            ],
          ),
        ),

        // Row 2: 7, 8, 9, ×
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeyButton(
                  label: '7',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('7'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '8',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('8'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '9',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('9'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '×',
                  color: colors.accent,
                  fontSize: 42.0,
                  semanticLabel: 'Multiply',
                  onTap: () => controller.onOperator(TokenType.multiply, '×'),
                ),
              ),
            ],
          ),
        ),

        // Row 3: 4, 5, 6, −
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeyButton(
                  label: '4',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('4'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '5',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('5'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '6',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('6'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '−',
                  color: colors.accent,
                  fontSize: 46.0,
                  semanticLabel: 'Minus',
                  onTap: () => controller.onOperator(TokenType.minus, '-'),
                ),
              ),
            ],
          ),
        ),

        // Row 4: 1, 2, 3, +
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeyButton(
                  label: '1',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('1'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '2',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('2'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '3',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('3'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '+',
                  color: colors.accent,
                  fontSize: 46.0,
                  semanticLabel: 'Plus',
                  onTap: () => controller.onOperator(TokenType.plus, '+'),
                ),
              ),
            ],
          ),
        ),

        // Row 5: 0, ., +/-, =
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: KeyButton(
                  label: '0',
                  color: colors.ink,
                  fontSize: 46.0,
                  onTap: () => pressDigit('0'),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '.',
                  color: colors.ink,
                  fontSize: 46.0,
                  semanticLabel: 'Decimal point',
                  onTap: () => pressDecimal(),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '+/-',
                  color: colors.inkSoft,
                  fontSize: 32.0,
                  semanticLabel: 'Toggle sign',
                  onTap: () => controller.onToggleSign(),
                ),
              ),
              Expanded(
                child: KeyButton(
                  label: '=',
                  color: colors.accent,
                  fontSize: 48.0,
                  semanticLabel: 'Equals',
                  onTap: () => controller.onEquals(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
