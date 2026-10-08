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
const _bundledDate = '2026-10-08';
const _bundledPerUsd = <String, String>{
  'USD': '1',
  'EUR': '0.89246269',
  'GBP': '0.75717014',
  'BDT': '123.11617034',
  'INR': '96.75640102',
  'PKR': '276.71502876',
  'LKR': '330.63012984',
  'NPR': '154.88280893',
  'JPY': '158.22434618',
  'CNY': '6.70331167',
  'KRW': '1337.42685607',
  'SGD': '1.28041753',
  'MYR': '4.0874844',
  'THB': '33.63708636',
  'IDR': '17898.1820002',
  'PHP': '62.78001379',
  'VND': '25921.59847985',
  'AED': '3.6725',
  'SAR': '3.75',
  'QAR': '3.64',
  'KWD': '0.31057123',
  'TRY': '49.2143635',
  'CAD': '1.42619842',
  'AUD': '1.4376884',
  'NZD': '1.7849449',
  'CHF': '0.83307984',
  'SEK': '9.99556841',
  'RUB': '85.49785925',
  'BRL': '5.01540823',
  'MXN': '17.98422175',
  'ZAR': '16.63600395',
  'EGP': '52.37271645',
  'NGN': '1329.30541158',
};
// END bundled rates
