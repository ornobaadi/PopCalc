import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';

void main() {
  late CalculatorController controller;

  setUp(() {
    controller = CalculatorController();
  });

  test('Initial state is empty with 0 result', () {
    expect(controller.state.resultText, '0');
    expect(controller.state.expressionText, '');
    expect(controller.state.previewText, isNull);
  });

  test('Typing digits updates current number and formatted result', () {
    controller.onDigit('1');
    controller.onDigit('0');
    controller.onDigit('2');
    controller.onDigit('4');

    expect(controller.state.resultText, '1,024');
    expect(controller.state.previewText, isNull);
  });

  test('Live preview updates when operator and second number are entered', () {
    controller.onDigit('1');
    controller.onDigit('0');
    controller.onDigit('2');
    controller.onDigit('4');
    controller.onOperator(TokenType.plus, '+');
    controller.onDigit('5');
    controller.onPercent();

    // Live preview should calculate 1024 + 5% = 1075.2
    expect(controller.state.previewText, '1,075.2');

    // On equals, the main result becomes 1,075.2
    controller.onEquals();
    expect(controller.state.resultText, '1,075.2');
    expect(controller.state.justEvaluated, true);
    expect(controller.state.previewText, isNull);
  });

  test('Consecutive operation: after equals, typing operator continues calculation', () {
    controller.onDigit('1');
    controller.onDigit('0');
    controller.onOperator(TokenType.plus, '+');
    controller.onDigit('5');
    controller.onEquals();
    expect(controller.state.resultText, '15');

    // Now type + 5
    controller.onOperator(TokenType.plus, '+');
    controller.onDigit('5');
    controller.onEquals();
    expect(controller.state.resultText, '20');
  });

  test('Divide by zero displays error message', () {
    controller.onDigit('9');
    controller.onOperator(TokenType.divide, '÷');
    controller.onDigit('0');
    controller.onEquals();

    expect(controller.state.resultText, "Can't divide by zero");
    expect(controller.state.error, isNotNull);
  });

  test('Percent displays on the big hero display', () {
    controller.onDigit('8');
    controller.onDigit('8');
    controller.onOperator(TokenType.multiply, '×');
    controller.onDigit('9');
    controller.onPercent();

    // Result text for the hero display should show 9%
    expect(controller.state.resultText, '9%');
    expect(controller.state.expression.toDisplayString(), '88 × 9%');
  });

  test('Token editing: tapping a number highlights it and typing a new digit replaces it', () {
    // Enter 88 × 9
    controller.onDigit('8');
    controller.onDigit('8');
    controller.onOperator(TokenType.multiply, '×');
    controller.onDigit('9');

    expect(controller.state.expression.toDisplayString(), '88 × 9');

    // Tap the first token (88)
    controller.selectToken(0);
    expect(controller.state.editingTokenIndex, 0);
    expect(controller.state.resultText, '88');

    // Type '5': should replace 88 with 5
    controller.onDigit('5');
    expect(controller.state.resultText, '5');
    expect(controller.state.expression.toDisplayString(), '5 × 9');

    // Type '6': should append to make 56
    controller.onDigit('6');
    expect(controller.state.resultText, '56');
    expect(controller.state.expression.toDisplayString(), '56 × 9');
  });

  test('Token editing: tapping an operator allows replacing it', () {
    // Enter 50 + 10
    controller.onDigit('5');
    controller.onDigit('0');
    controller.onOperator(TokenType.plus, '+');
    controller.onDigit('1');
    controller.onDigit('0');

    // Select operator '+' at index 1
    controller.selectToken(1);
    expect(controller.state.editingTokenIndex, 1);
    expect(controller.state.resultText, '+');

    // Replace '+' with '×'
    controller.onOperator(TokenType.multiply, '×');
    expect(controller.state.resultText, '×');
    expect(controller.state.expression.toDisplayString(), '50 × 10');

    // On equals: 50 × 10 = 500
    controller.onEquals();
    expect(controller.state.resultText, '500');
    expect(controller.state.editingTokenIndex, isNull);
  });

  // --- Regression tests ---

  void type(String keys) {
    for (final k in keys.split('')) {
      switch (k) {
        case '+': controller.onOperator(TokenType.plus, '+');
        case '-': controller.onOperator(TokenType.minus, '-');
        case '*': controller.onOperator(TokenType.multiply, '×');
        case '/': controller.onOperator(TokenType.divide, '÷');
        case '=': controller.onEquals();
        default: controller.onDigit(k);
      }
    }
  }

  test('Huge results use scientific notation instead of Infinity', () {
    type('999999999999999');
    for (var i = 0; i < 22; i++) {
      type('*999999999999999');
    }
    type('=');
    expect(controller.state.resultText, isNot(contains('Infinity')));
    expect(controller.state.resultText, contains('e'));

    // Continuing from a scientific result still works.
    type('*2=');
    expect(controller.state.error, isNull);
    expect(controller.state.resultText, contains('e'));
  });

  test('Division results round instead of truncating', () {
    type('1/3*3=');
    expect(controller.state.resultText, '1');
  });

  test('Tiny negative results never display as -0', () {
    type('0');
    controller.onDecimal();
    type('000000000000001');
    type('/1000000=');
    expect(controller.state.resultText, isNot('-0'));
  });

  test('% on a highlighted operator is ignored, not turned into a bad expression', () {
    type('5+3');
    controller.selectToken(1);
    controller.onPercent();
    controller.deselectToken();
    controller.onEquals();
    expect(controller.state.error, isNull);
    expect(controller.state.resultText, '8');
  });

  test('+/- after equals negates the answer', () {
    type('9*6=');
    controller.onToggleSign();
    expect(controller.state.resultText, '-54');
    type('+4=');
    expect(controller.state.resultText, '-50');
  });

  test('% after equals applies to the answer', () {
    type('9*6=');
    controller.onPercent();
    type('=');
    expect(controller.state.resultText, '0.54');
  });

  test('Pressing equals twice does not re-celebrate', () {
    type('2+2=');
    final id = controller.state.celebrationId;
    type('=');
    expect(controller.state.celebrationId, id);
  });

  test('Edited number tokens respect the digit cap', () {
    type('1+2');
    controller.selectToken(0);
    for (var i = 0; i < 30; i++) {
      controller.onDigit('9');
    }
    final digits = controller.state.expression
        .getAllTokens()
        .first
        .text
        .replaceAll(RegExp(r'[^0-9]'), '');
    expect(digits.length, lessThanOrEqualTo(15));
  });

  test('History restore keeps scientific numbers intact', () {
    controller.loadExpression('1.5e20 + 1', '1.5e20');
    expect(controller.state.expression.getAllTokens().first.text, '1.5e20');
  });

  group('Editing tokens', () {
    void type(String keys) {
      for (final k in keys.split('')) {
        switch (k) {
          case '+':
            controller.onOperator(TokenType.plus, '+');
          case 'x':
            controller.onOperator(TokenType.multiply, '×');
          case '.':
            controller.onDecimal();
          default:
            controller.onDigit(k);
        }
      }
    }

    test('editing a number after = and pressing = shows the new answer', () {
      type('10x11');
      controller.onEquals();
      expect(controller.state.resultText, '110');

      controller.selectToken(0);
      type('20');
      controller.onEquals();
      expect(controller.state.resultText, '220');
      expect(controller.state.justEvaluated, isTrue);
      expect(controller.state.editingTokenIndex, isNull);
    });

    test('editing, then deselecting, then = still evaluates', () {
      type('10x11');
      controller.onEquals();
      controller.selectToken(0);
      type('20');
      controller.deselectToken();
      controller.onEquals();
      expect(controller.state.resultText, '220');
    });

    test('deselecting without edits after = keeps the answer on screen', () {
      type('10x11');
      controller.onEquals();
      controller.selectToken(0);
      controller.deselectToken();
      expect(controller.state.resultText, '110');
    });

    test('typing after editing the last number extends it', () {
      type('10x11');
      controller.selectToken(2);
      type('12');
      controller.deselectToken();
      type('5');
      controller.onEquals();
      expect(controller.state.resultText, '1,250');
    });

    test('operator on a highlighted middle number swaps the next operator', () {
      type('10x11');
      controller.selectToken(0);
      controller.onOperator(TokenType.plus, '+');
      controller.onEquals();
      expect(controller.state.resultText, '21');
    });

    test('deleting a middle number removes its operator too', () {
      type('10x11+5');
      controller.selectToken(2);
      controller.onBackspace(); // replacing mode: removes whole token
      controller.onEquals();
      expect(controller.state.resultText, '15');
    });

    test('deleting an operator joins the numbers around it', () {
      type('10x11');
      controller.selectToken(1);
      controller.onBackspace();
      controller.onEquals();
      expect(controller.state.resultText, '1,011');
    });

    test('percent on a highlighted operator is ignored', () {
      type('10x11');
      controller.selectToken(1);
      controller.onPercent();
      controller.onEquals();
      expect(controller.state.resultText, '110');
    });

    test('number ending with a dot after editing still evaluates', () {
      type('10x11');
      controller.selectToken(0);
      type('5.');
      controller.onEquals();
      expect(controller.state.error, isNull);
      expect(controller.state.resultText, '55');
    });
  });
}
