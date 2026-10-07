import 'package:flutter/material.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';

class TopBar extends ConsumerWidget {
  final ThemeColors colors;
  final VoidCallback? onHistoryTap;
  final VoidCallback? onConverterTap;

  const TopBar({
    super.key,
    required this.colors,
    this.onHistoryTap,
    this.onConverterTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final converter = ref.watch(
      settingsProvider.select((s) => s.converterEnabled),
    );
    final scientificAvailable = ref.watch(
      settingsProvider.select((s) => s.scientificMode),
    );
    final scientificActive = ref.watch(
      settingsProvider.select((s) => s.scientificActive),
    );
    final iconColor = colors.inkSoft.withValues(alpha: 0.65);

    return SizedBox(
      height: 44.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // History button
                IconButton(
                  icon: Icon(
                    Icons.access_time_rounded,
                    color: iconColor,
                    size: 20.0,
                  ),
                  splashRadius: 20.0,
                  tooltip: 'History',
                  onPressed: onHistoryTap,
                ),

                // Simple ↔ scientific (when enabled in settings)
                if (scientificAvailable)
                  _ScientificToggle(
                    colors: colors,
                    active: scientificActive,
                    onChanged: (on) {
                      AppHaptics.mode(on);
                      AppSounds.mode(on);
                      ref
                          .read(settingsProvider.notifier)
                          .setScientificActive(on);
                    },
                  ),
              ],
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Unit converter (when enabled in settings)
                if (converter)
                  IconButton(
                    icon: Icon(
                      Icons.straighten_rounded,
                      color: iconColor,
                      size: 20.0,
                    ),
                    splashRadius: 20.0,
                    tooltip: 'Unit converter',
                    onPressed: () {
                      AppHaptics.selectionClick();
                      onConverterTap?.call();
                    },
                  ),

                // Settings / Skins button
                IconButton(
                  icon: Icon(Icons.tune_rounded, color: iconColor, size: 20.0),
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

/// f(x) switch between the simple and scientific calculator. Lit in the
/// accent colour while the scientific keys are showing.
class _ScientificToggle extends StatefulWidget {
  final ThemeColors colors;
  final bool active;
  final ValueChanged<bool> onChanged;

  const _ScientificToggle({
    required this.colors,
    required this.active,
    required this.onChanged,
  });

  @override
  State<_ScientificToggle> createState() => _ScientificToggleState();
}

class _ScientificToggleState extends State<_ScientificToggle> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final active = widget.active;
    return Tooltip(
      message: active ? 'Simple calculator' : 'Scientific calculator',
      child: Semantics(
        button: true,
        toggled: active,
        label: 'Scientific keys',
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onChanged(!active);
          },
          child: SizedBox(
            width: 48.0,
            height: 44.0,
            child: Center(
              child: AnimatedScale(
                scale: _pressed ? 0.85 : 1.0,
                duration: Duration(milliseconds: _pressed ? 70 : 160),
                curve: Curves.easeOutBack,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  width: 34.0,
                  height: 28.0,
                  decoration: BoxDecoration(
                    color: active
                        ? colors.accent.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  child: Center(
                    child: TweenAnimationBuilder<Color?>(
                      tween: ColorTween(
                        end: active
                            ? colors.accent
                            : colors.inkSoft.withValues(alpha: 0.65),
                      ),
                      duration: const Duration(milliseconds: 220),
                      builder: (_, color, _) => Icon(
                        Icons.functions_rounded,
                        color: color,
                        size: 20.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
