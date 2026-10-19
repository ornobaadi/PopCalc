/// Typed calculator errors.
///
/// Each one has a small pool of [messages] shown in the big numerals, one
/// at a time, so a mistake reads as a wink rather than a scolding. They are
/// drawn in Bebas Neue (capitals only) and have to fit the display, so keep
/// them in capitals and under about 18 characters. [plainMessage] is the
/// sober reason, for screen readers.
enum CalcError {
  divideByZero(
    "Can't divide by zero",
    ['ZERO SAYS NO', 'NOT BY ZERO', 'NICE TRY', 'INFINITY? NOPE', "CAN'T SPLIT NOTHING"],
  ),

  /// 0 ÷ 0: not merely impossible, but meaningless.
  zeroByZero(
    'Zero divided by zero is undefined',
    ['NOTHING ÷ NOTHING', '0 ÷ 0? PHILOSOPHY', 'ASK A PHILOSOPHER'],
  ),
  overflow(
    'The result is too large',
    _overflowSetups,
    punchlines: {..._overflowSetups},
  ),

  /// √ of a negative, or a negative number to a fractional power.
  negativeRoot(
    'No real root of a negative number',
    ["THAT'S IMAGINARY", 'NO REAL ROOT', 'ROOTS HATE MINUS'],
  ),

  /// ln or log of zero or a negative.
  badLog(
    'Logarithms need a number above zero',
    ['LOGS NEED MORE', 'LOG SAYS NO', "CAN'T LOG THAT"],
  ),

  /// sin⁻¹ or cos⁻¹ outside −1 to 1.
  badInverseTrig(
    'Inverse sine and cosine need a value from -1 to 1',
    ['OUT OF RANGE', '-1 TO 1 ONLY', 'TOO FAR OUT'],
  ),

  /// tan 90°, tan π/2.
  tanUndefined(
    'Tangent is not defined at this angle',
    ['TAN WENT VERTICAL', 'STRAIGHT UP. NOPE', 'OFF THE CHART'],
  ),

  /// 2.5!, (-3)!.
  badFactorial(
    'Factorial needs a whole number, zero or above',
    ['WHOLE NUMBERS ONLY', "CAN'T ! THAT", '! NEEDS A WHOLE'],
  ),
  invalidExpression(
    'This is not a complete calculation',
    ["THAT'S NOT MATH", 'COME AGAIN?', 'TYPO, PROBABLY', 'HMM. NO'],
  );

  final String plainMessage;
  final List<String> messages;

  /// Lines that are an innocent-sounding setup: the screen tags them with
  /// [kThatsWhatSheSaid] instead of the plain reason (The Office).
  final Set<String> punchlines;
  const CalcError(this.plainMessage, this.messages, {this.punchlines = const {}});
}

const _overflowSetups = [
  "IT WON'T FIT",
  "THAT'S HUGE",
  'WAY TOO BIG',
  'TOO HARD TO HANDLE',
  "I CAN'T TAKE IT ALL",
  'HOW IS IT THIS BIG',
  "THAT'S TOO LONG",
  "OKAY, THAT'S A LOT",
  "IT'S SO MUCH BIGGER",
  "I WASN'T READY",
  "THAT'S WAY TOO MUCH",
  'NEED BIGGER SCREEN',
  'HOW DO I FIT IT ALL',
  "IT'S OUT OF HAND",
];

const kThatsWhatSheSaid = "(That's what she said)";
