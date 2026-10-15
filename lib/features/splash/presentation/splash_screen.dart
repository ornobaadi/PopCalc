import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/app_icon/app_icons.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';

/// Animated branded launch splash, continuing Android's launch screen.
///
/// Android 12+ draws the tapped launcher entry's icon (the user's chosen app
/// icon) in a 160 dp circle on the brand colour. The first frame here is that
/// same picture, so the hand-over is invisible; then the icon settles into a
/// rounded tile and the wordmark arrives before the calculator fades in.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  /// Android 12's launch screen shows an icon with a background as a
  /// 160 dp circle (the middle of a 240 dp canvas).
  static const double launchIconSize = 160.0;
  static const double tileSize = 96.0;

  /// The brand colours of the native launch screen
  /// (flutter_native_splash.yaml); they follow the device, not the skin.
  static Color background(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF141414) : const Color(0xFFFFAE00);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;

  /// Fallback in case the icon is slow to decode: an animation rather than a
  /// Timer, so it is torn down with the screen.
  late final AnimationController _patience;
  bool _begun = false;
  static const _duration = Duration(milliseconds: 1500);

  /// Read before the first frame (see `SettingsNotifier.initAudio`), so the
  /// icon is right from frame one; the saved settings load a moment later.
  final AppIconOption _icon = appIconOf(SettingsNotifier.bootAppIcon);
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration);
    _patience = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Only let Android's launch screen go once the icon is decoded, or the
    // first frame would be an empty background. Capped, so a slow decode
    // can never hold the app.
    unawaited(
      precacheImage(
        AssetImage(_icon.previewAsset),
        context,
      ).whenComplete(_begin),
    );
    _patience.forward().whenComplete(_begin);
  }

  void _begin() {
    if (_begun || !mounted) return;
    _begun = true;
    _patience.stop();
    FlutterNativeSplash.remove();
    // Launch "skrr": the typewriter carriage return, whichever pack is chosen.
    AppSounds.launch();
    _controller.forward().whenComplete(_goHome);
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
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _patience.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    final bg = SplashScreen.background(brightness);
    final ink = brightness == Brightness.dark
        ? const Color(0xFFF2EFE6)
        : const Color(0xFF141414);

    // Hold the launch-screen picture, then settle into the tile (22-62%);
    // the wordmark follows (45-90%).
    final settle = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.22, 0.62, curve: Curves.easeInOutCubic),
    );
    final word = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.90, curve: Curves.easeOutBack),
    );
    final wordFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.80),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = settle.value;
            final size = lerpDouble(
              SplashScreen.launchIconSize,
              SplashScreen.tileSize,
              t,
            )!;
            // Circle (radius = half) to a rounded tile (radius = a quarter).
            final radius = size * lerpDouble(0.5, 0.25, t)!;
            final lift = lerpDouble(0, 30, t)!;
            return SizedBox.expand(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.translate(
                    offset: Offset(0, -lift),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: Image.asset(
                        _icon.previewAsset,
                        width: size,
                        height: size,
                        gaplessPlayback: true,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  Transform.translate(
                    offset: Offset(0, SplashScreen.tileSize / 2 + 24 - 30 + 16),
                    child: Opacity(
                      opacity: wordFade.value.clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 0.8 + 0.2 * word.value,
                        child: Text(
                          'POP CALC',
                          style: TextStyle(
                            fontFamily: 'Antonio',
                            fontWeight: FontWeight.w700,
                            fontSize: 22,
                            letterSpacing: 0.4,
                            color: ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
