import 'package:decimal/decimal.dart';
import 'token.dart';

abstract class AstNode {}

class NumberNode extends AstNode {
  final Decimal value;
  final bool isPercent;

  NumberNode(this.value, {this.isPercent = false});

  @override
  String toString() => 'NumberNode($value, percent: $isPercent)';
}

class BinaryOpNode extends AstNode {
  final AstNode left;
  final TokenType op;
  final AstNode right;

  BinaryOpNode(this.left, this.op, this.right);

  @override
  String toString() => 'BinaryOpNode($left, $op, $right)';
}

class UnaryMinusNode extends AstNode {
  final AstNode operand;

  UnaryMinusNode(this.operand);

  @override
  String toString() => 'UnaryMinusNode($operand)';
}

/// A function call such as sin(x) or √(x). [name] is the token's
/// function name without "(" (see [Token.functionName]).
class FunctionNode extends AstNode {
  final String name;
  final AstNode argument;

  FunctionNode(this.name, this.argument);

  @override
  String toString() => 'FunctionNode($name, $argument)';
}

/// π or e.
class ConstantNode extends AstNode {
  final String symbol;

  ConstantNode(this.symbol);

  @override
  String toString() => 'ConstantNode($symbol)';
}

class FactorialNode extends AstNode {
  final AstNode operand;

  FactorialNode(this.operand);

  @override
  String toString() => 'FactorialNode($operand)';
}
