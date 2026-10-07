import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpScreen(WidgetTester tester, {required bool advanced}) async {
  SharedPreferences.setMockInitialValues({'settings_advanced_mode': advanced});
  tester.view.physicalSize = const Size(1080, 2340); // 360 × 780 dp phone
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    const ProviderScope(child: MaterialApp(home: CalculatorScreen())),
  );
  // Let settings load from SharedPreferences.
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> tapKey(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).last);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  testWidgets('Advanced mode off: no scientific keys or mode toggle',
      (tester) async {
    await pumpScreen(tester, advanced: false);
    expect(find.text('sin'), findsNothing);
    expect(find.text('CONVERT'), findsNothing);
    expect(find.text('DEG'), findsNothing);
    expect(find.text('7'), findsOneWidget);
  });

  testWidgets('Advanced mode on: scientific keys evaluate', (tester) async {
    await pumpScreen(tester, advanced: true);
    expect(find.text('sin'), findsOneWidget);
    expect(find.text('DEG'), findsOneWidget);

    await tapKey(tester, 'sin');
    await tapKey(tester, '3');
    await tapKey(tester, '0');
    await tapKey(tester, ')');
    await tapKey(tester, '=');
    expect(find.text('sin('), findsOneWidget);

    // 2nd flips the row to inverses
    await tapKey(tester, '2nd');
    expect(find.text('-1'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Convert tab shows the unit converter', (tester) async {
    await pumpScreen(tester, advanced: true);
    await tapKey(tester, 'CONVERT');
    expect(find.text('LENGTH'), findsOneWidget);
    expect(find.text('ANS'), findsOneWidget);
    expect(find.text('sin'), findsNothing);

    await tapKey(tester, '1');
    await tapKey(tester, '0');
    expect(find.text('6.21371192237334'), findsOneWidget); // 10 km in mi

    await tester.ensureVisible(find.text('TEMP'));
    await tester.pump();
    await tapKey(tester, 'TEMP');
    expect(find.text('50'), findsOneWidget); // 10 °C in °F

    await tapKey(tester, 'CALC');
    expect(find.text('sin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
