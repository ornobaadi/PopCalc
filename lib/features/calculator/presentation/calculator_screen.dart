import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/converter/presentation/converter_view.dart';
import 'package:popcalc/features/history/presentation/history_sheet.dart';

import 'widgets/celebration_burst.dart';
import 'widgets/expression_line.dart';
import 'widgets/grain_overlay.dart';
import 'widgets/keypad.dart';
import 'widgets/numeral_animator.dart';
import 'widgets/scientific_strip.dart';
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

  /// Advanced mode: unit converter instead of the calculator.
  bool _showConverter = false;

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
    final advanced = settings.advancedMode;
    final showConverter = advanced && _showConverter;

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
                  colors: [colors.bgShade, colors.bg],
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
                        showConverter: showConverter,
                        onConverterChanged: (value) {
                          setState(() {
                            _showConverter = value;
                            _resultHighlighted = false;
                          });
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

                    if (showConverter)
                      Expanded(child: ConverterView(colors: colors)),

                    // Expression line with token tapping, square highlight, and conditional preview
                    if (!showConverter)
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

                    // Hero 3D extruded numeral result zone (~44% of vertical space,
                    // ~30% when the scientific strip takes its share)
                    // Interactive: users can rotate/move the 3D number in real-time with touch!
                    if (!showConverter)
                      Expanded(
                        flex: advanced ? 30 : 44,
                        child: RepaintBoundary(
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20.0,
                            ),
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
                                        _resultHighlighted =
                                            !_resultHighlighted;
                                      });
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() => _resultHighlighted = false);
                                    _copyResult(context, calcState.resultText);
                                  },
                                ),
                                // Highlight overlay when in whole-result edit mode
                                if (_resultHighlighted)
                                  Positioned.fill(
                                    child: IgnorePointer(
                                      child: AnimatedContainer(
                                        duration: const Duration(
                                          milliseconds: 160,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.accent.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                    // Scientific keys (Advanced mode)
                    if (advanced && !showConverter)
                      Expanded(
                        flex: 16,
                        child: RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                            ),
                            child: ScientificStrip(colors: colors),
                          ),
                        ),
                      ),

                    // Tactile Keypad (~52% of vertical space)
                    if (!showConverter)
                      Expanded(
                        flex: 52,
                        child: RepaintBoundary(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              24.0,
                              0.0,
                              24.0,
                              20.0,
                            ),
                            child: Keypad(
                              colors: colors,
                              highlightMode:
                                  _resultHighlighted ||
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
