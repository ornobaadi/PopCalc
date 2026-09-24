import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/engine/parser.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/engine/calc_error.dart';

void main() {
  group('Math Engine Basics', () {
    test('2 + 3 = 5', () {
      final tokens = [
        const Token(TokenType.number, '2'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '3'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '5');
    });

    test('7 - 10 = -3', () {
      final tokens = [
        const Token(TokenType.number, '7'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '10'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '-3');
    });

    test('6 x 7 = 42', () {
      final tokens = [
        const Token(TokenType.number, '6'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '7'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '42');
    });

    test('9 / 3 = 3', () {
      final tokens = [
        const Token(TokenType.number, '9'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '3'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '3');
    });
  });

  group('Precision and Decimal Exactness', () {
    test('0.1 + 0.2 = 0.3 (No floating point inaccuracies)', () {
      final tokens = [
        const Token(TokenType.number, '0.1'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '0.2'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '0.3');
    });

    test('1 / 3 handles infinite repeating decimals up to 12 places', () {
      final tokens = [
        const Token(TokenType.number, '1'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '3'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '0.333333333333');
    });

    test('Formatter trims redundant trailing zeros: 2.50 -> 2.5', () {
      final dec = Decimal.parse('2.50');
      expect(NumberFormatter.format(dec), '2.5');
    });
  });

  group('Order of Operations (Precedence)', () {
    test('2 + 3 x 4 = 14', () {
      final tokens = [
        const Token(TokenType.number, '2'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '3'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '4'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '14');
    });

    test('10 - 6 / 2 = 7', () {
      final tokens = [
        const Token(TokenType.number, '10'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '6'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '2'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '7');
    });
  });

  group('Percent Semantics (PRD specifications)', () {
    test('1,024 + 5% = 1,075.2', () {
      final tokens = [
        const Token(TokenType.number, '1024'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '5'),
        const Token(TokenType.percent, '%'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '1,075.2');
    });

    test('255 + 5% = 267.75', () {
      final tokens = [
        const Token(TokenType.number, '255'),
        const Token(TokenType.plus, '+'),
        const Token(TokenType.number, '5'),
        const Token(TokenType.percent, '%'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '267.75');
    });

    test('200 - 15% = 170', () {
      final tokens = [
        const Token(TokenType.number, '200'),
        const Token(TokenType.minus, '-'),
        const Token(TokenType.number, '15'),
        const Token(TokenType.percent, '%'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '170');
    });

    test('80 x 25% = 20', () {
      final tokens = [
        const Token(TokenType.number, '80'),
        const Token(TokenType.multiply, '×'),
        const Token(TokenType.number, '25'),
        const Token(TokenType.percent, '%'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '20');
    });

    test('50 / 25% = 200', () {
      final tokens = [
        const Token(TokenType.number, '50'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '25'),
        const Token(TokenType.percent, '%'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '200');
    });

    test('12% alone = 0.12', () {
      final tokens = [
        const Token(TokenType.number, '12'),
        const Token(TokenType.percent, '%'),
      ];
      final ast = Parser.parse(tokens)!;
      final result = Evaluator.evaluate(ast);
      expect(NumberFormatter.format(result), '0.12');
    });
  });

  group('Expression Editing Rules', () {
    test('Operator replacement: 5 + followed by - replaces with -', () {
      var expr = const Expression();
      expr = expr.appendDigit('5');
      expr = expr.appendOperator(TokenType.plus, '+');
      expect(expr.tokens.last.type, TokenType.plus);

      expr = expr.appendOperator(TokenType.minus, '-');
      expect(expr.tokens.last.type, TokenType.minus);

      expr = expr.appendDigit('3');
      final all = expr.getAllTokens();
      expect(all.length, 3);
      expect(all[1].text, '-');
      expect(all[2].text, '3');
    });

    test('Leading zero handling: 0 then 7 produces 7', () {
      var expr = const Expression();
      expr = expr.appendDigit('0');
      expect(expr.currentNumber, '0');
      expr = expr.appendDigit('7');
      expect(expr.currentNumber, '7');
    });

    test('Single decimal point rule: 1.2.3 blocks second dot', () {
      var expr = const Expression();
      expr = expr.appendDigit('1');
      expr = expr.appendDecimal();
      expr = expr.appendDigit('2');
      expr = expr.appendDecimal(); // Should be ignored
      expr = expr.appendDigit('3');
      expect(expr.currentNumber, '1.23');
    });

    test('Sign toggle (+/-)', () {
      var expr = const Expression();
      expr = expr.appendDigit('4');
      expr = expr.appendDigit('2');
      expect(expr.currentNumber, '42');
      expr = expr.toggleSign();
      expect(expr.currentNumber, '-42');
      expr = expr.toggleSign();
      expect(expr.currentNumber, '42');
    });

    test('Backspace and clear', () {
      var expr = const Expression();
      expr = expr.appendDigit('1');
      expr = expr.appendDigit('2');
      expr = expr.appendDigit('3');
      expect(expr.currentNumber, '123');
      expr = expr.backspace();
      expect(expr.currentNumber, '12');
      expr = expr.clear();
      expect(expr.isEmpty, true);
    });
  });

  group('Error Handling', () {
    test('Divide by zero throws CalcException with divideByZero error', () {
      final tokens = [
        const Token(TokenType.number, '5'),
        const Token(TokenType.divide, '÷'),
        const Token(TokenType.number, '0'),
      ];
      final ast = Parser.parse(tokens)!;
      expect(
        () => Evaluator.evaluate(ast),
        throwsA(isA<CalcException>().having(
          (e) => e.error,
          'error',
          CalcError.divideByZero,
        )),
      );
    });
  });
}
