import 'dart:math' as math;

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

/// How trig functions read and return angles.
enum AngleUnit {
  degrees,
  radians;

  static AngleUnit fromName(String? name) => AngleUnit.values.firstWhere(
        (u) => u.name == name,
        orElse: () => AngleUnit.degrees,
      );
}

class Evaluator {
  static final Decimal _oneHundred = Decimal.fromInt(100);
  static final Decimal _ninety = Decimal.fromInt(90);
  static final Decimal _threeSixty = Decimal.fromInt(360);

  static final Decimal pi = Decimal.parse('3.14159265358979323846264338327950');
  static final Decimal e = Decimal.parse('2.71828182845904523536028747135266');

  /// Results past this many integer digits are reported as overflow.
  static const int _maxDigits = 1000;

  /// Largest n accepted by n!.
  static const int _maxFactorial = 450;

  /// Evaluates an AST node to a [Decimal] result.
  /// Throws [CalcException] on errors like divide by zero.
  ///
  /// + − × ÷ %, integer powers and factorials are exact. Roots, logs, trig
  /// and fractional powers go through doubles and are rounded to 15
  /// significant digits, the most the display shows.
  static Decimal evaluate(AstNode node,
      {AngleUnit angleUnit = AngleUnit.degrees}) {
    return _Evaluation(angleUnit)._eval(node);
  }

  static Decimal _divide(Decimal a, Decimal b) {
    if (b == Decimal.zero) {
      throw CalcException(CalcError.divideByZero);
    }
    final Rational rational = a.toRational() / b.toRational();
    return rational.toDecimal(scaleOnInfinitePrecision: 32);
  }
}

class _Evaluation {
  final AngleUnit angleUnit;

  _Evaluation(this.angleUnit);

  Decimal _eval(AstNode node) {
    if (node is NumberNode) {
      if (node.isPercent) {
        return Evaluator._divide(node.value, Evaluator._oneHundred);
      }
      return node.value;
    }

    if (node is UnaryMinusNode) {
      final val = _eval(node.operand);
      return -val;
    }

    if (node is ConstantNode) {
      switch (node.symbol) {
        case 'π':
          return Evaluator.pi;
        case 'e':
          return Evaluator.e;
      }
      throw CalcException(CalcError.invalidExpression);
    }

    if (node is FactorialNode) {
      return _factorial(_eval(node.operand));
    }

    if (node is FunctionNode) {
      return _function(node.name, _eval(node.argument));
    }

    if (node is BinaryOpNode) {
      final leftVal = _eval(node.left);

      // Handle percent on right operand
      if (node.right is NumberNode && (node.right as NumberNode).isPercent) {
        final percentNum = (node.right as NumberNode).value;
        final fraction = Evaluator._divide(percentNum, Evaluator._oneHundred);

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
            return Evaluator._divide(leftVal, fraction);
          case TokenType.power:
            // a ^ (b / 100)
            return _power(leftVal, fraction);
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
          return Evaluator._divide(leftVal, rightVal);
        case TokenType.power:
          return _power(leftVal, rightVal);
        default:
          throw CalcException(CalcError.invalidExpression);
      }
    }

    throw CalcException(CalcError.invalidExpression);
  }

  Decimal _power(Decimal base, Decimal exponent) {
    if (exponent.isInteger) {
      if (base == Decimal.zero) {
        if (exponent < Decimal.zero) {
          throw CalcException(CalcError.divideByZero);
        }
        return exponent == Decimal.zero ? Decimal.one : Decimal.zero;
      }
      if (base.abs() == Decimal.one) {
        final odd = exponent.toBigInt().isOdd;
        return base < Decimal.zero && odd ? -Decimal.one : Decimal.one;
      }
      // Estimate the size first so 9^99999 fails fast instead of hanging.
      final magnitude =
          exponent.toDouble() * math.log(base.abs().toDouble()) / math.ln10;
      if (magnitude > Evaluator._maxDigits) {
        throw CalcException(CalcError.overflow);
      }
      if (magnitude < -Evaluator._maxDigits) {
        return Decimal.zero; // Far below what the display can show.
      }
      final result = base.toRational().pow(exponent.toBigInt().toInt());
      return result.toDecimal(scaleOnInfinitePrecision: 32);
    }

    if (base < Decimal.zero) {
      throw CalcException(CalcError.domainError);
    }
    return _fromDouble(math.pow(base.toDouble(), exponent.toDouble()).toDouble());
  }

