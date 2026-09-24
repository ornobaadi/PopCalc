import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/history/presentation/history_sheet.dart';
import 'widgets/expression_line.dart';
import 'widgets/grain_overlay.dart';
import 'widgets/keypad.dart';
import 'widgets/numeral_animator.dart';
import 'widgets/top_bar.dart';

class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  void _copyResult(BuildContext context, String text) {
    if (text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text.replaceAll(',', '')));
    HapticFeedback.mediumImpact();
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
    final themeMode = ref.watch(themeProvider);
    final colors = themeMode == AppThemeMode.ink
        ? ThemeColors.inkTheme
        : ThemeColors.sunnyTheme;
    final calcState = ref.watch(calculatorProvider);

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
          // Background subtle radiant lighting gradient
          Container(
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

          // Tactile film grain overlay
          const GrainOverlay(),

          // Centered phone frame for responsive web & mobile presentation
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 440.0,
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    // Top utility bar (quiet History & Theme)
                    TopBar(
                      colors: colors,
                      onHistoryTap: () {
                        HapticFeedback.selectionClick();
                        HistorySheet.show(
                          context,
                          colors: colors,
                          onSelectResult: (res) {
                            ref
                                .read(calculatorProvider.notifier)
                                .loadResult(res);
                          },
                        );
                      },
                    ),

                    // Centered expression line
                    ExpressionLine(
                      expression: calcState.expression,
                      previewText: calcState.previewText,
                      colors: colors,
                    ),

                    // Hero 3D extruded numeral result zone (~44% of vertical space)
                    Expanded(
                      flex: 44,
                      child: GestureDetector(
                        onLongPress: () =>
                            _copyResult(context, calcState.resultText),
                        child: Container(
                          width: double.infinity,
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: AnimatedExtrudedNumber(
                            text: calcState.resultText,
                            isEvaluated: calcState.justEvaluated,
                            hasError: calcState.error != null,
                            colors: colors,
                          ),
                        ),
                      ),
                    ),

                    // Tactile Keypad (~52% of vertical space)
                    Expanded(
                      flex: 52,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                            24.0, 0.0, 24.0, 20.0),
                        child: Keypad(colors: colors),
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
