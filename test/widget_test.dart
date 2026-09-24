import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/main.dart';

void main() {
  testWidgets('Calculator smoke test - keys present and functional',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PopCalcApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    // Verify keypad keys are rendered
    expect(find.text('7'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('9'), findsOneWidget);
    expect(find.text('+'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(find.text('C'), findsOneWidget);

    // Tap 7, +, 8, =
    await tester.tap(find.text('7'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('+'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('8'));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('='));
    await tester.pump(const Duration(milliseconds: 100));
  });
}
