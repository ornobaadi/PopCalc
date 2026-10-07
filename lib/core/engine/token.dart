/// Core tokens for the calculator engine.
/// PURE DART - No Flutter imports allowed in core/engine.
enum TokenType {
  number,
  plus,
  minus,
  multiply,
  divide,
  percent,
  // Advanced mode
  power,
  leftParen,
  rightParen,
  /// A function call opener; its text carries the "(" (e.g. "sin(").
  function,
  /// π or e.
  constant,
  factorial,
}

class Token {
  final TokenType type;
  final String text;

  const Token(this.type, this.text);

  bool get isOperator =>
      type == TokenType.plus ||
      type == TokenType.minus ||
      type == TokenType.multiply ||
      type == TokenType.divide ||
      type == TokenType.power;

  bool get isNumber => type == TokenType.number;
  bool get isPercent => type == TokenType.percent;

  /// Opens a parenthesised group: "(" or a function like "sin(".
  bool get isOpener =>
      type == TokenType.leftParen || type == TokenType.function;

  /// Can end an operand, so an operator, ")" or "!" may follow it.
  bool get endsOperand =>
      type == TokenType.number ||
      type == TokenType.percent ||
      type == TokenType.rightParen ||
      type == TokenType.constant ||
      type == TokenType.factorial;

  /// Function name without its trailing "(" (e.g. "sin(" → "sin").
  String get functionName =>
      type == TokenType.function ? text.substring(0, text.length - 1) : text;

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
