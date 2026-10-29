import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:popcalc/core/storage/rates_store.dart';
import 'package:rational/rational.dart';
import 'package:popcalc/core/units/currency.dart';
import 'package:popcalc/core/units/units.dart';
import 'package:popcalc/features/converter/application/converter_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A response in the rate service's shape, with BDT at [bdt] per dollar.
String ratesJson(String date, {double bdt = 120.0, Set<String> drop = const {}}) {
  return jsonEncode({
    'date': date,
    'usd': {
      for (final c in Currency.all)
        if (!drop.contains(c.code))
          c.code.toLowerCase(): c.code == 'USD'
              ? 1
              : c.code == 'BDT'
              ? bdt
              : 2.5,
      'xau': 0.0004, // extra entries are ignored
    },
  });
}

/// Rates newer than anything the app ships with.
const later = '2099-01-02';

String convert(String value, String from, String to) {
  final c = Units.byId(Currency.categoryId);
  return Currency.round(
    Units.convert(Decimal.parse(value), c.unit(from), c.unit(to)),
  ).toString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => Units.setCurrencyRates(CurrencyRates.bundled));

  group('Bundled rates', () {
    test('every listed currency has a positive rate', () {
      final rates = CurrencyRates.bundled;
      for (final c in Currency.all) {
        expect(rates.perUsd[c.code], isNotNull, reason: c.code);
        expect(rates.perUsd[c.code]! > Rational.zero, isTrue, reason: c.code);
      }
      expect(rates.perUsd['USD'], Rational.one);
    });

    test('Currency is a converter category from the start', () {
      final category = Units.byId(Currency.categoryId);
      expect(category.name, 'Currency');
      expect(category.units.length, Currency.all.length);
      expect(convert('1', 'usd', 'usd'), '1');
    });

    test('the other categories still convert exactly', () {
      final length = Units.byId('length');
      expect(
        Units.convert(Decimal.one, length.unit('in'), length.unit('cm')),
        Decimal.parse('2.54'),
      );
    });
  });

  group('Parsing', () {
    test('reads the service response', () {
      final rates = CurrencyRates.tryParse(ratesJson(later, bdt: 123.5))!;
      expect(rates.date, DateTime(2099, 1, 2));
      expect(rates.perUsd['BDT'], Decimal.parse('123.5').toRational());
      expect(rates.perUsd.length, Currency.all.length);
    });

    test('survives being saved and read back', () {
      final rates = CurrencyRates.tryParse(ratesJson(later, bdt: 123.5))!;
      final again = CurrencyRates.tryParse(rates.toJson())!;
      expect(again.date, rates.date);
      expect(again.perUsd['BDT'], rates.perUsd['BDT']);
    });

    test('rejects anything incomplete or broken', () {
      expect(CurrencyRates.tryParse(''), isNull);
      expect(CurrencyRates.tryParse('<html>offline</html>'), isNull);
      expect(CurrencyRates.tryParse('{"date":"2099-01-02"}'), isNull);
      expect(CurrencyRates.tryParse(ratesJson('not a date')), isNull);
      expect(CurrencyRates.tryParse(ratesJson(later, drop: {'EUR'})), isNull);
      expect(CurrencyRates.tryParse(ratesJson(later, bdt: 0)), isNull);
      expect(CurrencyRates.tryParse(ratesJson(later, bdt: -5)), isNull);
    });
  });

  group('Converting', () {
    setUp(() {
      Units.setCurrencyRates(
        CurrencyRates.tryParse(ratesJson(later, bdt: 120))!,
      );
    });

    test('uses the rate, both ways', () {
      expect(convert('10', 'usd', 'bdt'), '1200');
      expect(convert('1200', 'bdt', 'usd'), '10');
    });

    test('goes through the dollar between two other currencies', () {
      // 2.5 EUR = 1 USD = 120 BDT
      expect(convert('5', 'eur', 'bdt'), '240');
    });

    test('rounds like money, keeping small values visible', () {
      expect(convert('1', 'usd', 'eur'), '2.5');
      expect(convert('1', 'bdt', 'usd'), '0.008333');
      expect(Currency.round(Decimal.parse('12.3456')).toString(), '12.35');
      expect(Currency.round(Decimal.parse('0.12345678')).toString(), '0.1235');
    });
  });

  group('Refreshing', () {
    late int calls;

    ProviderContainer container(http.Client client) {
      final c = ProviderContainer(
        overrides: [httpClientProvider.overrideWithValue(client)],
      );
      addTearDown(c.dispose);
      return c;
    }

    setUp(() {
      calls = 0;
      SharedPreferences.setMockInitialValues({});
    });

    test('never goes online by itself', () async {
      final c = container(
        MockClient((_) async {
          calls++;
          return http.Response('', 500);
        }),
      );
      c.read(ratesProvider);
      c.read(converterProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(calls, 0);
      expect(c.read(ratesProvider).rates.date, CurrencyRates.bundled.date);
      expect(c.read(ratesProvider).status, RatesStatus.idle);
    });

    test('success replaces, saves and reaches the converter', () async {
      final c = container(
        MockClient((_) async => http.Response(ratesJson(later, bdt: 150), 200)),
      );
      final converter = c.read(converterProvider.notifier);
      converter.selectCategory(Units.byId(Currency.categoryId));
      converter.onDigit('2');

      expect(await c.read(ratesProvider.notifier).refresh(), isTrue);
      expect(c.read(ratesProvider).status, RatesStatus.updated);
      expect(c.read(ratesProvider).rates.date, DateTime(2099, 1, 2));
      // USD -> BDT is the default pair; the open converter picked it up.
      expect(c.read(converterProvider).outputText, '300');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('currency_rates_json'), contains('2099-01-02'));
    });

    test('falls back to the mirror when the first source fails', () async {
      final c = container(
        MockClient((request) async {
          calls++;
          return request.url.host.contains('jsdelivr')
              ? http.Response('nope', 503)
              : http.Response(ratesJson(later), 200);
        }),
      );
      expect(await c.read(ratesProvider.notifier).refresh(), isTrue);
      expect(calls, 2);
    });

    test('failure keeps the rates already in use', () async {
      for (final client in [
        MockClient((_) async => throw const FormatException('offline')),
        MockClient((_) async => http.Response('<html>login</html>', 200)),
        MockClient(
          (_) async => http.Response(ratesJson(later, drop: {'INR'}), 200),
        ),
        // Older than what is already in use.
        MockClient((_) async => http.Response(ratesJson('2001-01-01'), 200)),
      ]) {
        final c = container(client);
        expect(await c.read(ratesProvider.notifier).refresh(), isFalse);
        expect(c.read(ratesProvider).status, RatesStatus.failed);
        expect(c.read(ratesProvider).rates.date, CurrencyRates.bundled.date);
      }
    });

    test('saved rates load on start, unless the app ships newer ones', () async {
      final client = MockClient((_) async => http.Response('', 500));

      SharedPreferences.setMockInitialValues({
        'currency_rates_json': ratesJson(later, bdt: 200),
      });
      final newer = container(client);
      newer.read(ratesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(newer.read(ratesProvider).rates.date, DateTime(2099, 1, 2));

      Units.setCurrencyRates(CurrencyRates.bundled);
      SharedPreferences.setMockInitialValues({
        'currency_rates_json': ratesJson('2001-01-01'),
      });
      final older = container(client);
      older.read(ratesProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(older.read(ratesProvider).rates.date, CurrencyRates.bundled.date);
    });
  });
}
