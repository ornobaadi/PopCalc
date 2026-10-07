import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/engine/parser.dart';
import 'package:popcalc/core/engine/token.dart';

/// Builds tokens from short strings: numbers, operators, "(", ")", "!",
/// "π", "e", and functions written with their "(" (e.g. "sin(").
List<Token> tok(List<String> parts) => parts.map((p) {
      switch (p) {
        case '+':
          return const Token(TokenType.plus, '+');
        case '-':
          return const Token(TokenType.minus, '-');
        case '×':
          return const Token(TokenType.multiply, '×');
        case '÷':
          return const Token(TokenType.divide, '÷');
        case '^':
          return const Token(TokenType.power, '^');
        case '%':
          return const Token(TokenType.percent, '%');
        case '(':
          return const Token(TokenType.leftParen, '(');
        case ')':
          return const Token(TokenType.rightParen, ')');
        case '!':
          return const Token(TokenType.factorial, '!');
        case 'π':
        case 'e':
          return Token(TokenType.constant, p);
      }
      if (p.endsWith('(')) return Token(TokenType.function, p);
      return Token(TokenType.number, p);
    }).toList();

String calc(List<String> parts,
    {AngleUnit unit = AngleUnit.degrees, bool tolerant = false}) {
  final ast = Parser.parse(tok(parts), tolerant: tolerant);
  if (ast == null) return 'PARSE';
  try {
    return NumberFormatter.format(Evaluator.evaluate(ast, angleUnit: unit));
  } on CalcException catch (e) {
    return e.error.name;
  }
}

