import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/converter/presentation/converter_screen.dart';
import 'package:popcalc/features/history/presentation/history_sheet.dart';
import 'widgets/celebration_burst.dart';
import 'widgets/expression_line.dart';
import 'widgets/grain_overlay.dart';
import 'widgets/keypad.dart';
import 'widgets/numeral_animator.dart';
import 'widgets/scientific_tray.dart';
import 'widgets/top_bar.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  /// When true, the result zone is in "edit/highlight" mode.
  /// The next digit press will replace the entire current number.
  bool _resultHighlighted = false;

  void _copyResult(BuildContext context, String text) {
    if (text.isEmpty) return;
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
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final colors = ThemeColors.of(themeMode);
    final calcState = ref.watch(calculatorProvider);
    final settings = ref.watch(settingsProvider);
    final scientific = settings.advancedTools && settings.scientificActive;

    // Auto-clear highlight when state changes externally
    if (_resultHighlighted &&
        calcState.justEvaluated == false &&
        calcState.expression.getAllTokens().isNotEmpty) {
      _resultHighlighted = false;
    }

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Background subtle radiant lighting gradient
          RepaintBoundary(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, -0.3),
                  radius: 1.3,
                  colors: [
                    colors.bgShade,
                    colors.bg,
                  ],
                ),
              ),
            ),
          ),

          // Tactile film grain overlay
          const GrainOverlay(),

          // Centered phone frame for responsive web & mobile presentation
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440.0),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top utility bar (isolated for 0-jank rendering)
                    RepaintBoundary(
                      child: TopBar(
                        colors: colors,
                        onConverterTap: () {
                          AppHaptics.mode(true);
                          AppSounds.mode(true);
                          setState(() => _resultHighlighted = false);
                          ConverterScreen.open(context);
                        },
                        onHistoryTap: () {
                          AppHaptics.selectionClick();
                          setState(() => _resultHighlighted = false);
                          HistorySheet.show(
                            context,
                            colors: colors,
                            onSelectEntry: (expr, res) {
                              ref
                                  .read(calculatorProvider.notifier)
                                  .loadExpression(expr, res);
                            },
                          );
                        },
                      ),
                    ),

                    // Expression line with token tapping, square highlight, and conditional preview
                    RepaintBoundary(
                      child: ExpressionLine(
                        expression: calcState.expression,
                        previewText: calcState.previewText,
                        colors: colors,
                        justEvaluated: calcState.justEvaluated,
                        editingTokenIndex: calcState.editingTokenIndex,
                        showLivePreview: settings.showLivePreview,
                        onTokenTap: (index) {
                          setState(() => _resultHighlighted = false);
                          ref
                              .read(calculatorProvider.notifier)
                              .selectToken(index);
                        },
                      ),
                    ),

                    // Hero 3D extruded numeral result zone (~44% of vertical space)
                    // Interactive: users can rotate/move the 3D number in real-time with touch!
                    // With the scientific tray open the keypad keeps its
                    // finger-sized rows and the answer gives up the room.
                    // The split eases between layouts as the tray comes and
                    // goes (flex is scaled ×10 so the tween moves smoothly).
                    TweenAnimationBuilder<double>(
                      tween: Tween(
                        end: !scientific
                            ? 44
                            : settings.scientificExpanded
                                ? 24
                                : 34,
                      ),
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                      builder: (context, flex, child) => Expanded(
                        flex: (flex * 10).round(),
                        child: child!,
                      ),
                      child: RepaintBoundary(
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              // Speed-line burst behind the answer
                              Positioned.fill(
                                left: -40,
                                right: -40,
                                child: CelebrationBurst(
                                  trigger: calcState.celebrationId,
                                  color: colors.burst,
                                ),
                              ),
                              AnimatedExtrudedNumber(
                                text: calcState.resultText,
                                isEvaluated: calcState.justEvaluated,
                                hasError: calcState.error != null,
                                colors: colors,
                                isLite: settings.liteMode,
                                isZero: calcState.isZeroState,
                                celebrationId: calcState.celebrationId,
                                onTap: () {
                                  if (calcState.editingTokenIndex != null) {
                                    ref
                                        .read(calculatorProvider.notifier)
                                        .deselectToken();
                                  } else {
                                    AppHaptics.selectionClick();
                                    setState(() {
                                      _resultHighlighted = !_resultHighlighted;
                                    });
                                  }
                                },
                                onLongPress: () {
                                  setState(() => _resultHighlighted = false);
                                  _copyResult(context, calcState.resultText);
                                },
                              ),
                              // Angle unit badge, display-corner style
                              if (scientific)
                                Positioned(
                                  top: 6,
                                  left: 0,
                                  child: _AngleBadge(
                                    colors: colors,
                                    unit: settings.angleUnit,
                                    onTap: () {
                                      final toRadians = settings.angleUnit ==
                                          AngleUnit.degrees;
                                      AppHaptics.shift(toRadians);
                                      AppSounds.shift(toRadians);
                                      ref
                                          .read(settingsProvider.notifier)
                                          .setAngleUnit(
                                            settings.angleUnit ==
                                                    AngleUnit.degrees
                                                ? AngleUnit.radians
                                                : AngleUnit.degrees,
                                          );
                                    },
                                  ),
                                ),
                              // Highlight overlay when in whole-result edit mode
                              if (_resultHighlighted)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      decoration: BoxDecoration(
                                        color: colors.accent
                                            .withValues(alpha: 0.12),
                                        borderRadius:
                                            BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Scientific keys (Settings > Scientific Calculator),
                    // shown or hidden from the top bar.
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) => SizeTransition(
                        sizeFactor: animation,
                        alignment: Alignment.bottomCenter,
                        child: FadeTransition(opacity: animation, child: child),
                      ),
                      child: scientific
                          ? Padding(
                              key: const ValueKey('tray'),
                              padding: const EdgeInsets.fromLTRB(
                                  18.0, 0.0, 18.0, 6.0),
                              child: RepaintBoundary(
                                child: ScientificTray(colors: colors),
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('no-tray'),
                              width: double.infinity,
                            ),
                    ),

                    // Tactile Keypad (~52% of vertical space)
                    Expanded(
                      flex: 520,
                      child: RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                              24.0, 0.0, 24.0, 20.0),
                          child: Keypad(
                            colors: colors,
                            highlightMode: _resultHighlighted ||
                                calcState.editingTokenIndex != null,
                            onHighlightConsumed: () {
                              setState(() => _resultHighlighted = false);
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// DEG / RAD indicator in the display's corner; tap to switch.
class _AngleBadge extends StatelessWidget {
  final ThemeColors colors;
  final AngleUnit unit;
  final VoidCallback onTap;

  const _AngleBadge({
    required this.colors,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDeg = unit == AngleUnit.degrees;
    return Semantics(
      button: true,
      label: isDeg
          ? 'Angles in degrees. Tap for radians'
          : 'Angles in radians. Tap for degrees',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Container(
              key: ValueKey(isDeg),
              padding:
                  const EdgeInsets.symmetric(horizontal: 9.0, vertical: 4.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: colors.accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(10.0),
              ),
              child: Text(
                isDeg ? 'DEG' : 'RAD',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 15.0,
                  letterSpacing: 1.2,
                  height: 1.0,
                  color: colors.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
