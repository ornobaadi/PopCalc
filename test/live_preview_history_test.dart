import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/storage/history_store.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Live preview saves to history when app is paused', (tester) async {
    SharedPreferences.setMockInitialValues({'settings_show_live_preview': true});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: CalculatorScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Type 1 + 2
    await tester.tap(find.text('1'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('+'));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('2'));
    await tester.pump(const Duration(milliseconds: 50));

    // Live preview shows 3 without tapping =
    expect(container.read(historyProvider), isEmpty);

    // Simulate app being paused / sent to background
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(milliseconds: 100));

    // Verify history recorded the pending preview
    final history = container.read(historyProvider);
    expect(history.length, 1);
    expect(history.first.expression, '1 + 2');
    expect(history.first.result, '3');
  });
}
