import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/engine/parser.dart';
import 'package:popcalc/core/engine/token.dart';

/// Turns "1% - 1%" or "sin(30)" into tokens the way the keypad would.
List<Token> _tokens(String s) {
  final out = <Token>[];
  final re = RegExp(r'\d+(\.\d+)?|sin\(|cos\(|tan\(|ln\(|log\(|√\(|[-+×÷^%()!π]');
  for (final m in re.allMatches(s.replaceAll(' ', ''))) {
    final t = m.group(0)!;
    out.add(switch (t) {
      '+' => Token(TokenType.plus, t),
      '-' => Token(TokenType.minus, t),
      '×' => Token(TokenType.multiply, t),
      '÷' => Token(TokenType.divide, t),
      '^' => Token(TokenType.power, t),
      '%' => Token(TokenType.percent, t),
      '(' => Token(TokenType.leftParen, t),
      ')' => Token(TokenType.rightParen, t),
      '!' => Token(TokenType.factorial, t),
      'π' => Token(TokenType.constant, t),
      _ when t.endsWith('(') => Token(TokenType.function, t),
      _ => Token(TokenType.number, t),
    });
  }
  return out;
}

String _calc(String s) =>
    NumberFormatter.format(Evaluator.evaluate(Parser.parse(_tokens(s), tolerant: false)!));

void main() {
  group('percentages', () {
    const cases = {
      '1% - 1%': '0',
      '1% + 1%': '0.02',
      '50% + 10%': '0.6',
      '50% - 10% - 40%': '0',
      '100 + 10%': '110',
      '100 - 10%': '90',
      '200 × 5%': '10',
      '200 × 5% + 10%': '11',
      '100 + 10% + 10%': '121',
      '50 ÷ 25%': '200',
      '10%': '0.1',
    };
    cases.forEach((input, expected) {
      test('$input = $expected', () => expect(_calc(input), expected));
    });
  });

  group('everyday exactness', () {
    const cases = {
      '0.1 + 0.2': '0.3',
      '1 ÷ 3 × 3': '1',
      '2 ÷ 3': '0.66666666666667',
      '√(144)': '12',
      '√(0.25)': '0.5',
      '√(2)': '1.4142135623731',
      '√(8) ÷ √(2)': '2',
      '10 - 3 × 2': '4',
      '(10 - 3) × 2': '14',
      '2 ^ 10': '1,024',
      '2 ^ 3 ^ 2': '512',
      '-2 ^ 2': '-4',
      '(-2) ^ 2': '4',
      '0.1 × 3': '0.3',
      '1.1 × 1.1': '1.21',
      '100 ÷ 8': '12.5',
      '5!': '120',
      '√(2) × √(2)': '2',
      'sin(30)': '0.5',
      'cos(60)': '0.5',
      'tan(45)': '1',
      'log(1000)': '3',
      '999999999999999 + 1': '1e15',
      '7 - 10': '-3',
      '0.3 - 0.1': '0.2',
      '19.99 × 3': '59.97',
    };
    cases.forEach((input, expected) {
      test('$input = $expected', () => expect(_calc(input), expected));
    });
  });
}
