import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/settings/presentation/widgets/signature_footer.dart';

void main() {
  testWidgets('Footer shows the maker, signature and installed version',
      (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'PopCalc',
      packageName: 'com.ornobaadi.popcalc',
      version: '1.2.0',
      buildNumber: '5',
      buildSignature: '',
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: SignatureFooter(colors: ThemeColors.sunnyTheme),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('HANDCRAFTED BY'), findsOneWidget);
    expect(find.bySemanticsLabel('Ornob Aadi signature'), findsOneWidget);
    expect(find.text('POPCALC  ·  v1.2.0 (5)'), findsOneWidget);
    expect(find.text('LICENSES'), findsOneWidget);
  });
}
