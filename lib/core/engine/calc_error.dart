/// Typed calculator errors.
enum CalcError {
  divideByZero,
  overflow,
  invalidExpression,
  /// Outside a function's domain: √ of a negative, ln 0, tan 90°, 2.5!.
  domainError;

  String get userMessage {
    switch (this) {
      case CalcError.divideByZero:
        return "Can't divide by zero";
      case CalcError.overflow:
        return "Overflow";
      case CalcError.invalidExpression:
        return "Error";
      case CalcError.domainError:
        return "Not defined";
    }
  }
}
