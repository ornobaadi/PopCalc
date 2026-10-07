import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';

const _sin = Token(TokenType.function, 'sin(');
const _paren = Token(TokenType.leftParen, '(');

void main() {
  late CalculatorController c;
  var unit = AngleUnit.degrees;

  setUp(() {
    unit = AngleUnit.degrees;
    c = CalculatorController(angleUnit: () => unit);
  });

  test('sin(30) = 0.5 with auto-closed paren', () {
    c.onOpener(_sin);
    c.onDigit('3');
    c.onDigit('0');
    c.onEquals();
    expect(c.state.resultText, '0.5');
    expect(c.state.expressionText, 'sin(30');
    expect(c.state.error, isNull);
  });

  test('angle unit switch refreshes the preview', () {
    c.onOpener(_sin);
    c.onConstant('π');
    expect(c.state.previewText, '0.05480366514879'); // sin(π°)
    unit = AngleUnit.radians;
    c.refreshPreview();
    expect(c.state.previewText, '0');
  });

  test('2(3 + 4) = 14', () {
    c.onDigit('2');
    c.onOpener(_paren);
    c.onDigit('3');
    c.onOperator(TokenType.plus, '+');
    c.onDigit('4');
    c.onRightParen();
    expect(c.state.resultText, '14');
    c.onEquals();
    expect(c.state.resultText, '14');
  });

  test('x² and ! continue from the answer', () {
    c.onDigit('3');
    c.onEquals();
    c.onSquare();
    c.onEquals();
    expect(c.state.resultText, '9');
    c.onFactorial();
    c.onEquals();
    expect(c.state.resultText, '362,880');
  });

  test('a function after = starts fresh', () {
    c.onDigit('5');
    c.onEquals();
    c.onOpener(const Token(TokenType.function, '√('));
    c.onDigit('9');
    c.onEquals();
    expect(c.state.resultText, '3');
  });

  test('10ˣ and eˣ', () {
    c.onExp10();
    c.onDigit('3');
    c.onEquals();
    expect(c.state.resultText, '1,000');
    c.onClear();
    c.onExpE();
    c.onDigit('0');
    c.onEquals();
    expect(c.state.resultText, '1');
  });

  test('= on a dangling function is ignored quietly', () {
    c.onDigit('2');
    c.onOperator(TokenType.multiply, '×');
    c.onOpener(_sin);
    c.onEquals();
    expect(c.state.error, isNull);
    expect(c.state.justEvaluated, isFalse);
  });

  test('domain errors show a message', () {
    c.onOpener(const Token(TokenType.function, 'ln('));
    c.onDigit('0');
    c.onEquals();
    expect(c.state.resultText, 'Not defined');
  });

  test('history string round-trips through loadExpression', () {
    c.onDigit('2');
    c.onConstant('e');
    c.onOperator(TokenType.plus, '+');
    c.onOpener(const Token(TokenType.function, 'cos⁻¹('));
    c.onDigit('1');
    c.onRightParen();
    c.onOperator(TokenType.plus, '+');
    c.onDigit('3');
    c.onFactorial();
    c.onOperator(TokenType.power, '^');
    c.onDigit('2');
    c.onEquals();
    final expr = c.state.expressionText;
    final result = c.state.resultText;
    expect(expr, '2e + cos⁻¹(1) + 3!^2');

    final restored = CalculatorController(angleUnit: () => unit);
    restored.loadExpression(expr, result);
    expect(restored.state.expression.toDisplayString(), expr);
    expect(restored.state.resultText, result);
  });

  test('scientific result in history still loads as one number', () {
    c.loadExpression('1.5e20 × 2', '3e20');
    expect(c.state.expression.getAllTokens().first.text, '1.5e20');
  });
}
