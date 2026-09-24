/// Typed calculator errors.
enum CalcError {
  divideByZero,
  overflow,
  invalidExpression;

  String get userMessage {
    switch (this) {
      case CalcError.divideByZero:
        return "Can't divide by zero";
      case CalcError.overflow:
        return "Overflow";
      case CalcError.invalidExpression:
        return "Error";
    }
  }
}
