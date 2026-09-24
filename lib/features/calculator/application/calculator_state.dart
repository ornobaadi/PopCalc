import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/expression.dart';

class CalculatorState {
  final Expression expression;
  final String expressionText;
  final String resultText;
  final String? previewText;
  final CalcError? error;
  final bool justEvaluated;
  final int? editingTokenIndex;
  final bool isReplacingEditedToken;

  const CalculatorState({
    this.expression = const Expression(),
    this.expressionText = '',
    this.resultText = '0',
    this.previewText,
    this.error,
    this.justEvaluated = false,
    this.editingTokenIndex,
    this.isReplacingEditedToken = false,
  });

  /// True when the result is the idle "0" with nothing typed.
  bool get isZeroState =>
      error == null &&
      !justEvaluated &&
      editingTokenIndex == null &&
      expression.getAllTokens().isEmpty &&
      resultText == '0';

  CalculatorState copyWith({
    Expression? expression,
    String? expressionText,
    String? resultText,
    String? previewText,
    bool clearPreview = false,
    CalcError? error,
    bool clearError = false,
    bool? justEvaluated,
    int? editingTokenIndex,
    bool clearEditingTokenIndex = false,
    bool? isReplacingEditedToken,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      expressionText: expressionText ?? this.expressionText,
      resultText: resultText ?? this.resultText,
      previewText: clearPreview ? null : (previewText ?? this.previewText),
      error: clearError ? null : (error ?? this.error),
      justEvaluated: justEvaluated ?? this.justEvaluated,
      editingTokenIndex: clearEditingTokenIndex
          ? null
          : (editingTokenIndex ?? this.editingTokenIndex),
      isReplacingEditedToken:
          isReplacingEditedToken ?? this.isReplacingEditedToken,
    );
  }

  @override
  String toString() =>
      'CalculatorState(expr: "$expressionText", res: "$resultText", prev: "$previewText", editIdx: $editingTokenIndex, err: $error, evaluated: $justEvaluated)';
}
