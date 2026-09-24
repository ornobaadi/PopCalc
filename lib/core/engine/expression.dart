import 'token.dart';

/// Represents an immutable mathematical expression and its editing rules.
class Expression {
  final List<Token> tokens;
  final String currentNumber;

  const Expression({
    this.tokens = const [],
    this.currentNumber = '',
  });

  static const int maxDigitsPerNumber = 15;
  static const int maxTokens = 60;

  bool get isEmpty => tokens.isEmpty && currentNumber.isEmpty;

  /// Returns true if the expression can be evaluated
  bool get canEvaluate =>
      currentNumber.isNotEmpty ||
      (tokens.isNotEmpty && !tokens.last.isOperator);

  /// Builds a full token list including the active current number
  List<Token> getAllTokens() {
    final list = List<Token>.from(tokens);
    if (currentNumber.isNotEmpty) {
      list.add(Token(TokenType.number, currentNumber));
    }
    return list;
  }

  /// Appends a digit ('0'-'9')
  Expression appendDigit(String digit) {
    if (tokens.length >= maxTokens) return this;

    // Check digit length cap (ignoring '-' and '.')
    final digitsOnly = currentNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length >= maxDigitsPerNumber) return this;

    // Leading zero cleanup: if currentNumber is "0", replace with new digit unless digit is '0'
    if (currentNumber == '0') {
      return Expression(
        tokens: tokens,
        currentNumber: digit,
      );
    } else if (currentNumber == '-0') {
      return Expression(
        tokens: tokens,
        currentNumber: '-$digit',
      );
    }

