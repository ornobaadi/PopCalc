import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/core/units/units.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/calculator/presentation/widgets/backspace_icon.dart';
import 'package:popcalc/features/calculator/presentation/widgets/grain_overlay.dart';
import 'package:popcalc/features/calculator/presentation/widgets/key_button.dart';
import 'package:popcalc/features/calculator/presentation/widgets/numeral_animator.dart';
import 'package:popcalc/features/converter/application/converter_controller.dart';

const _display = TextStyle(
  fontFamily: 'BebasNeue',
  fontFamilyFallback: ['Antonio', 'sans-serif'],
  letterSpacing: 0.8,
  height: 1.0,
);

void _copyToClipboard(BuildContext context, String text) {
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

/// The unit converter: its own screen, same skin and keys as the
/// calculator, with one number in and one number out.
class ConverterScreen extends ConsumerWidget {
  const ConverterScreen({super.key});

  static Future<void> open(BuildContext context) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, _, _) => const ConverterScreen(),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0.0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ThemeColors.of(ref.watch(themeProvider));

    return Scaffold(
      backgroundColor: colors.bg,
      body: Stack(
        children: [
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
          const GrainOverlay(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440.0),
              child: SafeArea(
                child: Column(
                  children: [
                    _Header(colors: colors),
                    _CategoryTabs(colors: colors),
                    Expanded(flex: 48, child: _Readout(colors: colors)),
                    Expanded(
                      flex: 44,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          24.0,
                          4.0,
                          24.0,
                          20.0,
                        ),
                        child: _ConverterKeypad(colors: colors),
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

class _Header extends StatelessWidget {
  final ThemeColors colors;

  const _Header({required this.colors});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: colors.inkSoft.withValues(alpha: 0.65),
                size: 20.0,
              ),
              splashRadius: 20.0,
              tooltip: 'Back to calculator',
              onPressed: () {
                AppHaptics.selectionClick();
                Navigator.of(context).maybePop();
              },
            ),
            Expanded(
              child: Center(
                child: Text(
                  'CONVERT',
                  style: _display.copyWith(
                    fontSize: 20.0,
                    letterSpacing: 3.0,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
            // Balances the back button so the title stays centred.
            const SizedBox(width: 48.0),
          ],
        ),
      ),
    );
  }
}

/// Plain text tabs with a dot under the active one. The active tab
/// scrolls into view so it is never hidden off-edge.
class _CategoryTabs extends ConsumerStatefulWidget {
  final ThemeColors colors;

  const _CategoryTabs({required this.colors});

  @override
  ConsumerState<_CategoryTabs> createState() => _CategoryTabsState();
}

class _CategoryTabsState extends ConsumerState<_CategoryTabs> {
  final _keys = {for (final c in Units.categories) c.id: GlobalKey()};

  void _reveal(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    // Saved category may be far right; bring it into view on open.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _reveal(ref.read(converterProvider).category.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final selected = ref.watch(converterProvider.select((s) => s.category));

    ref.listen(
      converterProvider.select((s) => s.category.id),
      (_, id) => _reveal(id),
    );

    // Soft fade at both edges hints there are more categories to scroll.
    return SizedBox(
      height: 44.0,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const LinearGradient(
          colors: [
            Color(0x00000000),
            Color(0xFF000000),
            Color(0xFF000000),
            Color(0x00000000),
          ],
          stops: [0.0, 0.06, 0.88, 1.0],
        ).createShader(rect),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 22.0),
          child: Row(
            children: [
              for (final category in Units.categories)
                Semantics(
                  key: _keys[category.id],
                  button: true,
                  selected: category.id == selected.id,
                  label: category.name,
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (category.id == selected.id) return;
                      AppHaptics.selectionClick();
                      AppSounds.utility();
                      ref
                          .read(converterProvider.notifier)
                          .selectCategory(category);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 180),
                            style: _display.copyWith(
                              fontSize: category.id == selected.id
                                  ? 21.0
                                  : 18.0,
                              letterSpacing: 1.2,
                              color: category.id == selected.id
                                  ? colors.ink
                                  : colors.inkSoft.withValues(alpha: 0.55),
                            ),
                            child: Text(category.name.toUpperCase()),
                          ),
                          const SizedBox(height: 5.0),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutBack,
                            width: category.id == selected.id ? 6.0 : 0.0,
                            height: 6.0,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The number you type (big, extruded) over the converted number.
class _Readout extends ConsumerWidget {
  final ThemeColors colors;

  const _Readout({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(converterProvider);
    final controller = ref.read(converterProvider.notifier);
    final isLite = ref.watch(settingsProvider.select((s) => s.liteMode));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          const SizedBox(height: 6.0),
          _UnitButton(
            colors: colors,
            unit: state.from,
            onTap: () => _UnitSheet.show(
              context,
              colors,
              state.category,
              state.from,
              controller.setFrom,
            ),
          ),
          Expanded(
            flex: 11,
            child: AnimatedExtrudedNumber(
              text: state.inputText,
              colors: colors,
              isLite: isLite,
              isZero: state.input.isEmpty,
              onLongPress: () => _copyToClipboard(context, state.inputText),
            ),
          ),
          _SwapDivider(colors: colors, onSwap: controller.swap),
          _UnitButton(
            colors: colors,
            unit: state.to,
            onTap: () => _UnitSheet.show(
              context,
              colors,
              state.category,
              state.to,
              controller.setTo,
            ),
          ),
          Expanded(
            flex: 6,
            child: GestureDetector(
              onLongPress: () => _copyToClipboard(context, state.outputText),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 140),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Text(
                      state.outputText,
                      key: ValueKey(state.outputText),
                      semanticsLabel: '${state.outputText} ${state.to.name}',
                      style: _display.copyWith(
                        fontSize: 64.0,
                        color: colors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Text(
            state.referenceText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Antonio',
              fontSize: 13.0,
              letterSpacing: 0.4,
              color: colors.inkSoft.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 6.0),
        ],
      ),
    );
  }
}

/// "KILOMETRE  KM ⌄" — tap to pick another unit.
class _UnitButton extends StatelessWidget {
  final ThemeColors colors;
  final Unit unit;
  final VoidCallback onTap;

  const _UnitButton({
    required this.colors,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${unit.name}. Change unit',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14.0, 7.0, 8.0, 7.0),
          decoration: BoxDecoration(
            color: colors.ink.withValues(alpha: colors.isDark ? 0.08 : 0.05),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                unit.name.toUpperCase(),
                style: _display.copyWith(fontSize: 18.0, color: colors.inkSoft),
              ),
              const SizedBox(width: 8.0),
              Text(
                unit.symbol,
                style: _display.copyWith(fontSize: 18.0, color: colors.accent),
              ),
              const SizedBox(width: 2.0),
              Icon(
                Icons.expand_more_rounded,
                color: colors.inkSoft,
                size: 18.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hairline with a round swap button that spins half a turn per tap.
class _SwapDivider extends StatefulWidget {
  final ThemeColors colors;
  final VoidCallback onSwap;

  const _SwapDivider({required this.colors, required this.onSwap});

  @override
  State<_SwapDivider> createState() => _SwapDividerState();
}

class _SwapDividerState extends State<_SwapDivider> {
  int _turns = 0;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final line = Expanded(
      child: Container(height: 1.5, color: colors.ink.withValues(alpha: 0.08)),
    );
    return SizedBox(
      height: 56.0,
      child: Row(
        children: [
          line,
          const SizedBox(width: 12.0),
          Semantics(
            button: true,
            label: 'Swap units',
            excludeSemantics: true,
            child: GestureDetector(
              onTapDown: (_) {
                AppHaptics.operatorKey();
                AppSounds.operatorKey();
                setState(() => _pressed = true);
              },
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) {
                setState(() {
                  _pressed = false;
                  _turns++;
                });
                widget.onSwap();
              },
              child: AnimatedScale(
                scale: _pressed ? 0.86 : 1.0,
                duration: const Duration(milliseconds: 90),
                child: Container(
                  width: 44.0,
                  height: 44.0,
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _turns * math.pi),
                    duration: const Duration(milliseconds: 360),
                    curve: Curves.easeOutBack,
                    builder: (_, angle, child) =>
                        Transform.rotate(angle: angle, child: child),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: colors.accent,
                      size: 24.0,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12.0),
          line,
        ],
      ),
    );
  }
}

class _UnitSheet {
  static void show(
    BuildContext context,
    ThemeColors colors,
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
          maxHeight: MediaQuery.of(sheetContext).size.height * 0.7,
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
                width: 36.0,
                height: 4.0,
                decoration: BoxDecoration(
                  color: colors.inkSoft.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    category.name.toUpperCase(),
                    style: _display.copyWith(
                      fontSize: 28.0,
                      letterSpacing: 1.5,
                      color: colors.ink,
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12.0, 0.0, 12.0, 16.0),
                  children: [
                    for (final unit in category.units)
                      _UnitRow(
                        colors: colors,
                        unit: unit,
                        selected: unit.id == current.id,
                        onTap: () {
                          AppHaptics.selectionClick();
                          onPick(unit);
                          Navigator.of(sheetContext).pop();
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitRow extends StatelessWidget {
  final ThemeColors colors;
  final Unit unit;
  final bool selected;
  final VoidCallback onTap;

  const _UnitRow({
    required this.colors,
    required this.unit,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            children: [
              Container(
                width: 52.0,
                height: 36.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? colors.accent
                      : colors.ink.withValues(
                          alpha: colors.isDark ? 0.08 : 0.05,
                        ),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: Text(
                      unit.symbol,
                      style: _display.copyWith(
                        fontSize: 18.0,
                        color: selected ? colors.bg : colors.ink,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14.0),
              Expanded(
                child: Text(
                  unit.name,
                  style: TextStyle(
                    fontFamily: 'Antonio',
                    fontSize: 17.0,
                    color: selected ? colors.accent : colors.ink,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.check_rounded, color: colors.accent, size: 20.0),
            ],
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
          Expanded(
            child: KeyButton(
              label: '+/-',
              color: colors.inkSoft,
              fontSize: 32.0,
              semanticLabel: 'Toggle sign',
              haptic: AppHaptics.utility,
              sound: AppSounds.utility,
              onTap: c.onToggleSign,
            ),
          ),
        ]),
        row([
          Expanded(
            child: KeyButton(
              label: 'ANS',
              color: colors.accent,
              fontSize: 28.0,
              semanticLabel: 'Use the calculator answer',
              haptic: AppHaptics.utility,
              sound: AppSounds.utility,
              onTap: () {
                final calc = ref.read(calculatorProvider);
                if (calc.error == null) c.loadValue(calc.resultText);
              },
            ),
          ),
          digit('0'),
          Expanded(
            child: KeyButton(
              label: '.',
              color: colors.ink,
              fontSize: 46.0,
              semanticLabel: 'Decimal point',
              sound: AppSounds.utility,
              onTap: c.onDecimal,
            ),
          ),
          Expanded(
            child: KeyButton(
              color: colors.accent,
              semanticLabel: 'Copy converted value',
              haptic: AppHaptics.utility,
              onTap: () => _copyToClipboard(
                context,
                ref.read(converterProvider).outputText,
              ),
              child: Icon(Icons.copy_rounded, color: colors.accent, size: 26),
            ),
          ),
        ]),
      ],
    );
  }
}