void main() {
  group('Precedence', () {
    test('powers are right-associative: 2^3^2 = 512',
        () => expect(calc(['2', '^', '3', '^', '2']), '512'));
    test('power binds tighter than unary minus: -2^2 = -4',
        () => expect(calc(['-', '2', '^', '2']), '-4'));
    test('typed negative base: (-2)^2 = 4',
        () => expect(calc(['-2', '^', '2']), '4'));
    test('power before multiply: 2 × 3^2 = 18',
        () => expect(calc(['2', '×', '3', '^', '2']), '18'));
    test('negative exponent: 2^-2 = 0.25',
        () => expect(calc(['2', '^', '-', '2']), '0.25'));
    test('parentheses: (2 + 3) × 4 = 20',
        () => expect(calc(['(', '2', '+', '3', ')', '×', '4']), '20'));
    test('factorial before power: 3!^2 = 36',
        () => expect(calc(['3', '!', '^', '2']), '36'));
    test('percent exponent: 100^50% = 10',
        () => expect(calc(['100', '^', '50', '%']), '10'));
  });

  group('Implicit multiplication', () {
    test('2π', () => expect(calc(['2', 'π']), '6.28318530717959'));
    test('2(3 + 1) = 8',
        () => expect(calc(['2', '(', '3', '+', '1', ')']), '8'));
    test('(2)(3) = 6', () => expect(calc(['(', '2', ')', '(', '3', ')']), '6'));
    test('2√(9) = 6', () => expect(calc(['2', '√(', '9', ')']), '6'));
    test('two bare numbers stay malformed',
        () => expect(calc(['5', '3']), 'PARSE'));
  });

  group('Parentheses', () {
    test('unclosed groups close on evaluate: (2 + 3 × 4 = 14',
        () => expect(calc(['(', '2', '+', '3', '×', '4']), '14'));
    test('preview trims a dangling function: 2 × sin(',
        () => expect(calc(['2', '×', 'sin('], tolerant: true), '2'));
    test('stray ) is malformed', () => expect(calc(['2', ')']), 'PARSE'));
    test('empty () is malformed', () => expect(calc(['(', ')']), 'PARSE'));
  });

  group('Exact results', () {
    test('2^10 = 1,024', () => expect(calc(['2', '^', '10']), '1,024'));
    test('0.1^3 = 0.001', () => expect(calc(['0.1', '^', '3']), '0.001'));
    test('10! = 3,628,800', () => expect(calc(['10', '!']), '3,628,800'));
    test('0! = 1', () => expect(calc(['0', '!']), '1'));
    test('25! in scientific notation',
        () => expect(calc(['25', '!']), '1.551121e25'));
    test('1^1e20 does not hang',
        () => expect(calc(['1', '^', '100000000000000']), '1'));
  });

  group('Functions (degrees)', () {
    test('sin(30) = 0.5', () => expect(calc(['sin(', '30', ')']), '0.5'));
    test('sin(180) = 0', () => expect(calc(['sin(', '180', ')']), '0'));
    test('cos(90) = 0', () => expect(calc(['cos(', '90', ')']), '0'));
    test('cos(-180) = -1', () => expect(calc(['cos(', '-180', ')']), '-1'));
    test('cos(60) = 0.5', () => expect(calc(['cos(', '60', ')']), '0.5'));
    test('tan(45) = 1', () => expect(calc(['tan(', '45', ')']), '1'));
    test('tan(90) is undefined',
        () => expect(calc(['tan(', '90', ')']), 'domainError'));
    test('sin⁻¹(0.5) = 30',
        () => expect(calc(['sin⁻¹(', '0.5', ')']), '30'));
    test('cos⁻¹(2) is undefined',
        () => expect(calc(['cos⁻¹(', '2', ')']), 'domainError'));
    test('tan⁻¹(1) = 45', () => expect(calc(['tan⁻¹(', '1', ')']), '45'));
  });

  group('Functions (radians)', () {
    test('sin(π) = 0',
        () => expect(calc(['sin(', 'π', ')'], unit: AngleUnit.radians), '0'));
    test('cos(π) = -1',
        () => expect(calc(['cos(', 'π', ')'], unit: AngleUnit.radians), '-1'));
    test('sin(π ÷ 2) = 1',
        () => expect(
            calc(['sin(', 'π', '÷', '2', ')'], unit: AngleUnit.radians), '1'));
    test('tan(π ÷ 2) is undefined',
        () => expect(calc(['tan(', 'π', '÷', '2', ')'], unit: AngleUnit.radians),
            'domainError'));
  });

  group('Roots and logs', () {
    test('√(2)', () => expect(calc(['√(', '2', ')']), '1.4142135623731'));
    test('√(144) = 12', () => expect(calc(['√(', '144', ')']), '12'));
    test('√(-1) is undefined',
        () => expect(calc(['√(', '-1', ')']), 'domainError'));
    test('∛(-27) = -3', () => expect(calc(['∛(', '-27', ')']), '-3'));
    test('log(1000) = 3', () => expect(calc(['log(', '1000', ')']), '3'));
    test('ln(e) = 1', () => expect(calc(['ln(', 'e', ')']), '1'));
    test('ln(0) is undefined',
        () => expect(calc(['ln(', '0', ')']), 'domainError'));
    test('2^0.5 = √2', () => expect(calc(['2', '^', '0.5']), '1.4142135623731'));
    test('(-8)^0.5 is undefined',
        () => expect(calc(['-8', '^', '0.5']), 'domainError'));
  });

  group('Errors', () {
    test('2.5! is undefined', () => expect(calc(['2.5', '!']), 'domainError'));
    test('-3! is -(3!) = -6', () => expect(calc(['-', '3', '!']), '-6'));
    test('1000! overflows', () => expect(calc(['1000', '!']), 'overflow'));
    test('9^99999 overflows',
        () => expect(calc(['9', '^', '99999']), 'overflow'));
    test('0^-1 divides by zero',
        () => expect(calc(['0', '^', '-1']), 'divideByZero'));
    test('domain error message', () {
      expect(CalcError.domainError.userMessage, 'Not defined');
    });
  });

  group('Expression editing', () {
    test('function after a number keeps both', () {
      final e = const Expression().appendDigit('2').appendOpener(
          const Token(TokenType.function, 'sin('));
      expect(e.toDisplayString(), '2sin(');
    });

    test('minus inside a group starts a negative number', () {
      final e = const Expression()
          .appendOpener(const Token(TokenType.leftParen, '('))
          .appendOperator(TokenType.minus, '-')
          .appendDigit('3');
      expect(e.currentNumber, '-3');
    });

    test('lone minus before a function becomes unary minus', () {
      final e = const Expression()
          .appendOperator(TokenType.minus, '-')
          .appendOpener(const Token(TokenType.function, 'sin('))
          .appendDigit('3')
          .appendDigit('0');
      expect(e.toDisplayString(), '-sin(30');
      expect(calc(e.getAllTokens().map((t) => t.text).toList()), '-0.5');
    });

    test(') needs an open group and an operand', () {
      expect(const Expression().appendDigit('2').appendRightParen().tokens,
          isEmpty);
      final open = const Expression()
          .appendOpener(const Token(TokenType.leftParen, '('));
      expect(open.appendRightParen().tokens.length, 1);
      final closed = open.appendDigit('4').appendRightParen();
      expect(closed.toDisplayString(), '(4)');
      expect(closed.openParenDepth, 0);
    });

    test('operator after ) and constants', () {
      final e = const Expression()
          .appendConstant('π')
          .appendOperator(TokenType.multiply, '×')
          .appendDigit('2');
      expect(e.toDisplayString(), 'π × 2');
    });

    test('power shows without spaces', () {
      final e = const Expression()
          .appendDigit('2')
          .appendOperator(TokenType.power, '^')
          .appendDigit('8');
      expect(e.toDisplayString(), '2^8');
    });

    test('factorial needs an operand', () {
      expect(const Expression().appendFactorial().tokens, isEmpty);
      expect(const Expression().appendDigit('5').appendFactorial()
          .toDisplayString(), '5!');
    });

    test('10ˣ after a number multiplies', () {
      final e = const Expression().appendDigit('3').appendPowerOf('10');
      expect(e.toDisplayString(), '3 × 10^');
    });
  });
}
