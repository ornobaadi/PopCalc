import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/core/engine/evaluator.dart';
import 'package:popcalc/core/engine/expression.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/review/review_prompter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/history_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/converter/presentation/converter_screen.dart';
import 'package:popcalc/features/history/presentation/history_sheet.dart';

import 'widgets/celebration_burst.dart';
import 'widgets/expression_line.dart';
import 'widgets/grain_overlay.dart';
import 'widgets/ink_spill.dart';
import 'widgets/keypad.dart';
import 'widgets/numeral_animator.dart';
import 'widgets/scientific_tray.dart';
import 'widgets/top_bar.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen>
    with WidgetsBindingObserver {
  /// When true, the result zone is in "edit/highlight" mode.
  /// The next digit press will replace the entire current number.
  bool _resultHighlighted = false;

  /// Whether the device may currently rotate (null until first decided).
  bool? _landscapeAllowed;

  /// The pill at the top: a hunt note solved, or the secret skin found.
  String? _pill;
  bool _pillShown = false;
  Timer? _pillTimer;

  /// Waits out the error sound before "that's what she said" plays.
  Timer? _punchlineTimer;

  /// Holds Play's review card until the celebration is over and the user
  /// is idle; any change to the calculator calls it off.
  Timer? _reviewTimer;

  /// The hunt's finale is running (see [InkSpill]).
  bool _spilling = false;
  final _heroKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pillTimer?.cancel();
    _punchlineTimer?.cancel();
    _reviewTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.hidden) {
      _savePendingPreviewIfNeeded();
    }
  }

  void _savePendingPreviewIfNeeded() {
    final settings = ref.read(settingsProvider);
    if (!settings.showLivePreview) return;

    final calcState = ref.read(calculatorProvider);
    if (calcState.justEvaluated) return;

    final preview = calcState.previewText;
    // The preview ignores an operator left hanging at the end ("1 + 2 +"),
    // so the saved expression leaves it out too.
    final tokens = calcState.expression.getAllTokens();
    while (tokens.isNotEmpty && tokens.last.isOperator) {
      tokens.removeLast();
    }
    final expr = Expression.fromTokens(tokens).toDisplayString();
    if (preview != null && preview.isNotEmpty && expr.isNotEmpty) {
      ref.read(historyProvider.notifier).savePendingPreview(expr, preview);
    }
  }

  /// Only scientific mode has a sideways layout, so only it may rotate.
  void _allowLandscape(bool allow) {
    if (_landscapeAllowed == allow) return;
    _landscapeAllowed = allow;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      if (allow) ...[
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ],
    ]);
  }

  void _announce(String text) {
    _pillTimer?.cancel();
    _pillTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _pillShown = false);
    });
    setState(() {
      _pill = text;
      _pillShown = true;
    });
  }

  /// Where the ink starts: the middle of the big number.
  Offset _heroCentre() {
    final hero = _heroKey.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (hero == null || me == null || !hero.hasSize) {
      return MediaQuery.sizeOf(context).center(Offset.zero);
    }
    return me.globalToLocal(hero.localToGlobal(hero.size.center(Offset.zero)));
  }

  /// Under the ink: the skin is found and put on.
  void _finishHunt() {
    ref.read(settingsProvider.notifier).unlockSecret();
    ref.read(themeProvider.notifier).setTheme(kSecretSkins.first.mode);
    ref.read(secretFoundProvider.notifier).state++;
    ref
        .read(calculatorProvider.notifier)
        .showHeadline(kHuntHeadline, kHuntHeadlineNote);
    AppHaptics.success();
    // The best moment PopCalc has: let the ink dry and the headline land.
    ReviewPrompter.onCaseClosed().then((earned) {
      if (earned) _offerReview(const Duration(seconds: 4), atCase: true);
    });
  }

  void _offerReview(Duration after, {bool atCase = false}) {
    _reviewTimer?.cancel();
    _reviewTimer = Timer(after, () {
      if (mounted && (ModalRoute.of(context)?.isCurrent ?? true)) {
        ReviewPrompter.ask(atCase: atCase);
      }
    });
  }

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

    // A beat after the error sound, the punchline. Any key before then
    // clears errorPunchline and calls it off, so it never talks over typing.
    // Keyed on the line (never the same twice running), so pressing = again
    // gets its own punchline too.
    ref.listen(
        calculatorProvider
            .select((s) => s.errorPunchline ? s.resultText : null), (_, line) {
      _punchlineTimer?.cancel();
      if (line != null) {
        _punchlineTimer = Timer(
          const Duration(seconds: 1),
          AppSounds.thatsWhatSheSaid,
        );
      }
    });
    // A good answer may earn Play's review card (see ReviewPrompter); any
    // later change, a key or an error, means the user is busy, so it waits.
    ref.listen(calculatorProvider, (prev, next) {
      if (prev == null) return;
      // justEvaluated: the hunt's headline pops too, but is not an answer.
      if (next.celebrationId > prev.celebrationId && next.justEvaluated) {
        final id = next.celebrationId;
        ReviewPrompter.onAnswer().then((earned) {
          if (earned && ref.read(calculatorProvider).celebrationId == id) {
            _offerReview(const Duration(milliseconds: 1800));
          }
        });
      } else if (next.expressionText != prev.expressionText ||
          next.resultText != prev.resultText) {
        _reviewTimer?.cancel();
      }
    });
    ref.listen(secretFoundProvider, (_, _) {
      _announce('SECRET SKIN FOUND · ${kSecretSkins.first.label}');
    });
    ref.listen(huntSolvedProvider, (_, _) {
      final step = ref.read(settingsProvider).huntStep;
      _announce('${kHuntSolvedLines[step - 1]} · $step/$kHuntLength');
    });
    // Every note solved: the finale plays once this screen is on top again
    // (History closes itself on the last note; or at the next launch).
    if (settings.huntStep >= kHuntLength &&
        !settings.secretUnlocked &&
        !_spilling &&
        (ModalRoute.of(context)?.isCurrent ?? true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_spilling) setState(() => _spilling = true);
      });
    }

    // Auto-clear highlight when state changes externally
    if (_resultHighlighted &&
        calcState.justEvaluated == false &&
        calcState.expression.getAllTokens().isNotEmpty) {
      _resultHighlighted = false;
    }

    // Scientific mode may turn sideways; everything else stays upright.
    _allowLandscape(scientific);
    final size = MediaQuery.sizeOf(context);
    // Sideways on a phone: all scientific keys at once, beside the keypad.
    // (Wide but tall windows, like tablets, keep the centred phone frame.)
    final landscape =
        scientific && size.width > size.height * 1.2 && size.height < 560.0;

    final Widget topBar = RepaintBoundary(
      child: TopBar(
        colors: colors,
        compact: landscape,
        onConverterTap: () {
          AppHaptics.mode(true);
          setState(() => _resultHighlighted = false);
          // The converter is portrait-only: stand up for it, then let
          // the build decide again once it closes.
          _allowLandscape(false);
          ConverterScreen.open(context).whenComplete(() {
            if (mounted) setState(() {});
          });
        },
        onHistoryTap: () {
          AppHaptics.selectionClick();
          setState(() => _resultHighlighted = false);
          HistorySheet.show(
            context,
            colors: colors,
            onSelectEntry: (expr, res) {
              ref.read(calculatorProvider.notifier).loadExpression(expr, res);
            },
          );
        },
      ),
    );

    final Widget expressionLine = RepaintBoundary(
      child: ExpressionLine(
        expression: calcState.expression,
        previewText: calcState.previewText,
        colors: colors,
        justEvaluated: calcState.justEvaluated,
        editingTokenIndex: calcState.editingTokenIndex,
        showLivePreview: settings.showLivePreview,
        onTokenTap: (index) {
          setState(() => _resultHighlighted = false);
          ref.read(calculatorProvider.notifier).selectToken(index);
        },
      ),
    );

    final Widget resultZone = RepaintBoundary(
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
            // An error's line is a joke; a screen reader gets the reason.
            Semantics(
              key: _heroKey,
              label:
                  calcState.errorNote ??
                  calcState.error?.plainMessage ??
                  calcState.resultText,
              excludeSemantics: true,
              child: AnimatedExtrudedNumber(
                text: calcState.resultText,
                isEvaluated: calcState.justEvaluated,
                hasError: calcState.error != null,
                colors: colors,
                isLite: settings.liteMode,
                isZero: calcState.isZeroState,
                celebrationId: calcState.celebrationId,
                onTap: () {
                  if (calcState.editingTokenIndex != null) {
                    ref.read(calculatorProvider.notifier).deselectToken();
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
            ),
            // Under an error's line, the plain reason, small and quiet.
            // Together with the smaller lettering it marks the line as
            // a message, not an answer.
            if (calcState.error != null || calcState.errorNote != null)
              Align(
                alignment: Alignment.center,
                child: Transform.translate(
                  // A punchline adds a second line; shift down so the
                  // reason stays where it always sits.
                  offset: Offset(0.0, calcState.errorPunchline ? 64.0 : 54.0),
                  child: IgnorePointer(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // The punchline lands right under the setup; the
                        // sober reason follows, so the joke still makes sense.
                        if (calcState.errorPunchline)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Text(
                              kThatsWhatSheSaid,
                              key: const ValueKey('error-punchline'),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15.0,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.3,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        Text(
                          calcState.errorNote ?? calcState.error!.plainMessage,
                          key: const ValueKey('error-reason'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.0,
                            letterSpacing: 0.3,
                            color: colors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Angle unit badge, display-corner style
            if (scientific && !landscape)
              Positioned(
                top: 6,
                left: 0,
                child: _AngleBadge(
                  colors: colors,
                  unit: settings.angleUnit,
                  onTap: () {
                    final toRadians = settings.angleUnit == AngleUnit.degrees;
                    AppHaptics.shift(toRadians);
                    ref
                        .read(settingsProvider.notifier)
                        .setAngleUnit(
                          settings.angleUnit == AngleUnit.degrees
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
                    duration: const Duration(milliseconds: 160),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );

    final keypad = Keypad(
      colors: colors,
      highlightMode: _resultHighlighted || calcState.editingTokenIndex != null,
      onHighlightConsumed: () {
        setState(() => _resultHighlighted = false);
      },
    );

    final Widget content;
    if (landscape) {
      content = SafeArea(
        child: Row(
          children: [
            // Display
            Expanded(
              flex: 34,
              child: Column(
                children: [
                  topBar,
                  expressionLine,
                  Expanded(child: resultZone),
                  const SizedBox(height: 8.0),
                ],
              ),
            ),
            // Every scientific key, both layers side by side
            Expanded(
              flex: 31,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 10.0),
                child: RepaintBoundary(
                  child: ScientificTray(colors: colors, grid: true),
                ),
              ),
            ),
            // Keypad
            Expanded(
              flex: 35,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4.0, 8.0, 12.0, 10.0),
                child: RepaintBoundary(child: keypad),
              ),
            ),
          ],
        ),
      );
    } else {
      // Centered phone frame for responsive web & mobile presentation
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440.0),
          child: SafeArea(
            child: Column(
              children: [
                topBar,
                expressionLine,

                // Hero 3D extruded numeral result zone (~44% of vertical space)
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
                  builder: (context, flex, child) =>
                      Expanded(flex: (flex * 10).round(), child: child!),
                  child: resultZone,
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
                            18.0,
                            0.0,
                            18.0,
                            6.0,
                          ),
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
                      padding: const EdgeInsets.fromLTRB(24.0, 0.0, 24.0, 20.0),
                      child: keypad,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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

          // Blueprint: a drafting grid under everything
          if (colors.finish == SkinFinish.wireframe)
            Positioned.fill(
              child: IgnorePointer(
                child: GridPaper(
                  color: colors.ink.withValues(alpha: 0.14),
                  interval: 96.0,
                  divisions: 1,
                  subdivisions: 4,
                ),
              ),
            ),

          // Tactile film grain overlay
          const GrainOverlay(),

          content,

          if (_spilling)
            Positioned.fill(
              child: InkSpill(
                origin: _heroCentre(),
                isLite: settings.liteMode,
                onCovered: _finishHunt,
                onDone: () {
                  if (mounted) setState(() => _spilling = false);
                },
              ),
            ),

          // Hunt progress and the secret skin, announced as they land
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _pillShown ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 260),
                  child: Container(
                    margin: const EdgeInsets.only(top: 10.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      _pill ?? '',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 15.0,
                        letterSpacing: 1.6,
                        color: colors.bg,
                      ),
                    ),
                  ),
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
              padding: const EdgeInsets.symmetric(
                horizontal: 9.0,
                vertical: 4.0,
              ),
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
