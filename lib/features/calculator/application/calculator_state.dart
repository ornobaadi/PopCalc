import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/expression.dart';

class CalculatorState {
  final Expression expression;
  final String expressionText;
  final String resultText;
  final String? previewText;
  final CalcError? error;

  /// Small line under the hero: replaces an error's plain reason, or
  /// stands alone under a headline (the hunt). Lasts until the next change.
  final String? errorNote;

  /// The error's line is a setup: tag it "(That's what she said)".
  /// Like [errorNote], lasts until the next change.
  final bool errorPunchline;
  final bool justEvaluated;
  final int? editingTokenIndex;
  final bool isReplacingEditedToken;

  /// Increments on every successful `=` evaluation to trigger the celebration.
  final int celebrationId;

  const CalculatorState({
    this.expression = const Expression(),
    this.expressionText = '',
    this.resultText = '0',
    this.previewText,
    this.error,
    this.errorNote,
    this.errorPunchline = false,
    this.justEvaluated = false,
    this.editingTokenIndex,
    this.isReplacingEditedToken = false,
    this.celebrationId = 0,
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
    String? errorNote,
    bool errorPunchline = false,
    bool? justEvaluated,
    int? editingTokenIndex,
    bool clearEditingTokenIndex = false,
    bool? isReplacingEditedToken,
    int? celebrationId,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      expressionText: expressionText ?? this.expressionText,
      resultText: resultText ?? this.resultText,
      previewText: clearPreview ? null : (previewText ?? this.previewText),
      error: clearError ? null : (error ?? this.error),
      // Never carried over: it belongs to the moment it was set.
      errorNote: errorNote,
      errorPunchline: errorPunchline,
      justEvaluated: justEvaluated ?? this.justEvaluated,
      editingTokenIndex: clearEditingTokenIndex
          ? null
          : (editingTokenIndex ?? this.editingTokenIndex),
      isReplacingEditedToken:
          isReplacingEditedToken ?? this.isReplacingEditedToken,
      celebrationId: celebrationId ?? this.celebrationId,
    );
  }

  @override
  String toString() =>
      'CalculatorState(expr: "$expressionText", res: "$resultText", prev: "$previewText", editIdx: $editingTokenIndex, err: $error, evaluated: $justEvaluated)';
}
