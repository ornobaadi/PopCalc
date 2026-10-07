import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/units/units.dart';
import 'package:popcalc/features/converter/application/converter_controller.dart';

String convert(String value, String category, String from, String to) {
  final c = Units.byId(category);
  return NumberFormatter.format(
      Units.convert(Decimal.parse(value), c.unit(from), c.unit(to)));
}

void main() {
  group('Exact conversions', () {
    test('1 in = 2.54 cm', () => expect(convert('1', 'length', 'in', 'cm'), '2.54'));
    test('1 mi = 1.609344 km',
        () => expect(convert('1', 'length', 'mi', 'km'), '1.609344'));
    test('1 lb = 453.59237 g',
        () => expect(convert('1', 'mass', 'lb', 'g'), '453.59237'));
    test('100 km/h = 27.7… m/s',
        () => expect(convert('100', 'speed', 'kph', 'mps'), '27.7777777777778'));
    test('1 GiB = 1,073.741824 MB',
        () => expect(convert('1', 'data', 'gib', 'mb'), '1,073.741824'));
    test('1 gal = 3.785411784 L',
        () => expect(convert('1', 'volume', 'gal', 'l'), '3.785411784'));
    test('1 acre = 43,560 ft²',
        () => expect(convert('1', 'area', 'acre', 'ft2'), '43,560'));
    test('1 kWh = 3,600 kJ',
        () => expect(convert('1', 'energy', 'kwh', 'kj'), '3,600'));
    test('1 atm = 1.01325 bar',
        () => expect(convert('1', 'pressure', 'atm', 'bar'), '1.01325'));
  });

  group('Temperature', () {
    test('0 °C = 32 °F', () => expect(convert('0', 'temperature', 'c', 'f'), '32'));
    test('100 °C = 212 °F',
        () => expect(convert('100', 'temperature', 'c', 'f'), '212'));
    test('-40 °F = -40 °C',
        () => expect(convert('-40', 'temperature', 'f', 'c'), '-40'));
    test('0 K = -273.15 °C',
        () => expect(convert('0', 'temperature', 'k', 'c'), '-273.15'));
    test('98.6 °F = 37 °C',
        () => expect(convert('98.6', 'temperature', 'f', 'c'), '37'));
  });

  test('every category has its default units and unique ids', () {
    for (final c in Units.categories) {
      expect(c.unit(c.defaultFrom), isNotNull);
      expect(c.unit(c.defaultTo), isNotNull);
      expect(c.units.map((u) => u.id).toSet().length, c.units.length,
          reason: c.id);
    }
  });

  group('ConverterController', () {
    late ConverterController c;
    setUp(() => c = ConverterController(persist: false));

    test('typing converts live', () {
      c.onDigit('1');
      c.onDigit('0');
      expect(c.state.inputText, '10');
      expect(c.state.outputText, '6.21371192237334'); // km → mi
    });

    test('empty input shows 0 → 0', () {
      expect(c.state.inputText, '0');
      expect(c.state.outputText, '0');
    });

    test('swap carries the converted value', () {
      c.selectCategory(Units.byId('length'));
      c.setFrom(Units.byId('length').unit('in'));
      c.setTo(Units.byId('length').unit('cm'));
      c.onDigit('2');
      c.swap();
      expect(c.state.from.id, 'cm');
      expect(c.state.to.id, 'in');
      expect(c.state.input, '5.08');
      expect(c.state.outputText, '2');
    });

    test('picking the other side\'s unit swaps them', () {
      final length = Units.byId('length');
      c.selectCategory(length);
      c.setFrom(length.unit('mi'));
      expect(c.state.from.id, 'mi');
      expect(c.state.to.id, 'km');
    });

    test('changing category keeps the typed number', () {
      c.onDigit('5');
      c.selectCategory(Units.byId('temperature'));
      expect(c.state.input, '5');
      expect(c.state.outputText, '41');
    });

    test('sign, decimal and backspace', () {
      c.onDigit('4');
      c.onDecimal();
      c.onDigit('5');
      c.onToggleSign();
      expect(c.state.input, '-4.5');
      c.onBackspace();
      expect(c.state.input, '-4.');
      c.onClear();
      expect(c.state.input, '');
    });

    test('loadValue takes a calculator answer', () {
      c.loadValue('1,234.5');
      expect(c.state.input, '1234.5');
      c.loadValue('Not defined');
      expect(c.state.input, '1234.5');
    });
  });
}
