import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

import 'units.dart';

/// Currencies for the converter's Currency tab.
/// PURE DART - No Flutter imports allowed in core/units.
///
/// Unlike every other category, the factors are not exact: they are market
/// rates that change daily. A snapshot ships in the app ([CurrencyRates
/// .bundled]) so the tab works with no connection; newer rates can replace it
/// at runtime (see `core/storage/rates_store.dart`).
class Currency {
  final String code; // ISO 4217, upper case
  final String name;

  const Currency(this.code, this.name);

  /// Id of the converter category these become.
  static const categoryId = 'currency';

  /// The currencies offered. `tool/update_rates.py` reads the codes from
  /// this list, so adding one here is enough; then re-run the tool.
  static const all = <Currency>[
    Currency('USD', 'US Dollar'),
    Currency('EUR', 'Euro'),
    Currency('GBP', 'British Pound'),
    Currency('BDT', 'Bangladeshi Taka'),
    Currency('INR', 'Indian Rupee'),
    Currency('PKR', 'Pakistani Rupee'),
    Currency('LKR', 'Sri Lankan Rupee'),
    Currency('NPR', 'Nepalese Rupee'),
    Currency('JPY', 'Japanese Yen'),
    Currency('CNY', 'Chinese Yuan'),
    Currency('KRW', 'South Korean Won'),
    Currency('SGD', 'Singapore Dollar'),
    Currency('MYR', 'Malaysian Ringgit'),
    Currency('THB', 'Thai Baht'),
    Currency('IDR', 'Indonesian Rupiah'),
    Currency('PHP', 'Philippine Peso'),
    Currency('VND', 'Vietnamese Dong'),
    Currency('AED', 'UAE Dirham'),
    Currency('SAR', 'Saudi Riyal'),
    Currency('QAR', 'Qatari Riyal'),
    Currency('KWD', 'Kuwaiti Dinar'),
    Currency('TRY', 'Turkish Lira'),
    Currency('CAD', 'Canadian Dollar'),
    Currency('AUD', 'Australian Dollar'),
    Currency('NZD', 'New Zealand Dollar'),
    Currency('CHF', 'Swiss Franc'),
    Currency('SEK', 'Swedish Krona'),
    Currency('RUB', 'Russian Rouble'),
    Currency('BRL', 'Brazilian Real'),
    Currency('MXN', 'Mexican Peso'),
    Currency('ZAR', 'South African Rand'),
    Currency('EGP', 'Egyptian Pound'),
    Currency('NGN', 'Nigerian Naira'),
  ];

  /// The flag for a currency's country (the EU's for the euro), drawn by
  /// the phone's emoji font from the code's first two letters.
  static bool isCode(String code) => all.any((c) => c.code == code);

  static String flag(String code) {
    final c = code.toUpperCase();
    if (c.length != 3) return '';
    return String.fromCharCodes([
      0x1F1E6 + c.codeUnitAt(0) - 0x41,
      0x1F1E6 + c.codeUnitAt(1) - 0x41,
    ]);
  }

  /// The sign written before an amount, for the ones people know by sight.
  static const signs = {
    'USD': r'$',
    'EUR': '€',
    'GBP': '£',
    'BDT': '৳',
    'INR': '₹',
    'PKR': 'Rs',
    'LKR': 'Rs',
    'NPR': 'Rs',
    'JPY': '¥',
    'CNY': '¥',
    'KRW': '₩',
    'THB': '฿',
    'PHP': '₱',
    'VND': '₫',
    'TRY': '₺',
    'RUB': '₽',
    'NGN': '₦',
    'BRL': r'R$',
    'ZAR': 'R',
    'IDR': 'Rp',
    'MYR': 'RM',
    'CHF': 'Fr',
    'EGP': 'E£',
    'SGD': r'S$',
    'CAD': r'C$',
    'AUD': r'A$',
    'NZD': r'NZ$',
    'MXN': r'MX$',
    'SEK': 'kr',
  };

