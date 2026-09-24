import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';
import 'ast.dart';
import 'calc_error.dart';
import 'token.dart';

class CalcException implements Exception {
  final CalcError error;
  CalcException(this.error);

  @override
  String toString() => 'CalcException: ${error.userMessage}';
}

class Evaluator {
  static final Decimal _oneHundred = Decimal.fromInt(100);

  /// Evaluates an AST node to a [Decimal] result.
  /// Throws [CalcException] on errors like divide by zero.
  static Decimal evaluate(AstNode node) {
    return _eval(node);
  }

  static Decimal _eval(AstNode node) {
    if (node is NumberNode) {
      if (node.isPercent) {
        return _divide(node.value, _oneHundred);
      }
      return node.value;
    }

    if (node is UnaryMinusNode) {
      final val = _eval(node.operand);
      return -val;
    }

    if (node is BinaryOpNode) {
      final leftVal = _eval(node.left);

      // Handle percent on right operand
      if (node.right is NumberNode && (node.right as NumberNode).isPercent) {
        final percentNum = (node.right as NumberNode).value;
        final fraction = _divide(percentNum, _oneHundred);

        switch (node.op) {
          case TokenType.plus:
            // a + (a * b / 100)
            return leftVal + (leftVal * fraction);
          case TokenType.minus:
            // a - (a * b / 100)
            return leftVal - (leftVal * fraction);
          case TokenType.multiply:
            // a * (b / 100)
            return leftVal * fraction;
          case TokenType.divide:
            // a / (b / 100)
            return _divide(leftVal, fraction);
          default:
            throw CalcException(CalcError.invalidExpression);
        }
      }

      final rightVal = _eval(node.right);
      switch (node.op) {
        case TokenType.plus:
          return leftVal + rightVal;
        case TokenType.minus:
          return leftVal - rightVal;
        case TokenType.multiply:
          return leftVal * rightVal;
        case TokenType.divide:
          return _divide(leftVal, rightVal);
        default:
          throw CalcException(CalcError.invalidExpression);
      }
    }

    throw CalcException(CalcError.invalidExpression);
  }

  static Decimal _divide(Decimal a, Decimal b) {
    if (b == Decimal.zero) {
      throw CalcException(CalcError.divideByZero);
    }
    final Rational rational = a.toRational() / b.toRational();
    return rational.toDecimal(scaleOnInfinitePrecision: 12);
  }
}
