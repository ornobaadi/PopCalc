import 'package:flutter/material.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';

class TopBar extends ConsumerWidget {
  final ThemeColors colors;
  final VoidCallback? onHistoryTap;
  /// Advanced mode only: whether the unit converter is showing.
  final bool showConverter;
  final ValueChanged<bool>? onConverterChanged;

  const TopBar({
    super.key,
    required this.colors,
    this.onHistoryTap,
    this.showConverter = false,
    this.onConverterChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advanced = ref.watch(settingsProvider.select((s) => s.advancedMode));
    final angleUnit = ref.watch(settingsProvider.select((s) => s.angleUnit));

    return SizedBox(
      height: 44.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // History button (calculator history; hidden in the converter)
            Opacity(
              opacity: showConverter ? 0.0 : 1.0,
              child: IconButton(
                icon: Icon(
                  Icons.access_time_rounded,
                  color: colors.inkSoft.withValues(alpha: 0.65),
                  size: 20.0,
                ),
                splashRadius: 20.0,
                tooltip: 'History',
                onPressed: showConverter ? null : onHistoryTap,
              ),
            ),

            if (advanced)
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _ModeToggle(
                      colors: colors,
                      showConverter: showConverter,
                      onChanged: (value) {
                        AppHaptics.selectionClick();
                        onConverterChanged?.call(value);
                      },
                    ),
                  ),
                ),
              ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (advanced && !showConverter)
                  _Chip(
                    label: angleUnit == AngleUnit.degrees ? 'DEG' : 'RAD',
                    semanticLabel: angleUnit == AngleUnit.degrees
                        ? 'Angles in degrees. Tap for radians'
                        : 'Angles in radians. Tap for degrees',
                    colors: colors,
                    onTap: () {
                      AppHaptics.selectionClick();
                      ref.read(settingsProvider.notifier).setAngleUnit(
                            angleUnit == AngleUnit.degrees
                                ? AngleUnit.radians
                                : AngleUnit.degrees,
                          );
                    },
                  ),

                // Settings / Skins button
                IconButton(
                  icon: Icon(
                    Icons.tune_rounded,
                    color: colors.inkSoft.withValues(alpha: 0.65),
                    size: 20.0,
                  ),
                  splashRadius: 20.0,
                  tooltip: 'Settings',
                  onPressed: () {
                    AppHaptics.selectionClick();
                    SettingsSheet.show(context, colors: colors);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

const _barTextStyle = TextStyle(
  fontFamily: 'BebasNeue',
  fontSize: 18.0,
  letterSpacing: 1.0,
  height: 1.0,
);

/// CALC | CONVERT segmented switch.
class _ModeToggle extends StatelessWidget {
  final ThemeColors colors;
  final bool showConverter;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({
    required this.colors,
    required this.showConverter,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool value) {
      final selected = showConverter == value;
      return Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: selected ? null : () => onChanged(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: selected
                  ? colors.accent.withValues(alpha: 0.16)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14.0),
            ),
            child: Text(
              label,
              style: _barTextStyle.copyWith(
                color: selected ? colors.accent : colors.inkSoft,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2.0),
      decoration: BoxDecoration(
        border: Border.all(color: colors.ink.withValues(alpha: 0.12), width: 1.5),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [segment('CALC', false), segment('CONVERT', true)],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String semanticLabel;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.semanticLabel,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 10.0),
          child: Text(
            label,
            style: _barTextStyle.copyWith(color: colors.accent),
          ),
        ),
      ),
    );
  }
}