  /// Rates are approximate, so results show money-style precision rather
  /// than the converter's usual exact digits: 2 decimals, more for small
  /// values so a weak currency does not round to nothing.
  static Decimal round(Decimal value) {
    final size = value.abs();
    if (size >= Decimal.one) return value.round(scale: 2);
    if (size >= Decimal.parse('0.01')) return value.round(scale: 4);
    return value.round(scale: 6);
  }
}

/// How many units of each currency one US dollar buys, on [date].
class CurrencyRates {
  final DateTime date;
  final Map<String, Rational> perUsd; // keyed by upper-case code

  const CurrencyRates._(this.date, this.perUsd);

  /// The rates that ship with the app.
  static final CurrencyRates bundled = CurrencyRates._(
    DateTime.parse(_bundledDate),
    {
      for (final entry in _bundledPerUsd.entries)
        entry.key: Rational.parse(entry.value),
    },
  );

  /// Parses the rate service's response:
  /// `{"date": "2026-10-08", "usd": {"bdt": 123.1, "eur": 0.89, ...}}`.
  ///
  /// Returns null unless the date is valid and every listed currency has a
  /// positive rate, so a broken or partial response can never replace good
  /// rates.
  static CurrencyRates? tryParse(String json) {
    try {
      final data = jsonDecode(json);
      if (data is! Map) return null;
      final date = DateTime.tryParse('${data['date']}');
      final usd = data['usd'];
      if (date == null || usd is! Map) return null;

      final rates = <String, Rational>{};
      for (final currency in Currency.all) {
        final raw = usd[currency.code.toLowerCase()];
        if (raw is! num || !raw.isFinite || raw <= 0) return null;
        final decimal = Decimal.tryParse(raw.toString());
        if (decimal == null) return null;
        rates[currency.code] = decimal.toRational();
      }
      if (rates['USD'] != Rational.one) return null;
      return CurrencyRates._(date, rates);
    } catch (_) {
      return null;
    }
  }

  /// The same shape [tryParse] reads, for saving on the device.
  String toJson() => jsonEncode({
    'date': date.toIso8601String().substring(0, 10),
    'usd': {
      for (final entry in perUsd.entries)
        entry.key.toLowerCase(): entry.value.toDouble(),
    },
  });

  /// These rates as a converter category, with the US dollar as its base:
  /// "value in USD = x × (1 / rate)".
  UnitCategory toCategory() => UnitCategory(
    Currency.categoryId,
    'Currency',
    [
      for (final currency in Currency.all)
        Unit(
          currency.code.toLowerCase(),
          currency.name,
          currency.code,
          perUsd[currency.code]!.inverse,
        ),
    ],
    defaultFrom: 'usd',
    defaultTo: 'bdt',
  );
}

// BEGIN bundled rates (written by tool/update_rates.py; do not edit by hand)
const _bundledDate = '2026-10-28';
const _bundledPerUsd = <String, String>{
  'USD': '1',
  'EUR': '0.89912268',
  'GBP': '0.75212496',
  'BDT': '124.13600097',
  'INR': '95.14009092',
  'PKR': '277.15527775',
  'LKR': '332.61767286',
  'NPR': '152.29550053',
  'JPY': '157.82921435',
  'CNY': '6.66763882',
  'KRW': '1342.15524726',
  'SGD': '1.2818442',
  'MYR': '4.08262468',
  'THB': '33.81667707',
  'IDR': '18174.23354809',
  'PHP': '63.99340051',
  'VND': '25801.99322409',
  'AED': '3.6725',
  'SAR': '3.75',
  'QAR': '3.64',
  'KWD': '0.31113203',
  'TRY': '49.82582198',
  'CAD': '1.40646342',
  'AUD': '1.4219191',
  'NZD': '1.7832984',
  'CHF': '0.8298767',
  'SEK': '9.95435183',
  'RUB': '80.49093792',
  'BRL': '5.35218539',
  'MXN': '18.69096305',
  'ZAR': '16.66746888',
  'EGP': '56.11961073',
  'NGN': '1341.62892744',
};
// END bundled rates
