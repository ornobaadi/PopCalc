import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/engine/parser.dart';
import 'package:popcalc/core/engine/token.dart';
import 'package:popcalc/core/storage/history_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'calculator_state.dart';

final calculatorProvider =
    StateNotifierProvider<CalculatorController, CalculatorState>((ref) {
  final controller = CalculatorController(
    onHistoryAdded: (expr, res) {
      ref.read(historyProvider.notifier).addEntry(expr, res);
    },
    angleUnit: () => ref.read(settingsProvider).angleUnit,
  );
  ref.listen(settingsProvider.select((s) => s.angleUnit),
      (_, _) => controller.refreshPreview());
  return controller;
});

class CalculatorController extends StateNotifier<CalculatorState> {
  final void Function(String expression, String result)? onHistoryAdded;
  final AngleUnit Function()? angleUnit;

  CalculatorController({this.onHistoryAdded, this.angleUnit})
      : super(const CalculatorState());

  AngleUnit get _angleUnit => angleUnit?.call() ?? AngleUnit.degrees;

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

    if (state.justEvaluated) {
      defaultResult = _tryEvaluate(state.expression) ?? defaultResult;
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

    final newExpr = _baseExpression().appendPercent();
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

    final newExpr = _baseExpression().toggleSign();
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
      justEvaluated: false,
    );
  }

  /// After `=`, follow-up actions (+/-, %) apply to the displayed answer,
  /// not to the expression that produced it.
  Expression _baseExpression() {
    if (state.justEvaluated) {
      return Expression.fromResult(state.resultText.replaceAll(',', ''));
    }
    return state.expression;
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

  // --- Advanced mode keys ---

  /// "(" or a function such as "sin(". After "=" these start a new
  /// expression, like a digit does.
  void onOpener(Token opener) =>
      _applyAdvanced((e) => e.appendOpener(opener), continueFromResult: false);

  void onRightParen() => _applyAdvanced((e) => e.appendRightParen());

  void onConstant(String symbol) => _applyAdvanced(
      (e) => e.appendConstant(symbol),
      continueFromResult: false);

  void onFactorial() => _applyAdvanced((e) => e.appendFactorial());

  /// x²: "^2" on the current operand.
  void onSquare() => _applyAdvanced((e) {
        final withPower = e.appendOperator(TokenType.power, '^');
        final all = withPower.getAllTokens();
        return all.isNotEmpty && all.last.type == TokenType.power
            ? withPower.appendDigit('2')
            : e;
      });

  /// eˣ: "e^".
  void onExpE() => _applyAdvanced(
      (e) => e.appendConstant('e').appendOperator(TokenType.power, '^'),
      continueFromResult: false);

  /// 10ˣ: "10^", multiplying whatever came before.
  void onExp10() => _applyAdvanced((e) => e.appendPowerOf('10'),
      continueFromResult: false);

  /// Shared path for advanced keys. [continueFromResult] decides whether,
  /// after "=", the key applies to the answer (like an operator) or starts
  /// fresh (like a digit).
  void _applyAdvanced(Expression Function(Expression) edit,
      {bool continueFromResult = true}) {
    if (state.editingTokenIndex != null) deselectToken();

    var expr = state.expression;
    if (state.justEvaluated) {
      expr = continueFromResult ? _baseExpression() : const Expression();
    }

    final newExpr = edit(expr);
    if (identical(newExpr, expr) && !state.justEvaluated) return;

    final preview = _computePreview(newExpr);
    final shown = newExpr.currentNumber.isNotEmpty
        ? NumberFormatter.formatInputNumber(newExpr.currentNumber)
        : _tryEvaluate(newExpr) ?? (state.justEvaluated ? '0' : state.resultText);

    state = state.copyWith(
      expression: newExpr,
      expressionText: newExpr.toDisplayString(),
      resultText: shown,
      previewText: preview,
      clearPreview: preview == null,
      clearError: true,
      justEvaluated: false,
    );
  }

  /// Recomputes the live preview, e.g. after switching DEG/RAD.
  void refreshPreview() {
    if (state.justEvaluated || state.error != null) return;
    final preview = _computePreview(state.expression);
    state = state.copyWith(previewText: preview, clearPreview: preview == null);
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
      if (ch == '^') { tokens.add(const Token(TokenType.power, '^')); i++; continue; }
      if (ch == '(') { tokens.add(const Token(TokenType.leftParen, '(')); i++; continue; }
      if (ch == ')') { tokens.add(const Token(TokenType.rightParen, ')')); i++; continue; }
      if (ch == '!') { tokens.add(const Token(TokenType.factorial, '!')); i++; continue; }
      if (ch == 'π' || ch == 'e') { tokens.add(Token(TokenType.constant, ch)); i++; continue; }
      final fn = _functionNames.where((f) => clean.startsWith(f, i)).firstOrNull;
      if (fn != null) { tokens.add(Token(TokenType.function, fn)); i += fn.length; continue; }
      // Number: collect digits, commas (thousands separator), dots
      if (RegExp(r'[0-9.,\-]').hasMatch(ch)) {
        final start = i;
        // 'e' keeps scientific results (e.g. "1.5e20") in one token, but
        // only when a digit follows; otherwise it is the constant e ("2e").
        while (i < clean.length &&
            (RegExp(r'[0-9.,]').hasMatch(clean[i]) ||
                (clean[i] == 'e' &&
                    i + 1 < clean.length &&
                    RegExp(r'[0-9]').hasMatch(clean[i + 1])))) { i++; }
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

  /// Function openers as they appear in expression strings.
  static const _functionNames = [
    'sin⁻¹(', 'cos⁻¹(', 'tan⁻¹(', 'sin(', 'cos(', 'tan(',
    'ln(', 'log(', '√(', '∛(',
  ];

  String? _tryEvaluate(Expression expr) {
    try {
      final tokens = expr.getAllTokens();
      if (tokens.isEmpty) return null;
      final ast = Parser.parse(tokens, tolerant: true);
      if (ast == null) return null;
      final val = Evaluator.evaluate(ast, angleUnit: _angleUnit);
      return NumberFormatter.format(val);
    } catch (_) {
      return null;
    }
  }

  void onEquals() {
    // Pressing = again on an answer would duplicate history + celebration.
    if (state.justEvaluated) return;

    final tokens = state.expression.getAllTokens();
    if (tokens.isEmpty) return;

    final ast = Parser.parse(tokens, tolerant: false);
    if (ast == null) {
      // A trailing operator ("5 +") or opener ("sin(") is just incomplete —
      // ignore quietly. Anything else is malformed (e.g. after token edits).
      if (!tokens.last.isOperator && !tokens.last.isOpener) {
        _showError(CalcError.invalidExpression);
      }
      return;
    }

    try {
      final evaluated = Evaluator.evaluate(ast, angleUnit: _angleUnit);
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
        celebrationId: state.celebrationId + 1,
      );
    } on CalcException catch (e) {
      _showError(e.error);
    } catch (_) {
      _showError(CalcError.invalidExpression);
    }
  }

  void _showError(CalcError error) {
    state = state.copyWith(
      error: error,
      resultText: error.userMessage,
      clearEditingTokenIndex: true,
      isReplacingEditedToken: false,
      clearPreview: true,
      justEvaluated: false,
    );
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
        final digitCount = token.text.replaceAll(RegExp(r'[^0-9]'), '').length;
        if (digitCount >= Expression.maxDigitsPerNumber) return;
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
      justEvaluated: false,
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
      justEvaluated: false,
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
        justEvaluated: false,
        isReplacingEditedToken: false,
      );
    } else {
      // User tapped an operator while a number was highlighted: swap the
      // operator that follows it, or append one if the number is last.
      var after = idx;
      if (after + 1 < allTokens.length && allTokens[after + 1].isPercent) {
        after++;
      }
      final opToken = Token(op, symbol);
      final newExpr =
          after + 1 < allTokens.length && allTokens[after + 1].isOperator
              ? state.expression.replaceTokenAt(after + 1, opToken)
              : state.expression.insertTokenAfter(after, opToken);
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
        justEvaluated: false,
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
    if (!token.isNumber) return;
    if (idx + 1 < allTokens.length && allTokens[idx + 1].isPercent) return;

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
      justEvaluated: false,
      editingTokenIndex: idx + 1,
      isReplacingEditedToken: false,
    );
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
        justEvaluated: false,
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
        final newExpr = state.expression.removeTokenCleanly(idx);
        final preview = _computePreview(newExpr);
        final remaining = newExpr.getAllTokens();

        state = state.copyWith(
          expression: newExpr,
          expressionText: newExpr.toDisplayString(),
          clearEditingTokenIndex: true,
          isReplacingEditedToken: false,
          resultText: _displayFor(remaining),
          previewText: preview,
          clearPreview: preview == null,
          clearError: true,
          justEvaluated: false,
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
          justEvaluated: false,
          isReplacingEditedToken: false,
        );
      }
    } else {
      final newExpr = state.expression.removeTokenCleanly(idx);
      final preview = _computePreview(newExpr);
      final remaining = newExpr.getAllTokens();

      state = state.copyWith(
        expression: newExpr,
        expressionText: newExpr.toDisplayString(),
        clearEditingTokenIndex: true,
        isReplacingEditedToken: false,
        resultText: _displayFor(remaining),
        previewText: preview,
        clearPreview: preview == null,
        clearError: true,
        justEvaluated: false,
      );
    }
  }

  String _displayFor(List<Token> tokens) {
    if (tokens.isEmpty) return '0';
    final last = tokens.last;
    return last.isNumber ? NumberFormatter.formatInputNumber(last.text) : last.text;
  }

  String? _computePreview(Expression expr) {
    final allTokens = expr.getAllTokens();
    if (allTokens.isEmpty || allTokens.length < 2) return null;

    final ast = Parser.parse(allTokens, tolerant: true);
    if (ast == null) return null;

    try {
      final res = Evaluator.evaluate(ast, angleUnit: _angleUnit);
      return NumberFormatter.format(res);
    } catch (_) {
      return null;
    }
  }
}
