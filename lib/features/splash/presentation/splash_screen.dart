import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';

/// Animated branded launch splash.
///
/// Bridged by the native flutter_native_splash screen during cold start, then
/// takes over and plays a short, tactile reveal of the PopCalc equals mark
/// before handing off to the calculator.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const _duration = Duration(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)
      ..forward().whenComplete(_goHome);
  }

  void _goHome() {
    if (!mounted) return;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 420),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const CalculatorScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity:
                CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final colors = AppTheme.colorsOf(themeMode);
    final isDark = themeMode == AppThemeMode.ink;

    final markAsset = isDark
        ? 'assets/brand_assets/logo/pop_calc_mark_dark_2048.png'
        : 'assets/brand_assets/logo/pop_calc_mark_2048.png';

    // Mark: springy pop + fade in (first 60%).
    final markScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    final markOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.4),
    );

    // Wordmark: pop in scale + fade (30% -> 90%).
    final wordmarkScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.30, 0.90, curve: Curves.easeOutBack),
      ),
    );
    final wordmarkOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.90),
    );

    return Scaffold(
      backgroundColor: colors.bg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: markScale,
              child: FadeTransition(
                opacity: markOpacity,
                child: Image.asset(
                  markAsset,
                  width: 96,
                  height: 96,
                  gaplessPlayback: true,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ScaleTransition(
              scale: wordmarkScale,
              child: FadeTransition(
                opacity: wordmarkOpacity,
                child: Text(
                  'POP CALC',
                  style: TextStyle(
                    fontFamily: 'Antonio',
                    fontWeight: FontWeight.w700,
                    fontSize: 22,
                    letterSpacing: 0.4,
                    color: colors.ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
