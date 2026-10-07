import 'package:decimal/decimal.dart';
import 'package:rational/rational.dart';

/// Unit definitions and exact conversion.
/// PURE DART - No Flutter imports allowed in core/units.
///
/// Every unit is "value in the category's base unit = x × factor + offset".
/// Factors are exact rationals (1 in = 0.0254 m by definition), so
/// conversions keep the calculator's exact-decimal promise. Only
/// temperature uses an offset.
class Unit {
  final String id;
  final String name;
  final String symbol;
  final Rational factor;
  final Rational offset;

  Unit(this.id, this.name, this.symbol, this.factor, [Rational? offset])
    : offset = offset ?? Rational.zero;

  @override
  String toString() => 'Unit($id)';
}

class UnitCategory {
  final String id;
  final String name;
  final List<Unit> units;

  /// Default "from" and "to" units when the category is opened.
  final String defaultFrom;
  final String defaultTo;

  UnitCategory(
    this.id,
    this.name,
    this.units, {
    required this.defaultFrom,
    required this.defaultTo,
  });

  Unit unit(String id) => units.firstWhere((u) => u.id == id);
}

Rational _r(String decimal) => Rational.parse(decimal);
Rational _f(int numerator, int denominator) =>
    Rational(BigInt.from(numerator), BigInt.from(denominator));

class Units {
  /// Converts [value] from one unit to another in the same category.
  static Decimal convert(Decimal value, Unit from, Unit to) {
    final base = value.toRational() * from.factor + from.offset;
    final result = (base - to.offset) / to.factor;
    return result.toDecimal(scaleOnInfinitePrecision: 32);
  }

  static UnitCategory byId(String id) =>
      categories.firstWhere((c) => c.id == id, orElse: () => categories.first);

