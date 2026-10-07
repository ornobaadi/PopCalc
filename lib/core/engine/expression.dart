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
    } else if (newTokens.isNotEmpty && newTokens.last.endsOperand) {
      newTokens.add(Token(op, symbol));
      return Expression(tokens: newTokens, currentNumber: '');
    } else if (newTokens.isEmpty || newTokens.last.isOpener) {
      // At the start of the expression or a group, minus starts a negative number
      if (op == TokenType.minus) {
        return Expression(tokens: newTokens, currentNumber: '-');
      }
    }

    return this;
  }

  /// Number of "(" (including function openers) not yet closed.
  int get openParenDepth {
    var depth = 0;
    for (final t in tokens) {
      if (t.isOpener) depth++;
      if (t.type == TokenType.rightParen) depth--;
    }
    return depth;
  }

  /// Tokens with the number being typed committed. A lone "-" becomes a
  /// minus token so "-sin(30)" and "-π" work.
  List<Token> _committedTokens() {
    final list = List<Token>.from(tokens);
    if (currentNumber == '-') {
      list.add(const Token(TokenType.minus, '-'));
    } else if (currentNumber.isNotEmpty) {
      var num = currentNumber;
      if (num.endsWith('.')) num = num.substring(0, num.length - 1);
      list.add(Token(TokenType.number, num));
    }
    return list;
  }

  /// Appends "(" or a function opener such as "sin(". After a number or
  /// ")" this multiplies implicitly ("2(3)", "2sin(30)").
  Expression appendOpener(Token opener) {
    assert(opener.isOpener);
    if (tokens.length >= maxTokens) return this;
    return Expression(tokens: _committedTokens()..add(opener));
  }

  /// Appends ")" when there is an open group with something in it.
  Expression appendRightParen() {
    if (tokens.length >= maxTokens || openParenDepth <= 0) return this;
    final list = _committedTokens();
    if (list.isEmpty || !list.last.endsOperand) return this;
    return Expression(
        tokens: list..add(const Token(TokenType.rightParen, ')')));
  }

  /// Appends π or e. After a number this multiplies implicitly ("2π").
  Expression appendConstant(String symbol) {
    if (tokens.length >= maxTokens) return this;
    return Expression(
        tokens: _committedTokens()..add(Token(TokenType.constant, symbol)));
  }

  /// Appends "!" after a number, constant, ")" or another "!".
  Expression appendFactorial() {
    if (tokens.length >= maxTokens) return this;
    final list = _committedTokens();
    if (list.isEmpty || !list.last.endsOperand || list.last.isPercent) {
      return this;
    }
    return Expression(
        tokens: list..add(const Token(TokenType.factorial, '!')));
  }

  /// Appends "[base]^" (e.g. 10ˣ), multiplying by whatever came before.
  Expression appendPowerOf(String base) {
    if (tokens.length + 3 > maxTokens) return this;
    final list = _committedTokens();
    if (list.isNotEmpty && list.last.endsOperand) {
      list.add(const Token(TokenType.multiply, '×'));
    }
    list
      ..add(Token(TokenType.number, base))
      ..add(const Token(TokenType.power, '^'));
    return Expression(tokens: list);
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

  /// Removes the token at [index] without leaving a malformed expression:
  /// a number takes its percent and one neighbouring operator with it, and
  /// removing an operator between two numbers joins them ("10 × 11" → "1011").
  Expression removeTokenCleanly(int index) {
    final all = getAllTokens();
    if (index < 0 || index >= all.length) return this;
    final newAll = List<Token>.from(all);
    final token = newAll[index];

    if (token.isNumber) {
      var end = index + 1;
      if (end < newAll.length && newAll[end].isPercent) end++;
      var start = index;
      if (start > 0 && newAll[start - 1].isOperator) {
        start--;
      } else if (end < newAll.length && newAll[end].isOperator) {
        end++;
      }
      newAll.removeRange(start, end);
    } else if (token.isOperator &&
        index > 0 &&
        index + 1 < newAll.length &&
        newAll[index - 1].isNumber &&
        newAll[index + 1].isNumber) {
      final joined = newAll[index - 1].text + newAll[index + 1].text.replaceAll('-', '');
      newAll.replaceRange(index - 1, index + 2, [Token(TokenType.number, joined)]);
    } else {
      newAll.removeAt(index);
    }
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
    if (tokens.isNotEmpty && tokens.last.isNumber) {
      return Expression(
        tokens: List.unmodifiable(tokens.sublist(0, tokens.length - 1)),
        currentNumber: tokens.last.text,
      );
    }
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
      final isUnaryMinus = token.type == TokenType.minus &&
          (i == 0 || all[i - 1].isOpener || all[i - 1].isOperator);
      if (token.type == TokenType.power || isUnaryMinus) {
        buffer.write(token.text);
      } else if (token.isOperator) {
        buffer.write(' ${token.text} ');
      } else {
        buffer.write(token.text);
      }
    }
    return buffer.toString().trim();
  }
}
