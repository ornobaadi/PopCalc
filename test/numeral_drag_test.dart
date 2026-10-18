import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/calculator/presentation/widgets/extruded_number.dart';
import 'package:popcalc/features/calculator/presentation/widgets/numeral_animator.dart';

/// The hero numerals: one solid block turned by a drag, a fling that eases
/// home, and a tap that still reaches [AnimatedExtrudedNumber.onTap].
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AppHaptics.enabled = false;
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final c in ['method', 'accelerometer', 'gyroscope', 'user_accel']) {
      messenger.setMockMethodCallHandler(
        MethodChannel('dev.fluttercommunity.plus/sensors/$c'),
        (_) async => null,
      );
    }
  });

  tearDown(() => AppHaptics.enabled = true);

  Future<void> pumpHero(
    WidgetTester tester, {
    String text = '1,234',
    bool isLite = false,
    VoidCallback? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              height: 260,
              child: AnimatedExtrudedNumber(
                text: text,
                colors: ThemeColors.of(AppThemeMode.ink),
                isLite: isLite,
                onTap: onTap,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  List<Offset>? tiltsNow(WidgetTester tester) =>
      tester.widget<ExtrudedNumber>(find.byType(ExtrudedNumber)).glyphTilts;

  testWidgets('at rest every digit faces straight on', (tester) async {
    await pumpHero(tester);
    final tilts = tiltsNow(tester)!;
    expect(tilts, hasLength('1,234'.length));
    for (final t in tilts) {
      expect(t, Offset.zero);
    }
  });

  testWidgets('a drag turns the whole number as one block', (tester) async {
    await pumpHero(tester);
    final hero = find.byType(AnimatedExtrudedNumber);
    final left = tester.getTopLeft(hero) + const Offset(40, 130);

    final gesture = await tester.startGesture(left);
    for (var i = 0; i < 8; i++) {
      await gesture.moveBy(const Offset(15, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));

    final tilts = tiltsNow(tester)!;
    expect(tilts.first.dx, greaterThan(0.2));
    // Wherever it is grabbed, every digit turns by the same amount.
    for (final t in tilts) {
      expect(t, tilts.first);
    }
    expect(tester.takeException(), isNull);

    await gesture.up();
  });

  testWidgets('a flick swings past the middle and settles back', (
    tester,
  ) async {
    await pumpHero(tester);
    await tester.fling(
      find.byType(AnimatedExtrudedNumber),
      const Offset(120, 0),
      1500,
    );

    // Wobbles through the other side on its way home.
    var crossed = false;
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (tiltsNow(tester)!.first.dx < -0.01) crossed = true;
    }
    expect(crossed, isTrue);

    await tester.pump(const Duration(seconds: 3));
    for (final t in tiltsNow(tester)!) {
      expect(t.distance, lessThan(0.01));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap still reaches onTap', (tester) async {
    var taps = 0;
    await pumpHero(tester, onTap: () => taps++);
    await tester.tap(find.byType(AnimatedExtrudedNumber));
    await tester.pump(const Duration(milliseconds: 50));
    expect(taps, 1);
  });

  testWidgets('lite mode stays flat', (tester) async {
    await pumpHero(tester, isLite: true);
    await tester.drag(
      find.byType(AnimatedExtrudedNumber),
      const Offset(100, 0),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tiltsNow(tester), isNull);
  });

  testWidgets('a new digit joins the turn', (tester) async {
    await pumpHero(tester, text: '12');
    await pumpHero(tester, text: '123');
    expect(tiltsNow(tester), hasLength(3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
  });
}
