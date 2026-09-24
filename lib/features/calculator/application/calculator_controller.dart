import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/engine/parser.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/storage/history_store.dart';
import 'calculator_state.dart';

final calculatorProvider =
    StateNotifierProvider<CalculatorController, CalculatorState>((ref) {
  return CalculatorController(
    onHistoryAdded: (expr, res) {
      ref.read(historyProvider.notifier).addEntry(expr, res);
    },
  );
});

class CalculatorController extends StateNotifier<CalculatorState> {
  final void Function(String expression, String result)? onHistoryAdded;

  CalculatorController({this.onHistoryAdded}) : super(const CalculatorState());

  /// Selects a token in the expression for editing.
  /// Tapping the already selected token deselects it.
  void selectToken(int index) {
    if (state.editingTokenIndex == index) {
      deselectToken();
      return;
    }

    final allTokens = state.expression.getAllTokens();
    if (index < 0 || index >= allTokens.length) return;

    final token = allTokens[index];
    final display = token.isNumber
        ? NumberFormatter.formatInputNumber(token.text)
        : token.text;

    state = state.copyWith(
      editingTokenIndex: index,
      isReplacingEditedToken: true,
      resultText: display,
      clearError: true,
    );
  }

  /// Deselects any currently highlighted token and returns to normal entry.
  void deselectToken() {
    if (state.editingTokenIndex == null) return;

    final allTokens = state.expression.getAllTokens();
    String defaultResult = '0';
    if (allTokens.isNotEmpty) {
      final last = allTokens.last;
      defaultResult = last.isNumber
          ? NumberFormatter.formatInputNumber(last.text)
          : last.text;
    }

    state = state.copyWith(
      clearEditingTokenIndex: true,
      isReplacingEditedToken: false,
      resultText: defaultResult,
    );
  }

