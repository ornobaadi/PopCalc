import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/engine/calc_error.dart';
import 'package:popcalc/features/calculator/application/calculator_controller.dart';
import 'package:popcalc/features/calculator/application/calculator_state.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';

/// Starts on a given state, so the screen can be checked without typing.
class _Fixed extends CalculatorController {
  _Fixed(CalculatorState s) {
    state = s;
  }
}

Future<void> _pump(WidgetTester tester, CalculatorState s) async {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final c in ['method', 'accelerometer', 'gyroscope', 'user_accel']) {
    messenger.setMockMethodCallHandler(
        MethodChannel('dev.fluttercommunity.plus/sensors/$c'), (_) async => null);
  }
  await tester.pumpWidget(ProviderScope(
    overrides: [calculatorProvider.overrideWith((ref) => _Fixed(s))],
    child: const MaterialApp(home: CalculatorScreen()),
  ));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  testWidgets('a setup line shows the reason, then "That\'s what she said"', (tester) async {
    await _pump(
      tester,
      const CalculatorState(
        error: CalcError.overflow,
        resultText: "IT WON'T FIT",
        errorPunchline: true,
      ),
    );
    expect(find.byKey(const ValueKey('error-punchline')), findsOneWidget);
    expect(find.text(kThatsWhatSheSaid), findsOneWidget);
    // The punchline sits directly under the setup, above the reason.
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('error-punchline'))).dy,
      lessThan(tester.getTopLeft(find.byKey(const ValueKey('error-reason'))).dy),
    );
    expect(find.text(CalcError.overflow.plainMessage), findsOneWidget);
  });

  testWidgets('other errors keep only the plain reason', (tester) async {
    await _pump(
      tester,
      const CalculatorState(error: CalcError.badLog, resultText: 'LOG SAYS NO'),
    );
    expect(find.byKey(const ValueKey('error-punchline')), findsNothing);
    expect(find.text(CalcError.badLog.plainMessage), findsOneWidget);
  });
}
