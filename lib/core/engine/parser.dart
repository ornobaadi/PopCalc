import 'package:decimal/decimal.dart';
import 'ast.dart';
import 'token.dart';

class Parser {
  final List<Token> _tokens;
  int _current = 0;

  Parser(this._tokens);

  /// Parse the tokens into an AST.
  /// If [tolerant] is true, trailing operators are ignored so live preview works.
  static AstNode? parse(List<Token> tokens, {bool tolerant = true}) {
    if (tokens.isEmpty) return null;

    var cleanTokens = List<Token>.from(tokens);
    if (tolerant) {
      // Trim trailing operator tokens for live preview
      while (cleanTokens.isNotEmpty && cleanTokens.last.isOperator) {
        cleanTokens.removeLast();
      }
    }

    if (cleanTokens.isEmpty) return null;

    final parser = Parser(cleanTokens);
    try {
      final node = parser._expr();
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
    var node = _factor();

    while (!_isAtEnd()) {
      if (_match(TokenType.multiply)) {
        final right = _factor();
        node = BinaryOpNode(node, TokenType.multiply, right);
      } else if (_match(TokenType.divide)) {
        final right = _factor();
        node = BinaryOpNode(node, TokenType.divide, right);
      } else {
        break;
      }
    }

    return node;
  }

  AstNode _factor() {
    if (_match(TokenType.minus)) {
      final operand = _factor();
      return UnaryMinusNode(operand);
    }
    return _primary();
  }

  AstNode _primary() {
    if (_peek().type == TokenType.number) {
      final token = _advance();
      final val = Decimal.parse(token.text.replaceAll(',', ''));
      bool isPercent = false;
      if (!_isAtEnd() && _peek().type == TokenType.percent) {
        _advance();
        isPercent = true;
      }
      return NumberNode(val, isPercent: isPercent);
    }

    throw FormatException('Unexpected token: ${_peek()}');
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
