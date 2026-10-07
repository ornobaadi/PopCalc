import 'package:decimal/decimal.dart';
import 'ast.dart';
import 'token.dart';

/// Grammar (lowest to highest precedence):
///   expr    → term (('+' | '−') term)*
///   term    → unary (('×' | '÷' | implicit ×) unary)*
///   unary   → '−' unary | power
///   power   → postfix ('^' unary)?          right-associative, so -2^2 = -4
///   postfix → primary '!'*
///   primary → number '%'? | constant | '(' expr ')' | function expr ')'
class Parser {
  final List<Token> _tokens;
  int _current = 0;

  Parser(this._tokens);

  /// Parse the tokens into an AST.
  /// If [tolerant] is true, trailing operators are ignored so live preview works.
  /// Unclosed parentheses are closed automatically in both modes.
  static AstNode? parse(List<Token> tokens, {bool tolerant = true}) {
    if (tokens.isEmpty) return null;

    var cleanTokens = List<Token>.from(tokens);
    if (tolerant) {
      // Trim trailing operators and dangling openers ("2 × sin(") for preview
      while (cleanTokens.isNotEmpty &&
          (cleanTokens.last.isOperator || cleanTokens.last.isOpener)) {
        cleanTokens.removeLast();
      }
    }

    if (cleanTokens.isEmpty) return null;

    var depth = 0;
    for (final t in cleanTokens) {
      if (t.isOpener) depth++;
      if (t.type == TokenType.rightParen) depth--;
      if (depth < 0) return null;
    }
    for (var i = 0; i < depth; i++) {
      cleanTokens.add(const Token(TokenType.rightParen, ')'));
    }

    final parser = Parser(cleanTokens);
    try {
      final node = parser._expr();
      // Leftover tokens (e.g. "5 % 3" or "5 3" after token editing) mean the
      // expression is malformed — never silently drop them.
      if (!parser._isAtEnd()) return null;
      return node;
    } catch (_) {
      return null;
    }
  }

  AstNode _expr() {
    var node = _term();

    while (!_isAtEnd()) {
      if (_match(TokenType.plus)) {
        final right = _term();
        node = BinaryOpNode(node, TokenType.plus, right);
      } else if (_match(TokenType.minus)) {
        final right = _term();
        node = BinaryOpNode(node, TokenType.minus, right);
      } else {
        break;
      }
    }

    return node;
  }

  AstNode _term() {
    var node = _unary();

    while (!_isAtEnd()) {
      if (_match(TokenType.multiply)) {
        final right = _unary();
        node = BinaryOpNode(node, TokenType.multiply, right);
      } else if (_match(TokenType.divide)) {
        final right = _unary();
        node = BinaryOpNode(node, TokenType.divide, right);
      } else if (_isImplicitMultiply()) {
        final right = _unary();
        node = BinaryOpNode(node, TokenType.multiply, right);
      } else {
        break;
      }
    }

    return node;
  }

  /// "2π", "2(3)", "(1)(2)", "π2" and "3!2" multiply implicitly. Two bare
  /// numbers side by side ("5 3", left by token editing) stay malformed.
  bool _isImplicitMultiply() {
    if (_isAtEnd() || _current == 0) return false;
    final next = _peek();
    if (next.isOpener || next.type == TokenType.constant) return true;
    if (next.isNumber) {
      final prev = _tokens[_current - 1].type;
      return prev == TokenType.rightParen ||
          prev == TokenType.constant ||
          prev == TokenType.factorial;
    }
    return false;
  }

  AstNode _unary() {
    if (_match(TokenType.minus)) {
      final operand = _unary();
      return UnaryMinusNode(operand);
    }
    return _power();
  }

  AstNode _power() {
    final base = _postfix();
    if (_match(TokenType.power)) {
      final exponent = _unary();
      return BinaryOpNode(base, TokenType.power, exponent);
    }
    return base;
  }

  AstNode _postfix() {
    var node = _primary();
    while (_match(TokenType.factorial)) {
      node = FactorialNode(node);
    }
    return node;
  }

  AstNode _primary() {
    if (_isAtEnd()) throw const FormatException('Unexpected end');
    final token = _peek();

    switch (token.type) {
      case TokenType.number:
        _advance();
        final val = Decimal.parse(token.text.replaceAll(',', ''));
        bool isPercent = false;
        if (!_isAtEnd() && _peek().type == TokenType.percent) {
          _advance();
          isPercent = true;
        }
        return NumberNode(val, isPercent: isPercent);
      case TokenType.constant:
        _advance();
        return ConstantNode(token.text);
      case TokenType.leftParen:
        _advance();
        final inner = _expr();
        _expect(TokenType.rightParen);
        return inner;
      case TokenType.function:
        _advance();
        final arg = _expr();
        _expect(TokenType.rightParen);
        return FunctionNode(token.functionName, arg);
      default:
        throw FormatException('Unexpected token: $token');
    }
  }

  void _expect(TokenType type) {
    if (!_match(type)) throw FormatException('Expected $type');
  }

  bool _match(TokenType type) {
    if (_check(type)) {
      _advance();
      return true;
    }
    return false;
  }

  bool _check(TokenType type) {
    if (_isAtEnd()) return false;
    return _peek().type == type;
  }

  Token _peek() => _tokens[_current];

  Token _advance() {
    if (!_isAtEnd()) _current++;
    return _tokens[_current - 1];
  }

  bool _isAtEnd() => _current >= _tokens.length;
}
