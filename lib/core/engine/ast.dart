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
