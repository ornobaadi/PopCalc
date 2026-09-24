import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/expression.dart';

class CalculatorState {
  final Expression expression;
  final String expressionText;
  final String resultText;
  final String? previewText;
  final CalcError? error;
  final bool justEvaluated;

  const CalculatorState({
    this.expression = const Expression(),
    this.expressionText = '',
    this.resultText = '0',
    this.previewText,
    this.error,
    this.justEvaluated = false,
  });

  CalculatorState copyWith({
    Expression? expression,
    String? expressionText,
    String? resultText,
    String? previewText,
    bool clearPreview = false,
    CalcError? error,
    bool clearError = false,
    bool? justEvaluated,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      expressionText: expressionText ?? this.expressionText,
      resultText: resultText ?? this.resultText,
      previewText: clearPreview ? null : (previewText ?? this.previewText),
      error: clearError ? null : (error ?? this.error),
      justEvaluated: justEvaluated ?? this.justEvaluated,
    );
  }

  @override
  String toString() =>
      'CalculatorState(expr: "$expressionText", res: "$resultText", prev: "$previewText", err: $error, evaluated: $justEvaluated)';
}
