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
}
