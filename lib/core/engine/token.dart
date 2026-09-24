/// Core tokens for the calculator engine.
/// PURE DART - No Flutter imports allowed in core/engine.
enum TokenType {
  number,
  plus,
  minus,
  multiply,
  divide,
  percent,
}

class Token {
  final TokenType type;
  final String text;

  const Token(this.type, this.text);

  bool get isOperator =>
      type == TokenType.plus ||
      type == TokenType.minus ||
      type == TokenType.multiply ||
      type == TokenType.divide;

  bool get isNumber => type == TokenType.number;
  bool get isPercent => type == TokenType.percent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Token &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          text == other.text;

  @override
  int get hashCode => type.hashCode ^ text.hashCode;

  @override
  String toString() => 'Token($type, "$text")';
}