  void onDigit(String digit) {
    if (state.editingTokenIndex != null) {
      _handleEditedTokenDigit(digit);
      return;
    }

    var expr = state.expression;
    if (state.justEvaluated) {
      expr = const Expression();
    }

    final newExpr = expr.appendDigit(digit);
    final currentNum = newExpr.currentNumber.isNotEmpty
        ? NumberFormatter.formatInputNumber(newExpr.currentNumber)
        : '0';

    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: currentNum,
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      justEvaluated: false,
    );
  }

  void onDecimal() {
    if (state.editingTokenIndex != null) {
      _handleEditedTokenDecimal();
      return;
    }

    var expr = state.expression;
    if (state.justEvaluated) {
      expr = const Expression();
    }

    final newExpr = expr.appendDecimal();
    final currentNum = newExpr.currentNumber.isNotEmpty
        ? NumberFormatter.formatInputNumber(newExpr.currentNumber)
        : '0';

    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: currentNum,
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      justEvaluated: false,
    );
  }

  void onOperator(TokenType op, String symbol) {
    if (state.editingTokenIndex != null) {
      _handleEditedTokenOperator(op, symbol);
      return;
    }

    var expr = state.expression;
    if (state.justEvaluated) {
      expr = Expression.fromResult(state.resultText.replaceAll(',', ''));
    }

    final newExpr = expr.appendOperator(op, symbol);
    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      justEvaluated: false,
    );
  }

  void onPercent() {
    if (state.editingTokenIndex != null) {
      _handleEditedTokenPercent();
      return;
    }

    final newExpr = state.expression.appendPercent();
    final preview = _computePreview(newExpr);

    final allTokens = newExpr.getAllTokens();
    String percentDisplay = '0%';
    if (allTokens.length >= 2) {
      final lastNum = allTokens[allTokens.length - 2];
      if (lastNum.type == TokenType.number) {
        percentDisplay = '${NumberFormatter.formatInputNumber(lastNum.text)}%';
      }
    } else if (allTokens.isNotEmpty && allTokens.last.type == TokenType.percent) {
      percentDisplay = '%';
    }

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: percentDisplay,
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      justEvaluated: false,
    );
  }

  void onToggleSign() {
    if (state.editingTokenIndex != null) {
      _handleEditedTokenToggleSign();
      return;
    }

    final newExpr = state.expression.toggleSign();
    final currentNum = newExpr.currentNumber.isNotEmpty
        ? NumberFormatter.formatInputNumber(newExpr.currentNumber)
        : state.resultText;

    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: currentNum,
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
    );
  }

  void onBackspace() {
    if (state.editingTokenIndex != null) {
      _handleEditedTokenBackspace();
      return;
    }

    if (state.justEvaluated) {
      onClear();
      return;
    }

    final newExpr = state.expression.backspace();
    final currentNum = newExpr.currentNumber.isNotEmpty
        ? NumberFormatter.formatInputNumber(newExpr.currentNumber)
        : (newExpr.tokens.isNotEmpty ? newExpr.tokens.last.text : '0');

    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: currentNum,
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      justEvaluated: false,
    );
  }

  void onClear() {
    state = const CalculatorState();
  }

  void loadResult(String result) {
    state = state.copyWith(
      expression: Expression.fromResult(result.replaceAll(',', '')),
      resultText: result,
      expressionText: '',
      clearEditingTokenIndex: true,
      clearPreview: true,
      clearError: true,
      justEvaluated: true,
    );
  }

  /// Restores a full history entry — puts the original expression back
  /// into the editing buffer so the user can modify any token.
  void loadExpression(String expressionStr, String result) {
    // Parse the display string (e.g. "1,234 + 5%") back into tokens.
    // Tokenisation rules: numbers contain [0-9.,], operators are +−×÷, % is percent.
    final clean = expressionStr.trim();
    final List<Token> tokens = [];
    int i = 0;
    while (i < clean.length) {
      final ch = clean[i];
      if (ch == ' ') { i++; continue; }
      if (ch == '+') { tokens.add(const Token(TokenType.plus, '+')); i++; continue; }
      if (ch == '−' || ch == '-') { tokens.add(const Token(TokenType.minus, '−')); i++; continue; }
      if (ch == '×' || ch == '*') { tokens.add(const Token(TokenType.multiply, '×')); i++; continue; }
      if (ch == '÷' || ch == '/') { tokens.add(const Token(TokenType.divide, '÷')); i++; continue; }
      if (ch == '%') { tokens.add(const Token(TokenType.percent, '%')); i++; continue; }
      // Number: collect digits, commas (thousands separator), dots
      if (RegExp(r'[0-9.,\-]').hasMatch(ch)) {
        final start = i;
        while (i < clean.length && RegExp(r'[0-9.,]').hasMatch(clean[i])) { i++; }
        final raw = clean.substring(start, i).replaceAll(',', '');
        tokens.add(Token(TokenType.number, raw));
        continue;
      }
      i++; // skip unknown
    }

    final restoredExpr = tokens.isEmpty
        ? Expression.fromResult(result.replaceAll(',', ''))
        : Expression.fromTokens(tokens);

    // Compute live result for the restored expression
    final resultNum = _tryEvaluate(restoredExpr) ?? result;

    state = state.copyWith(
      expression: restoredExpr,
      resultText: resultNum,
      expressionText: expressionStr,
      clearEditingTokenIndex: true,
      clearPreview: true,
      clearError: true,
      justEvaluated: false,
    );
  }

  String? _tryEvaluate(Expression expr) {
    try {
      final tokens = expr.getAllTokens();
      if (tokens.isEmpty) return null;
      final ast = Parser.parse(tokens, tolerant: true);
      if (ast == null) return null;
      final val = Evaluator.evaluate(ast);
      return NumberFormatter.format(val);
    } catch (_) {
      return null;
    }
  }

  void onEquals() {
    final tokens = state.expression.getAllTokens();
    if (tokens.isEmpty) return;

    final ast = Parser.parse(tokens, tolerant: false);
    if (ast == null) return;

    try {
      final evaluated = Evaluator.evaluate(ast);
      final formattedResult = NumberFormatter.format(evaluated);
      final exprStr = state.expression.toDisplayString();

      onHistoryAdded?.call(exprStr, formattedResult);

      state = state.copyWith(
        expressionText: exprStr,
        resultText: formattedResult,
        clearEditingTokenIndex: true,
        isReplacingEditedToken: false,
        clearPreview: true,
        clearError: true,
        justEvaluated: true,
      );
    } on CalcException catch (e) {
      state = state.copyWith(
        error: e.error,
        resultText: e.error.userMessage,
        clearEditingTokenIndex: true,
        isReplacingEditedToken: false,
        clearPreview: true,
        justEvaluated: false,
      );
    } catch (_) {
      state = state.copyWith(
        error: CalcError.invalidExpression,
        resultText: CalcError.invalidExpression.userMessage,
        clearEditingTokenIndex: true,
        isReplacingEditedToken: false,
        clearPreview: true,
        justEvaluated: false,
      );
    }
  }

  // --- Handlers for Editing Highlighted Tokens ---

  void _handleEditedTokenDigit(String digit) {
    final idx = state.editingTokenIndex!;
    final allTokens = state.expression.getAllTokens();
    if (idx >= allTokens.length) {
      deselectToken();
      return;
    }

    final token = allTokens[idx];
    String newText;
    if (state.isReplacingEditedToken || !token.isNumber) {
      newText = digit;
    } else {
      if (token.text == '0') {
        newText = digit;
      } else if (token.text == '-0') {
        newText = '-$digit';
      } else {
        newText = token.text + digit;
      }
    }

    final newToken = Token(TokenType.number, newText);
    final newExpr = state.expression.replaceTokenAt(idx, newToken);
    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: NumberFormatter.formatInputNumber(newText),
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      isReplacingEditedToken: false,
    );
  }

  void _handleEditedTokenDecimal() {
    final idx = state.editingTokenIndex!;
    final allTokens = state.expression.getAllTokens();
    if (idx >= allTokens.length) {
      deselectToken();
      return;
    }

    final token = allTokens[idx];
    String newText;
    if (state.isReplacingEditedToken || !token.isNumber) {
      newText = '0.';
    } else {
      if (token.text.contains('.')) return;
      newText = '${token.text}.';
    }

    final newToken = Token(TokenType.number, newText);
    final newExpr = state.expression.replaceTokenAt(idx, newToken);
    final preview = _computePreview(newExpr);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: NumberFormatter.formatInputNumber(newText),
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      isReplacingEditedToken: false,
    );
  }

  void _handleEditedTokenOperator(TokenType op, String symbol) {
    final idx = state.editingTokenIndex!;
    final allTokens = state.expression.getAllTokens();
    if (idx >= allTokens.length) {
      deselectToken();
      return;
    }

    final token = allTokens[idx];
    if (token.isOperator || token.isPercent) {
      final newToken = Token(op, symbol);
      final newExpr = state.expression.replaceTokenAt(idx, newToken);
      final preview = _computePreview(newExpr);

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        resultText: symbol,
        previewText: preview,
        clearPreview: preview == null,
        clearError: true,
        isReplacingEditedToken: false,
      );
    } else {
      // User tapped an operator while a number was highlighted
      final newExpr = state.expression.insertTokenAfter(idx, Token(op, symbol));
      final preview = _computePreview(newExpr);

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        resultText: symbol,
        previewText: preview,
        clearPreview: preview == null,
        clearEditingTokenIndex: true,
        isReplacingEditedToken: false,
        clearError: true,
      );
    }
  }

  void _handleEditedTokenPercent() {
    final idx = state.editingTokenIndex!;
    final allTokens = state.expression.getAllTokens();
    if (idx >= allTokens.length) {
      deselectToken();
      return;
    }

    final token = allTokens[idx];
    if (token.isPercent) return;

    if (token.isOperator) {
      final newToken = const Token(TokenType.percent, '%');
      final newExpr = state.expression.replaceTokenAt(idx, newToken);
      final preview = _computePreview(newExpr);

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        resultText: '%',
        previewText: preview,
        clearPreview: preview == null,
        clearError: true,
      );
    } else {
      // Number token: append percent after it
      final newExpr = state.expression.insertTokenAfter(idx, const Token(TokenType.percent, '%'));
      final preview = _computePreview(newExpr);

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        resultText: '${NumberFormatter.formatInputNumber(token.text)}%',
        previewText: preview,
        clearPreview: preview == null,
        clearError: true,
        editingTokenIndex: idx + 1,
        isReplacingEditedToken: false,
      );
    }
  }

  void _handleEditedTokenToggleSign() {
    final idx = state.editingTokenIndex!;
    final allTokens = state.expression.getAllTokens();
    if (idx >= allTokens.length) {
      deselectToken();
      return;
    }

    final token = allTokens[idx];
    if (token.isNumber) {
      final toggled = token.text.startsWith('-')
          ? token.text.substring(1)
          : '-${token.text}';
      final newToken = Token(TokenType.number, toggled);
      final newExpr = state.expression.replaceTokenAt(idx, newToken);
      final preview = _computePreview(newExpr);

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        resultText: NumberFormatter.formatInputNumber(toggled),
        previewText: preview,
        clearPreview: preview == null,
        clearError: true,
        isReplacingEditedToken: false,
      );
    }
  }

  void _handleEditedTokenBackspace() {
    final idx = state.editingTokenIndex!;
    final allTokens = state.expression.getAllTokens();
    if (idx >= allTokens.length) {
      deselectToken();
      return;
    }

    final token = allTokens[idx];
    if (token.isNumber) {
      if (state.isReplacingEditedToken ||
          token.text.length <= 1 ||
          (token.text.length == 2 && token.text.startsWith('-'))) {
        final newExpr = state.expression.removeTokenAt(idx);
        final preview = _computePreview(newExpr);
        final remaining = newExpr.getAllTokens();

        state = state.copyWith(
          expression: newExpr,
          expressionText: newExpr.toDisplayString(),
          clearEditingTokenIndex: true,
          isReplacingEditedToken: false,
          resultText: remaining.isNotEmpty ? remaining.last.text : '0',
          previewText: preview,
          clearPreview: preview == null,
          clearError: true,
        );
      } else {
        final newText = token.text.substring(0, token.text.length - 1);
        final newToken = Token(TokenType.number, newText);
        final newExpr = state.expression.replaceTokenAt(idx, newToken);
        final preview = _computePreview(newExpr);

        state = state.copyWith(
          expression: newExpr,
          expressionText: newExpr.toDisplayString(),
          resultText: NumberFormatter.formatInputNumber(newText),
          previewText: preview,
          clearPreview: preview == null,
          clearError: true,
          isReplacingEditedToken: false,
        );
      }
    } else {
      final newExpr = state.expression.removeTokenAt(idx);
      final preview = _computePreview(newExpr);
      final remaining = newExpr.getAllTokens();

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        clearEditingTokenIndex: true,
        isReplacingEditedToken: false,
        resultText: remaining.isNotEmpty ? remaining.last.text : '0',
        previewText: preview,
        clearPreview: preview == null,
        clearError: true,
      );
    }
  }

  String? _computePreview(Expression expr) {
    final allTokens = expr.getAllTokens();
    if (allTokens.isEmpty || allTokens.length < 2) return null;

    final ast = Parser.parse(allTokens, tolerant: true);
    if (ast == null) return null;

    try {
      final res = Evaluator.evaluate(ast);
      return NumberFormatter.format(res);
    } catch (_) {
      return null;
    }
  }
}
