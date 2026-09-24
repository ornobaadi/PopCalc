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

  void onDigit(String digit) {
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
    var expr = state.expression;
    if (state.justEvaluated) {
      // Continue from the evaluated result
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
    final newExpr = state.expression.appendPercent();
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

  void onToggleSign() {
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
      clearPreview: true,
      clearError: true,
      justEvaluated: true,
    );
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
        clearPreview: true,
        clearError: true,
        justEvaluated: true,
      );
    } on CalcException catch (e) {
      state = state.copyWith(
        error: e.error,
        resultText: e.error.userMessage,
        clearPreview: true,
        justEvaluated: false,
      );
    } catch (_) {
      state = state.copyWith(
        error: CalcError.invalidExpression,
        resultText: CalcError.invalidExpression.userMessage,
        clearPreview: true,
        justEvaluated: false,
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
