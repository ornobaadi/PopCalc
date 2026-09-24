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
}
