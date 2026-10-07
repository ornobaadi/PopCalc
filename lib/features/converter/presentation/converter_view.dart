import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/core/units/units.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/calculator/presentation/widgets/backspace_icon.dart';
import 'package:popcalc/features/calculator/presentation/widgets/key_button.dart';
import 'package:popcalc/features/calculator/presentation/widgets/numeral_animator.dart';
import 'package:popcalc/features/converter/application/converter_controller.dart';

/// Unit converter body, shown in place of the calculator in Advanced mode.
class ConverterView extends ConsumerWidget {
  final ThemeColors colors;

  const ConverterView({super.key, required this.colors});

  static const _labelStyle = TextStyle(
    fontFamily: 'BebasNeue',
    fontFamilyFallback: ['Antonio', 'sans-serif'],
    letterSpacing: 0.8,
    height: 1.0,
  );

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text.replaceAll(',', '')));
    AppHaptics.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied $text to clipboard'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(converterProvider);
    final controller = ref.read(converterProvider.notifier);
    final isLite = ref.watch(settingsProvider.select((s) => s.liteMode));

    return Column(
      children: [
        _CategoryPills(colors: colors, selected: state.category),

        // Input and converted value (~44% like the calculator's result zone)
        Expanded(
          flex: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              children: [
                _UnitChip(
                  colors: colors,
                  unit: state.from,
                  onTap: () => _pickUnit(
                    context,
                    state.category,
                    state.from,
                    controller.setFrom,
                  ),
                ),
                Expanded(
                  flex: 3,
                  child: AnimatedExtrudedNumber(
                    text: state.inputText,
                    colors: colors,
                    isLite: isLite,
                    isZero: state.input.isEmpty,
                    onLongPress: () => _copy(context, state.inputText),
                  ),
                ),
                Divider(color: colors.ink.withValues(alpha: 0.1), height: 1),
                _UnitChip(
                  colors: colors,
                  unit: state.to,
                  onTap: () => _pickUnit(
                    context,
                    state.category,
                    state.to,
                    controller.setTo,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onLongPress: () => _copy(context, state.outputText),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        state.outputText,
                        semanticsLabel: '${state.outputText} ${state.to.name}',
                        style: _labelStyle.copyWith(
                          fontSize: 72.0,
                          color: colors.accent,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Expanded(
          flex: 52,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
            child: _ConverterKeypad(colors: colors),
          ),
        ),
      ],
    );
  }

  void _pickUnit(
    BuildContext context,
    UnitCategory category,
    Unit current,
    ValueChanged<Unit> onPick,
  ) {
    AppHaptics.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.65,
        ),
        decoration: BoxDecoration(
          color: colors.bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
          border: Border(
            top: BorderSide(
              color: colors.ink.withValues(alpha: 0.1),
              width: 1.5,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            children: [
              for (final unit in category.units)
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 28.0),
                  title: Text(
                    unit.name,
                    style: TextStyle(
                      color: unit.id == current.id ? colors.accent : colors.ink,
                      fontSize: 16.0,
                    ),
                  ),
                  trailing: Text(
                    unit.symbol,
                    style: _labelStyle.copyWith(
                      fontSize: 22.0,
                      color: unit.id == current.id
                          ? colors.accent
                          : colors.inkSoft,
                    ),
                  ),
                  onTap: () {
                    AppHaptics.selectionClick();
                    onPick(unit);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryPills extends ConsumerWidget {
  final ThemeColors colors;
  final UnitCategory selected;

  const _CategoryPills({required this.colors, required this.selected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44.0,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
        itemCount: Units.categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8.0),
        itemBuilder: (context, i) {
          final category = Units.categories[i];
          final isSelected = category.id == selected.id;
          return GestureDetector(
            onTap: () {
              AppHaptics.selectionClick();
              AppSounds.utility();
              ref.read(converterProvider.notifier).selectCategory(category);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(horizontal: 14.0),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected
                    ? colors.accent.withValues(alpha: 0.16)
                    : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? colors.accent
                      : colors.ink.withValues(alpha: 0.12),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Text(
                category.name.toUpperCase(),
                style: ConverterView._labelStyle.copyWith(
                  fontSize: 18.0,
                  color: isSelected ? colors.accent : colors.inkSoft,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _UnitChip extends StatelessWidget {
  final ThemeColors colors;
  final Unit unit;
  final VoidCallback onTap;

  const _UnitChip({
    required this.colors,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Semantics(
        button: true,
        label: 'Change unit, ${unit.name}',
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  unit.name.toUpperCase(),
                  style: ConverterView._labelStyle.copyWith(
                    fontSize: 20.0,
                    color: colors.inkSoft,
                  ),
                ),
                const SizedBox(width: 6.0),
                Text(
                  unit.symbol,
                  style: ConverterView._labelStyle.copyWith(
                    fontSize: 20.0,
                    color: colors.accent,
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  color: colors.inkSoft,
                  size: 20.0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConverterKeypad extends ConsumerWidget {
  final ThemeColors colors;

  const _ConverterKeypad({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(converterProvider.notifier);

    Widget digit(String d) => Expanded(
      child: KeyButton(
        label: d,
        color: colors.ink,
        fontSize: 46.0,
        sound: () => AppSounds.digit(d),
        onTap: () => c.onDigit(d),
      ),
    );

    Widget utility(
      String label,
      VoidCallback onTap, {
      String? semantic,
      double fontSize = 32.0,
      Widget? child,
    }) => Expanded(
      child: KeyButton(
        label: child == null ? label : null,
        color: colors.inkSoft,
        fontSize: fontSize,
        semanticLabel: semantic,
        haptic: AppHaptics.utility,
        sound: AppSounds.utility,
        onTap: onTap,
        child: child,
      ),
    );

    Widget row(List<Widget> keys) => Expanded(child: Row(children: keys));

    return Column(
      children: [
        row([
          digit('7'),
          digit('8'),
          digit('9'),
          Expanded(
            child: KeyButton(
              color: colors.inkSoft,
              semanticLabel: 'Backspace',
              haptic: AppHaptics.backspace,
              sound: AppSounds.backspace,
              onTap: c.onBackspace,
              child: BackspaceIcon(color: colors.inkSoft, size: 28),
            ),
          ),
        ]),
        row([
          digit('4'),
          digit('5'),
          digit('6'),
          Expanded(
            child: KeyButton(
              label: 'C',
              color: colors.inkSoft,
              fontSize: 42.0,
              semanticLabel: 'Clear',
              haptic: AppHaptics.clear,
              sound: AppSounds.clear,
              onTap: c.onClear,
            ),
          ),
        ]),
        row([
          digit('1'),
          digit('2'),
          digit('3'),
          utility('+/-', c.onToggleSign, semantic: 'Toggle sign'),
        ]),
        row([
          utility(
            'ANS',
            () {
              final calc = ref.read(calculatorProvider);
              if (calc.error == null) c.loadValue(calc.resultText);
            },
            semantic: 'Use calculator answer',
            fontSize: 28.0,
          ),
          digit('0'),
          utility('.', c.onDecimal, semantic: 'Decimal point', fontSize: 46.0),
          Expanded(
            child: KeyButton(
              color: colors.accent,
              semanticLabel: 'Swap units',
              haptic: AppHaptics.operatorKey,
              sound: AppSounds.operatorKey,
              onTap: c.swap,
              child: Icon(
                Icons.swap_vert_rounded,
                color: colors.accent,
                size: 34,
              ),
            ),
          ),
        ]),
      ],
    );
  }
}