  static final List<UnitCategory> categories = [
    UnitCategory(
      'length',
      'Length',
      [
        Unit('mm', 'Millimetre', 'mm', _r('0.001')),
        Unit('cm', 'Centimetre', 'cm', _r('0.01')),
        Unit('m', 'Metre', 'm', Rational.one),
        Unit('km', 'Kilometre', 'km', _r('1000')),
        Unit('in', 'Inch', 'in', _r('0.0254')),
        Unit('ft', 'Foot', 'ft', _r('0.3048')),
        Unit('yd', 'Yard', 'yd', _r('0.9144')),
        Unit('mi', 'Mile', 'mi', _r('1609.344')),
        Unit('nmi', 'Nautical mile', 'nmi', _r('1852')),
      ],
      defaultFrom: 'km',
      defaultTo: 'mi',
    ),
    UnitCategory(
      'mass',
      'Weight',
      [
        Unit('mg', 'Milligram', 'mg', _r('0.000001')),
        Unit('g', 'Gram', 'g', _r('0.001')),
        Unit('kg', 'Kilogram', 'kg', Rational.one),
        Unit('t', 'Tonne', 't', _r('1000')),
        Unit('oz', 'Ounce', 'oz', _r('0.028349523125')),
        Unit('lb', 'Pound', 'lb', _r('0.45359237')),
        Unit('st', 'Stone', 'st', _r('6.35029318')),
      ],
      defaultFrom: 'kg',
      defaultTo: 'lb',
    ),
    UnitCategory(
      'temperature',
      'Temp',
      [
        Unit('c', 'Celsius', '°C', Rational.one, _r('273.15')),
        Unit('f', 'Fahrenheit', '°F', _f(5, 9), _r('459.67') * _f(5, 9)),
        Unit('k', 'Kelvin', 'K', Rational.one),
      ],
      defaultFrom: 'c',
      defaultTo: 'f',
    ),
    UnitCategory(
      'volume',
      'Volume',
      [
        Unit('ml', 'Millilitre', 'mL', _r('0.001')),
        Unit('l', 'Litre', 'L', Rational.one),
        Unit('m3', 'Cubic metre', 'm³', _r('1000')),
        Unit('tsp', 'Teaspoon (US)', 'tsp', _r('0.00492892159375')),
        Unit('tbsp', 'Tablespoon (US)', 'tbsp', _r('0.01478676478125')),
        Unit('floz', 'Fluid ounce (US)', 'fl oz', _r('0.0295735295625')),
        Unit('cup', 'Cup (US)', 'cup', _r('0.2365882365')),
        Unit('pt', 'Pint (US)', 'pt', _r('0.473176473')),
        Unit('qt', 'Quart (US)', 'qt', _r('0.946352946')),
        Unit('gal', 'Gallon (US)', 'gal', _r('3.785411784')),
        Unit('galuk', 'Gallon (UK)', 'gal UK', _r('4.54609')),
        Unit('in3', 'Cubic inch', 'in³', _r('0.016387064')),
        Unit('ft3', 'Cubic foot', 'ft³', _r('28.316846592')),
      ],
      defaultFrom: 'l',
      defaultTo: 'gal',
    ),
    UnitCategory(
      'area',
      'Area',
      [
        Unit('cm2', 'Square centimetre', 'cm²', _r('0.0001')),
        Unit('m2', 'Square metre', 'm²', Rational.one),
        Unit('ha', 'Hectare', 'ha', _r('10000')),
        Unit('km2', 'Square kilometre', 'km²', _r('1000000')),
        Unit('in2', 'Square inch', 'in²', _r('0.00064516')),
        Unit('ft2', 'Square foot', 'ft²', _r('0.09290304')),
        Unit('yd2', 'Square yard', 'yd²', _r('0.83612736')),
        Unit('acre', 'Acre', 'ac', _r('4046.8564224')),
        Unit('mi2', 'Square mile', 'mi²', _r('2589988.110336')),
      ],
      defaultFrom: 'm2',
      defaultTo: 'ft2',
    ),
    UnitCategory(
      'speed',
      'Speed',
      [
        Unit('mps', 'Metres per second', 'm/s', Rational.one),
        Unit('kph', 'Kilometres per hour', 'km/h', _f(5, 18)),
        Unit('mph', 'Miles per hour', 'mph', _r('0.44704')),
        Unit('kn', 'Knot', 'kn', _f(463, 900)),
        Unit('fps', 'Feet per second', 'ft/s', _r('0.3048')),
      ],
      defaultFrom: 'kph',
      defaultTo: 'mph',
    ),
    UnitCategory(
      'time',
      'Time',
      [
        Unit('ms', 'Millisecond', 'ms', _r('0.001')),
        Unit('s', 'Second', 's', Rational.one),
        Unit('min', 'Minute', 'min', _r('60')),
        Unit('h', 'Hour', 'h', _r('3600')),
        Unit('d', 'Day', 'd', _r('86400')),
        Unit('wk', 'Week', 'wk', _r('604800')),
        Unit('yr', 'Year (365.25 d)', 'yr', _r('31557600')),
      ],
      defaultFrom: 'h',
      defaultTo: 'min',
    ),
    UnitCategory(
      'data',
      'Data',
      [
        Unit('bit', 'Bit', 'bit', _f(1, 8)),
        Unit('b', 'Byte', 'B', Rational.one),
        Unit('kb', 'Kilobyte', 'KB', _r('1000')),
        Unit('mb', 'Megabyte', 'MB', _r('1000000')),
        Unit('gb', 'Gigabyte', 'GB', _r('1000000000')),
        Unit('tb', 'Terabyte', 'TB', _r('1000000000000')),
        Unit('kib', 'Kibibyte', 'KiB', _r('1024')),
        Unit('mib', 'Mebibyte', 'MiB', _r('1048576')),
        Unit('gib', 'Gibibyte', 'GiB', _r('1073741824')),
      ],
      defaultFrom: 'gb',
      defaultTo: 'mb',
    ),
    UnitCategory(
      'pressure',
      'Pressure',
      [
        Unit('pa', 'Pascal', 'Pa', Rational.one),
        Unit('kpa', 'Kilopascal', 'kPa', _r('1000')),
        Unit('bar', 'Bar', 'bar', _r('100000')),
        Unit('atm', 'Atmosphere', 'atm', _r('101325')),
        // 1 psi = 1 lbf/in² = 4.4482216152605 N / 0.00064516 m²
        Unit(
          'psi',
          'Pound per sq inch',
          'psi',
          _r('4.4482216152605') / _r('0.00064516'),
        ),
        Unit('mmhg', 'Millimetre of mercury', 'mmHg', _r('133.322387415')),
      ],
      defaultFrom: 'bar',
      defaultTo: 'psi',
    ),
    UnitCategory(
      'energy',
      'Energy',
      [
        Unit('j', 'Joule', 'J', Rational.one),
        Unit('kj', 'Kilojoule', 'kJ', _r('1000')),
        Unit('cal', 'Calorie', 'cal', _r('4.184')),
        Unit('kcal', 'Kilocalorie', 'kcal', _r('4184')),
        Unit('wh', 'Watt-hour', 'Wh', _r('3600')),
        Unit('kwh', 'Kilowatt-hour', 'kWh', _r('3600000')),
        Unit('btu', 'British thermal unit', 'BTU', _r('1055.05585262')),
      ],
      defaultFrom: 'kcal',
      defaultTo: 'kj',
    ),
  ];
}
