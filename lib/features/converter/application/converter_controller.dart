import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/engine/formatter.dart';
import 'package:popcalc/core/storage/rates_store.dart';
import 'package:popcalc/core/units/currency.dart';
import 'package:popcalc/core/units/units.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ConverterState {
  final UnitCategory category;
  final Unit from;
  final Unit to;

  /// The number being typed, raw (e.g. "1024.5", "-40").
  final String input;

  const ConverterState({
    required this.category,
    required this.from,
    required this.to,
    this.input = '',
  });

  String get inputText => NumberFormatter.formatInputNumber(input);

  String get outputText {
    final clean = input.endsWith('.')
        ? input.substring(0, input.length - 1)
        : input;
    final value = Decimal.tryParse(clean == '' || clean == '-' ? '0' : clean);
    if (value == null) return '0';
    return NumberFormatter.format(_shown(Units.convert(value, from, to)));
  }

  bool get isCurrency => category.id == Currency.categoryId;

  /// Currency shows money-style precision; everything else is exact.
  Decimal _shown(Decimal value) => isCurrency ? Currency.round(value) : value;

  /// One-unit reference line, e.g. "1 km = 0.621371192237334 mi".
  String get referenceText {
    final one = NumberFormatter.format(
      _shown(Units.convert(Decimal.one, from, to)),
    );
    return '1 ${from.symbol} = $one ${to.symbol}';
  }

  ConverterState copyWith({
    UnitCategory? category,
    Unit? from,
    Unit? to,
    String? input,
  }) {
    return ConverterState(
      category: category ?? this.category,
      from: from ?? this.from,
      to: to ?? this.to,
      input: input ?? this.input,
    );
  }

  factory ConverterState.forCategory(UnitCategory c, {String input = ''}) =>
      ConverterState(
        category: c,
        from: c.unit(c.defaultFrom),
        to: c.unit(c.defaultTo),
        input: input,
      );
}

final converterProvider =
    StateNotifierProvider<ConverterController, ConverterState>((ref) {
      final controller = ConverterController();
      // Currency rates can change underneath the chosen units (saved rates
      // loading, or a refresh); pick the units up again when they do.
      ref.listen(ratesProvider, (_, _) => controller.reloadUnits());
      return controller;
    });

class ConverterController extends StateNotifier<ConverterState> {
  ConverterController({bool persist = true})
    : _persist = persist,
      super(ConverterState.forCategory(Units.categories.first)) {
    if (persist) _load();
  }

  final bool _persist;

  static const _kCategory = 'converter_category';
  static const _kFrom = 'converter_from';
  static const _kTo = 'converter_to';

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final category = Units.byId(prefs.getString(_kCategory) ?? '');
      Unit pick(String? id, String fallback) => category.units.firstWhere(
        (u) => u.id == id,
        orElse: () => category.unit(fallback),
      );
      state = state.copyWith(
        category: category,
        from: pick(prefs.getString(_kFrom), category.defaultFrom),
        to: pick(prefs.getString(_kTo), category.defaultTo),
      );
    } catch (_) {}
  }

  Future<void> _save() async {
    if (!_persist) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCategory, state.category.id);
      await prefs.setString(_kFrom, state.from.id);
      await prefs.setString(_kTo, state.to.id);
    } catch (_) {}
  }

  void selectCategory(UnitCategory category) {
    if (category.id == state.category.id) return;
    state = ConverterState.forCategory(category, input: state.input);
    _save();
  }

  void setFrom(Unit unit) {
    state = unit.id == state.to.id
        ? state.copyWith(from: unit, to: state.from)
        : state.copyWith(from: unit);
    _save();
  }

  void setTo(Unit unit) {
    state = unit.id == state.from.id
        ? state.copyWith(to: unit, from: state.to)
        : state.copyWith(to: unit);
    _save();
  }

  /// Looks the category and units up again by id, after currency rates
  /// changed underneath them. The selection and the input stay as they are.
  void reloadUnits() {
    final category = Units.byId(state.category.id);
    Unit pick(Unit old, String fallback) => category.units.firstWhere(
      (u) => u.id == old.id,
      orElse: () => category.unit(fallback),
    );
    state = state.copyWith(
      category: category,
      from: pick(state.from, category.defaultFrom),
      to: pick(state.to, category.defaultTo),
    );
  }

  /// Swaps the units and carries the converted value over as the new input.
  void swap() {
    final carried = state.input.isEmpty
        ? ''
        : state.outputText.replaceAll(',', '');
    state = state.copyWith(
      from: state.to,
      to: state.from,
      // Scientific outputs ("1.2e20") can't be edited digit by digit.
      input: carried.contains('e') ? state.input : carried,
    );
    _save();
  }

  Expression get _expr => Expression(currentNumber: state.input);

  void onDigit(String digit) =>
      state = state.copyWith(input: _expr.appendDigit(digit).currentNumber);

  void onDecimal() =>
      state = state.copyWith(input: _expr.appendDecimal().currentNumber);

  void onBackspace() =>
      state = state.copyWith(input: _expr.backspace().currentNumber);

  void onToggleSign() {
    if (state.input.isEmpty) return;
    state = state.copyWith(input: _expr.toggleSign().currentNumber);
  }

  void onClear() => state = state.copyWith(input: '');

  /// Starts from a value carried over from the calculator.
  void loadValue(String value) {
    final raw = value.replaceAll(',', '');
    if (Decimal.tryParse(raw) == null || raw.contains('e')) return;
    state = state.copyWith(input: raw);
  }
}
