// Renders the square store mockup for every skin into assets/skins/<mode>.png:
// the real calculator in that skin, inside a tilted phone frame.
//
//   flutter test tool/generate_skin_mockups.dart --update-goldens
//
// Re-run after changing a skin's colours or adding a skin.
// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _side = 600.0; // px, rendered at 1x
const _phone = Size(360.0, 780.0);

Future<void> _font(String family, String path) async {
  final bytes = File(path).readAsBytesSync();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.view(bytes.buffer)));
  await loader.load();
}

void main() {
  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final c in ['method', 'accelerometer', 'gyroscope', 'user_accel']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('dev.fluttercommunity.plus/sensors/$c'),
        (_) async => null,
      );
    }
  });

  // Only skins sold in the store need a mockup.
  for (final mode in _layouts.keys) {
    testWidgets('mockup ${mode.name}', (tester) async {
      await _font('BebasNeue', 'assets/fonts/BebasNeue-Regular.ttf');
      await _font('Antonio', 'assets/fonts/Antonio-VariableFont_wght.ttf');
      await _font('Inter', 'assets/fonts/Inter-VariableFont_opsz,wght.ttf');
      final flutterRoot = Platform.environment['FLUTTER_ROOT'];
      if (flutterRoot != null) {
        await _font(
          'MaterialIcons',
          '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
        );
      }
      // Tests paint shadows as solid blocks unless told otherwise.
      debugDisableShadows = false;
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(_side, _side);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = ProviderContainer(
        overrides: [
          themeProvider.overrideWith((ref) => ThemeNotifier.preview(mode)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            home: _Mockup(mode: mode),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      final calc = container.read(calculatorProvider.notifier);
      for (final d in ['1', '2', '8']) {
        calc.onDigit(d);
        await tester.pump(const Duration(milliseconds: 400));
      }
      await tester.pump(const Duration(seconds: 1));

      await expectLater(
        find.byType(_Mockup),
        matchesGoldenFile('../assets/skins/${mode.name}.png'),
      );
      debugDisableShadows = true; // the test binding checks it is restored
    });
  }
}

/// How one skin's mockup is composed: where the phone sits and where the
/// skin name goes behind it. Every skin gets its own angle.
class _Layout {
  final double dx, dy, angle, scale; // phone, pivoting on its top centre
  final double swing; // perspective turn around the phone's vertical axis
  final Rect name; // box the skin name is fitted into
  final int turns; // quarter turns of the name (1 reads down, 3 reads up)
  final Offset?
  disc; // backdrop centre, when the default hides behind the phone
  final double discRadius;
  const _Layout(
    this.dx,
    this.dy,
    this.angle,
    this.scale,
    this.swing,
    this.name,
    this.turns, {
    this.disc,
    this.discRadius = 218.0,
  });
}

const _layouts = <AppThemeMode, _Layout>{
  AppThemeMode.obsidian: _Layout(
    110.0,
    186.0,
    -0.34,
    1.1,
    -0.3,
    Rect.fromLTWH(34.0, 30.0, 340.0, 132.0),
    0,
  ),
  AppThemeMode.synthwave: _Layout(
    -110.0,
    186.0,
    0.34,
    1.1,
    0.3,
    Rect.fromLTWH(226.0, 30.0, 340.0, 132.0),
    0,
  ),
  AppThemeMode.matcha: _Layout(
    78.0,
    74.0,
    -0.2,
    0.96,
    0.4,
    Rect.fromLTWH(26.0, 34.0, 132.0, 532.0),
    3,
  ),
  AppThemeMode.frost: _Layout(
    0.0,
    214.0,
    0.0,
    1.04,
    0.0,
    Rect.fromLTWH(40.0, 26.0, 520.0, 164.0),
    0,
    disc: Offset(300.0, 474.0),
    discRadius: 272.0,
  ),
  AppThemeMode.velvet: _Layout(
    20.0,
    -400.0,
    -0.12,
    1.0,
    0.28,
    Rect.fromLTWH(40.0, 440.0, 520.0, 132.0),
    0,
  ),
};

class _Mockup extends StatelessWidget {
  final AppThemeMode mode;
  const _Mockup({required this.mode});

  static Widget _circle(
    Offset centre,
    double radius,
    BoxDecoration decoration,
  ) {
    return Positioned(
      left: centre.dx - radius,
      top: centre.dy - radius,
      width: radius * 2,
      height: radius * 2,
      child: DecoratedBox(decoration: decoration),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ThemeColors.of(mode);
    final skin = skinOf(mode);
    final layout = _layouts[mode]!;

    // Where the phone's middle lands, for the glow behind it.
    final glowCentre =
        layout.disc ??
        Offset(
          _side / 2 + layout.dx,
          layout.dy + _phone.height * layout.scale * 0.45,
        );
    final nameAlign = layout.turns != 0
        ? Alignment.center
        : layout.name.center.dx < 250.0
        ? Alignment.centerLeft
        : layout.name.center.dx > 350.0
        ? Alignment.centerRight
        : Alignment.center;

    return RepaintBoundary(
      child: Container(
        width: _side,
        height: _side,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(colors.bg, colors.extrudeSide, 0.06)!,
              Color.lerp(colors.bg, colors.extrudeSide, 0.26)!,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Behind the phone: dark skins glow in their accent, light ones
            // sit on a solid disc of their block colour.
            if (colors.isDark)
              _circle(
                glowCentre,
                380.0,
                BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      colors.accent.withValues(alpha: 0.32),
                      colors.accent.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              )
            else
              _circle(
                glowCentre,
                layout.discRadius,
                BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color.lerp(colors.extrudeSide, colors.bg, 0.25)!,
                      colors.extrudeSide,
                    ],
                  ),
                ),
              ),
            // Hairline orbit around it.
            _circle(
              glowCentre,
              colors.isDark ? 250.0 : layout.discRadius + 44.0,
              BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.ink.withValues(alpha: 0.16),
                  width: 1.5,
                ),
              ),
            ),
            Positioned.fromRect(
              rect: layout.name,
              child: RotatedBox(
                quarterTurns: layout.turns,
                child: Column(
                  crossAxisAlignment: nameAlign == Alignment.centerLeft
                      ? CrossAxisAlignment.start
                      : nameAlign == Alignment.centerRight
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: nameAlign,
                        child: Text(
                          skin.label,
                          style: TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 100.0,
                            height: 1.0,
                            letterSpacing: 3.0,
                            color: colors.accent,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      'POPCALC  /  ${skin.modelCode}',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.0,
                        height: 1.2,
                        letterSpacing: 4.0,
                        color: colors.inkSoft,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: OverflowBox(
                alignment: Alignment.topCenter,
                minWidth: _phone.width,
                maxWidth: _phone.width,
                minHeight: _phone.height,
                maxHeight: _phone.height,
                child: Transform(
                  alignment: Alignment.topCenter,
                  transform: Matrix4.identity()
                    ..translateByDouble(layout.dx, layout.dy, 0.0, 1.0)
                    ..multiply(Matrix4.identity()..setEntry(3, 2, 0.0009))
                    ..rotateZ(layout.angle)
                    ..rotateY(layout.swing)
                    ..scaleByDouble(layout.scale, layout.scale, 1.0, 1.0),
                  child: _Phone(colors: colors, swing: layout.swing),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The phone, built like the app's numerals: a face in the skin's
/// `extrudeTop` on a solid block of `extrudeSide`.
class _Phone extends StatelessWidget {
  static const _depth = 16;
  static const _bezel = 8.0;
  static const _radius = 54.0;

  final ThemeColors colors;
  final double swing;
  const _Phone({required this.colors, required this.swing});

  @override
  Widget build(BuildContext context) {
    final side = swing < 0 ? -1.0 : 1.0;
    Offset layer(int i) => Offset(side * i * 1.5, i * 0.9);
    final edgeDark = Color.lerp(colors.extrudeSide, Colors.black, 0.28)!;

    return SizedBox(
      width: _phone.width,
      height: _phone.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Soft shadow under the whole block.
          Transform.translate(
            offset: layer(_depth),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(_radius),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x52000000),
                    blurRadius: 56.0,
                    spreadRadius: -4.0,
                    offset: Offset(side * 14.0, 30.0),
                  ),
                ],
              ),
            ),
          ),
          // Extruded block, darker towards the back.
          for (var i = _depth; i >= 1; i--)
            Transform.translate(
              offset: layer(i),
              child: Container(
                decoration: BoxDecoration(
                  color: Color.lerp(colors.extrudeSide, edgeDark, i / _depth),
                  borderRadius: BorderRadius.circular(_radius),
                ),
              ),
            ),
          // Face.
          Container(
            padding: const EdgeInsets.all(_bezel),
            decoration: BoxDecoration(
              color: colors.extrudeTop,
              borderRadius: BorderRadius.circular(_radius),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_radius - _bezel),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MediaQuery(
                    data: MediaQueryData(
                      size: Size(
                        _phone.width - _bezel * 2,
                        _phone.height - _bezel * 2,
                      ),
                      padding: const EdgeInsets.only(top: 18.0),
                    ),
                    child: const CalculatorScreen(),
                  ),
                  // Glass sheen across the top corner.
                  IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: side > 0
                              ? Alignment.topLeft
                              : Alignment.topRight,
                          end: Alignment.center,
                          colors: const [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