    return Expression(
      tokens: tokens,
      currentNumber: currentNumber + digit,
    );
  }

  /// Appends a decimal point '.'
  Expression appendDecimal() {
    if (tokens.length >= maxTokens) return this;

    // If current number already contains '.', ignore
    if (currentNumber.contains('.')) return this;

    if (currentNumber.isEmpty) {
      return Expression(
        tokens: tokens,
        currentNumber: '0.',
      );
    }

    return Expression(
      tokens: tokens,
      currentNumber: '$currentNumber.',
    );
  }

  /// Appends or replaces an operator ('+', '-', '×', '÷')
  Expression appendOperator(TokenType op, String symbol) {
    if (tokens.length >= maxTokens) return this;

    final newTokens = List<Token>.from(tokens);

    if (currentNumber.isNotEmpty) {
      // Commit current number
      String numToCommit = currentNumber;
      if (numToCommit.endsWith('.')) {
        numToCommit = numToCommit.substring(0, numToCommit.length - 1);
      }
      newTokens.add(Token(TokenType.number, numToCommit));
      newTokens.add(Token(op, symbol));
      return Expression(tokens: newTokens, currentNumber: '');
    }

    // If currentNumber is empty:
    if (newTokens.isNotEmpty && newTokens.last.isOperator) {
      // Consecutive operator rule: replace the previous operator
      newTokens[newTokens.length - 1] = Token(op, symbol);
      return Expression(tokens: newTokens, currentNumber: '');
    } else if (newTokens.isNotEmpty && (newTokens.last.isNumber || newTokens.last.isPercent)) {
      newTokens.add(Token(op, symbol));
      return Expression(tokens: newTokens, currentNumber: '');
    } else if (newTokens.isEmpty) {
      // If empty and operator is minus, treat as negative number input
      if (op == TokenType.minus) {
        return const Expression(tokens: [], currentNumber: '-');
      }
    }

    return this;
  }

  /// Appends a percent '%'
  Expression appendPercent() {
    if (tokens.length >= maxTokens) return this;

    final newTokens = List<Token>.from(tokens);

    if (currentNumber.isNotEmpty) {
      String numToCommit = currentNumber;
      if (numToCommit.endsWith('.')) {
        numToCommit = numToCommit.substring(0, numToCommit.length - 1);
      }
      newTokens.add(Token(TokenType.number, numToCommit));
      newTokens.add(const Token(TokenType.percent, '%'));
      return Expression(tokens: newTokens, currentNumber: '');
    } else if (newTokens.isNotEmpty && newTokens.last.isNumber) {
      newTokens.add(const Token(TokenType.percent, '%'));
      return Expression(tokens: newTokens, currentNumber: '');
    }

    return this;
  }

  /// Toggles the sign (+/-) of the active number or last result
  Expression toggleSign() {
    if (currentNumber.isNotEmpty) {
      if (currentNumber.startsWith('-')) {
        return Expression(
          tokens: tokens,
          currentNumber: currentNumber.substring(1),
        );
      } else {
        return Expression(
          tokens: tokens,
          currentNumber: '-$currentNumber',
        );
      }
    } else if (tokens.isNotEmpty && tokens.last.isNumber) {
      final newTokens = List<Token>.from(tokens);
      final last = newTokens.removeLast();
      final toggled = last.text.startsWith('-')
          ? last.text.substring(1)
          : '-${last.text}';
      return Expression(
        tokens: newTokens,
        currentNumber: toggled,
      );
    }
    return this;
  }

  /// Deletes the last character or token
  Expression backspace() {
    if (currentNumber.isNotEmpty) {
      final nextNumber = currentNumber.substring(0, currentNumber.length - 1);
      return Expression(
        tokens: tokens,
        currentNumber: nextNumber == '-' ? '' : nextNumber,
      );
    } else if (tokens.isNotEmpty) {
      final newTokens = List<Token>.from(tokens);
      final lastToken = newTokens.removeLast();
      if (lastToken.isNumber) {
        final text = lastToken.text;
        final nextNumber = text.length > 1 ? text.substring(0, text.length - 1) : '';
        return Expression(
          tokens: newTokens,
          currentNumber: nextNumber == '-' ? '' : nextNumber,
        );
      }
      return Expression(tokens: newTokens, currentNumber: '');
    }
    return this;
  }

  /// Replaces the token at [index] with [newToken]
  Expression replaceTokenAt(int index, Token newToken) {
    final all = getAllTokens();
    if (index < 0 || index >= all.length) return this;
    final newAll = List<Token>.from(all);
    newAll[index] = newToken;
    return Expression.fromTokens(newAll);
  }

  /// Removes the token at [index]
  Expression removeTokenAt(int index) {
    final all = getAllTokens();
    if (index < 0 || index >= all.length) return this;
    final newAll = List<Token>.from(all);
    newAll.removeAt(index);
    return Expression.fromTokens(newAll);
  }

  /// Inserts [newToken] right after [index]
  Expression insertTokenAfter(int index, Token newToken) {
    final all = getAllTokens();
    if (index < 0 || index >= all.length) {
      final newAll = List<Token>.from(all)..add(newToken);
      return Expression.fromTokens(newAll);
    }
    final newAll = List<Token>.from(all);
    newAll.insert(index + 1, newToken);
    return Expression.fromTokens(newAll);
  }

  /// Creates a new Expression from an explicit list of tokens
  factory Expression.fromTokens(List<Token> tokens) {
    return Expression(
      tokens: List.unmodifiable(tokens),
      currentNumber: '',
    );
  }

  /// Clears the entire expression
  Expression clear() {
    return const Expression(tokens: [], currentNumber: '');
  }

  /// Creates a new Expression from a single result number (e.g. after '=')
  static Expression fromResult(String resultStr) {
    return Expression(
      tokens: const [],
      currentNumber: resultStr,
    );
  }

  /// Formatted string for the expression line (e.g. "1,024 + 5%")
  String toDisplayString() {
    final all = getAllTokens();
    if (all.isEmpty) return '';

    final buffer = StringBuffer();
    for (int i = 0; i < all.length; i++) {
      final token = all[i];
      if (token.isOperator) {
        buffer.write(' ${token.text} ');
      } else {
        buffer.write(token.text);
      }
    }
    return buffer.toString().trim();
  }
}