  Decimal _factorial(Decimal n) {
    if (!n.isInteger || n < Decimal.zero) {
      throw CalcException(CalcError.domainError);
    }
    if (n > Decimal.fromInt(Evaluator._maxFactorial)) {
      throw CalcException(CalcError.overflow);
    }
    var result = BigInt.one;
    for (var i = 2; i <= n.toBigInt().toInt(); i++) {
      result *= BigInt.from(i);
    }
    return Decimal.fromBigInt(result);
  }

  Decimal _function(String name, Decimal x) {
    switch (name) {
      case 'sin':
      case 'cos':
      case 'tan':
        return _trig(name, x);
      case 'sin⁻¹':
        if (x.abs() > Decimal.one) throw CalcException(CalcError.domainError);
        return _fromAngle(math.asin(x.toDouble()));
      case 'cos⁻¹':
        if (x.abs() > Decimal.one) throw CalcException(CalcError.domainError);
        return _fromAngle(math.acos(x.toDouble()));
      case 'tan⁻¹':
        return _fromAngle(math.atan(x.toDouble()));
      case 'ln':
        if (x <= Decimal.zero) throw CalcException(CalcError.domainError);
        return _fromDouble(math.log(x.toDouble()));
      case 'log':
        if (x <= Decimal.zero) throw CalcException(CalcError.domainError);
        return _fromDouble(math.log(x.toDouble()) / math.ln10);
      case '√':
        if (x < Decimal.zero) throw CalcException(CalcError.domainError);
        return _fromDouble(math.sqrt(x.toDouble()));
      case '∛':
        final r = math.pow(x.abs().toDouble(), 1 / 3).toDouble();
        return _fromDouble(x < Decimal.zero ? -r : r);
    }
    throw CalcException(CalcError.invalidExpression);
  }

  Decimal _trig(String name, Decimal x) {
    double radians;
    if (angleUnit == AngleUnit.degrees) {
      // Reduce exactly first so sin(180) is 0 and tan(90) is undefined,
      // not 1.2e-16 and 1.6e16.
      final reduced = x % Evaluator._threeSixty;
      final angle = reduced < Decimal.zero
          ? reduced + Evaluator._threeSixty
          : reduced;
      if ((angle % Evaluator._ninety) == Decimal.zero) {
        final quadrant = (angle / Evaluator._ninety).toDecimal().toBigInt().toInt();
        const sines = [0, 1, 0, -1];
        const cosines = [1, 0, -1, 0];
        final s = sines[quadrant];
        final c = cosines[quadrant];
        switch (name) {
          case 'sin':
            return Decimal.fromInt(s);
          case 'cos':
            return Decimal.fromInt(c);
          default:
            if (c == 0) throw CalcException(CalcError.domainError);
            return Decimal.fromInt(s * c);
        }
      }
      radians = angle.toDouble() * math.pi / 180;
    } else {
      radians = x.toDouble();
    }

    final double value;
    switch (name) {
      case 'sin':
        value = math.sin(radians);
        break;
      case 'cos':
        value = math.cos(radians);
        break;
      default:
        if (math.cos(radians).abs() < 1e-15) {
          throw CalcException(CalcError.domainError);
        }
        value = math.tan(radians);
    }
    // Doubles leave tiny residue at multiples of π (sin π = 1.2e-16).
    return _fromDouble(value.abs() < 1e-15 ? 0 : value);
  }

  Decimal _fromAngle(double radians) => _fromDouble(
      angleUnit == AngleUnit.degrees ? radians * 180 / math.pi : radians);

  /// Rounds a double result to 15 significant digits so float noise
  /// (asin(0.5) = 30.000000000000004°) never reaches the display.
  static Decimal _fromDouble(double value) {
    if (value.isNaN) throw CalcException(CalcError.domainError);
    if (value.isInfinite) throw CalcException(CalcError.overflow);
    if (value == 0) return Decimal.zero;
    return Decimal.parse(value.toStringAsPrecision(15));
  }
}
