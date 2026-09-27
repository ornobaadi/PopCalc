import 'package:decimal/decimal.dart';

/// Formats numbers and expressions for display.
class NumberFormatter {
  static const int maxSignificantDigits = 15;

  /// Formats a [Decimal] into a human-readable string.
  /// Formats with thousands separators, trims trailing zeros,
  /// and switches to scientific notation if the length exceeds [maxSignificantDigits].
  static String format(Decimal value) {
    // Integer digits of |value| decide how many decimals fit in the cap.
    final intDigits = value.abs().truncate().toString().length;

    if (intDigits > maxSignificantDigits) {
      return _scientific(value, intDigits - 1);
    }

    // Round (not truncate) so 1 ÷ 3 × 3 shows 1, not 0.999999999999.
    final rounded = value.round(scale: maxSignificantDigits - intDigits);
    if (rounded == Decimal.zero) {
      return '0'; // Also avoids displaying "-0" for tiny negatives.
    }

    final isNegative = rounded < Decimal.zero;
    final absValue = isNegative ? -rounded : rounded;

    String s = absValue.toString();
    final parts = s.split('.');
    final integerPart = parts[0];
    final fractionalPart = parts.length > 1 ? parts[1] : '';

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

  /// Scientific notation computed from the exact decimal, so huge values
  /// never overflow to "Infinity" the way a double conversion would.
  static String _scientific(Decimal value, int exponent) {
    final isNegative = value < Decimal.zero;
    final digits = value.abs().truncate().toString();
    var mantissa = Decimal.parse('${digits[0]}.${digits.substring(1)}')
        .round(scale: 6);
    if (mantissa >= Decimal.ten) {
      mantissa = Decimal.one;
      exponent += 1;
    }
    var m = mantissa.toString();
    if (m.contains('.')) {
      m = m.replaceFirst(RegExp(r'\.?0+$'), '');
    }
    return '${isNegative ? '-' : ''}${m}e$exponent';
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
