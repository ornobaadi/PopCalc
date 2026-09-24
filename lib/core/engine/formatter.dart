import 'package:decimal/decimal.dart';

/// Formats numbers and expressions for display.
class NumberFormatter {
  static const int maxSignificantDigits = 15;

  /// Formats a [Decimal] into a human-readable string.
  /// Formats with thousands separators, trims trailing zeros,
  /// and switches to scientific notation if the length exceeds [maxSignificantDigits].
  static String format(Decimal value) {
    if (value == Decimal.zero) {
      return '0';
    }

    final isNegative = value < Decimal.zero;
    final absValue = isNegative ? -value : value;

    // Convert to string representation
    String s = absValue.toString();

    // Check if integer part is extremely large (>= 1e15)
    final parts = s.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

    if (integerPart.length > maxSignificantDigits) {
      // Use scientific notation
      final doubleVal = value.toDouble();
      return doubleVal.toStringAsExponential(6).replaceAll('+', '');
    }

    // Format integer part with commas
    final formattedInt = _addCommas(integerPart);

    if (fractionalPart.isEmpty) {
      return isNegative ? '-$formattedInt' : formattedInt;
    }

    // Trim trailing zeros from fractional part
    String trimmedFrac = fractionalPart;
    while (trimmedFrac.endsWith('0')) {
      trimmedFrac = trimmedFrac.substring(0, trimmedFrac.length - 1);
    }

    if (trimmedFrac.isEmpty) {
      return isNegative ? '-$formattedInt' : formattedInt;
    }

    // Cap total displayed digits if needed
    final totalDigits = integerPart.length + trimmedFrac.length;
    if (totalDigits > maxSignificantDigits) {
      final allowedFrac = maxSignificantDigits - integerPart.length;
      if (allowedFrac > 0) {
        trimmedFrac = trimmedFrac.substring(0, allowedFrac);
        while (trimmedFrac.endsWith('0')) {
          trimmedFrac = trimmedFrac.substring(0, trimmedFrac.length - 1);
        }
      } else {
        trimmedFrac = '';
      }
    }

    final result = trimmedFrac.isNotEmpty ? '$formattedInt.$trimmedFrac' : formattedInt;
    return isNegative ? '-$result' : result;
  }

  /// Formats an input number string with commas while typing (e.g. "1024" -> "1,024")
  static String formatInputNumber(String raw) {
    if (raw.isEmpty) return '0';
    final isNegative = raw.startsWith('-');
    final clean = isNegative ? raw.substring(1) : raw;

    final dotIndex = clean.indexOf('.');
    if (dotIndex == -1) {
      final formatted = _addCommas(clean);
      return isNegative ? '-$formatted' : formatted;
    } else {
      final intPart = clean.substring(0, dotIndex);
      final fracPart = clean.substring(dotIndex); // includes '.'
      final formatted = _addCommas(intPart);
      return isNegative ? '-$formatted$fracPart' : '$formatted$fracPart';
    }
  }

  static String _addCommas(String intDigits) {
    if (intDigits.isEmpty) return '0';
    final buffer = StringBuffer();
    final len = intDigits.length;
    for (int i = 0; i < len; i++) {
      if (i > 0 && (len - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(intDigits[i]);
    }
    return buffer.toString();
  }
}
