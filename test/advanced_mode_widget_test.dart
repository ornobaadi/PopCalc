import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpScreen(WidgetTester tester, {bool tools = false}) async {
  SharedPreferences.setMockInitialValues({'settings_advanced_tools': tools});
  tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp phone
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
  );
  // Let settings load from SharedPreferences.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  // Let the scientific tray finish easing in.
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('Tools off: plain calculator', (tester) async {
    await pumpScreen(tester);
    expect(find.text('sin'), findsNothing);
    expect(find.text('DEG'), findsNothing);
    expect(find.byTooltip('Unit converter'), findsNothing);
    expect(find.bySemanticsLabel('Scientific keys'), findsNothing);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('Tools on: both top-bar buttons and the tray', (tester) async {
    await pumpScreen(tester, tools: true);
    expect(find.bySemanticsLabel('Scientific keys'), findsOneWidget);
    expect(find.byTooltip('Unit converter'), findsOneWidget);
    expect(find.text('sin'), findsOneWidget);
    expect(find.text('DEG'), findsOneWidget);

    await tapKey(tester, 'sin');
    await tapKey(tester, '3');
    await tapKey(tester, '0');
    await tapKey(tester, ')');
    await tapKey(tester, '=');
    expect(find.text('sin('), findsOneWidget);

    // The swap key flips the keys to inverses
    await tester.tap(find.bySemanticsLabel('More functions'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('-1'), findsNWidgets(3));

    // DEG badge switches to radians
    await tapKey(tester, 'DEG');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RAD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Top-bar f(x) switches between simple and scientific', (
    tester,
  ) async {
    await pumpScreen(tester, tools: true);
    final toggle = find.bySemanticsLabel('Scientific keys');
    expect(toggle, findsOneWidget);
    expect(find.text('sin'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('sin'), findsNothing);
    expect(find.text('DEG'), findsNothing);

    await tester.tap(toggle);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('sin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tray handle folds the second row away', (tester) async {
    await pumpScreen(tester, tools: true);
    expect(find.text('log'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Show fewer scientific keys'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('log'), findsNothing);
    expect(find.text('π'), findsOneWidget);
  });

  testWidgets('Converter button opens its own screen', (tester) async {
    await pumpScreen(tester, tools: true);
    await tester.tap(find.byTooltip('Unit converter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('CONVERT'), findsOneWidget);
    expect(find.text('ANS'), findsOneWidget);

    await tapKey(tester, '1');
    await tapKey(tester, '0');
    expect(find.text('6.21371192237334'), findsOneWidget); // 10 km in mi

    await tester.ensureVisible(find.text('TEMP'));
    await tester.pump();
    await tapKey(tester, 'TEMP');
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('50'), findsOneWidget); // 10 °C in °F

    await tester.tap(find.byTooltip('Back to calculator'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('CONVERT'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Swiping a unit steps through the list', (tester) async {
    await pumpScreen(tester, tools: true);
    await tester.tap(find.byTooltip('Unit converter'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // Length opens on kilometre → mile; one notch up moves past kilometre.
    final from = find.bySemanticsLabel(RegExp(r'^Kilometre\. Change unit'));
    expect(from, findsOneWidget);
    await tester.drag(from, const Offset(0, -60));
    await tester.pump(const Duration(milliseconds: 300));
    expect(from, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sideways: every scientific key at once, no swap key', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'settings_advanced_tools': true});
    tester.view.physicalSize = const Size(2400, 1080); // 800 × 360 dp
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 400));

    // Both layers are laid out together.
    for (final label in [
      'Sine',
      'Inverse sine',
      'Square',
      'Power',
      'Square root',
      'Cube root',
      'Natural log',
      'e to the power',
      'Pi',
      'Euler number',
      'Factorial',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
    }
    expect(find.bySemanticsLabel('More functions'), findsNothing);
    expect(find.text('7'), findsOneWidget);

    // An inverse works straight away, and the angle key switches units.
    await tester.tap(find.bySemanticsLabel('Inverse sine'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('sin⁻¹('), findsOneWidget);

    await tester.tap(find.text('DEG'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('RAD'), findsOneWidget);
  });

  testWidgets('Sideways without scientific mode keeps the upright layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(2400, 1080);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.bySemanticsLabel('Sine'), findsNothing);
    expect(find.text('7'), findsOneWidget);
  });
}
