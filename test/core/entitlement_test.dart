import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final matcha = skinOf(AppThemeMode.matcha);
  final velvet = skinOf(AppThemeMode.velvet);

  test('every theme mode has a catalog entry', () {
    for (final mode in AppThemeMode.values) {
      if (kRetiredThemes.contains(mode)) continue;
      expect(skinOf(mode).mode, mode);
    }
  });

  test('a saved retired skin loads as Marigold, a live one as itself', () async {
    Future<AppThemeMode> loaded(AppThemeMode saved) async {
      SharedPreferences.setMockInitialValues({'settings_theme_mode': saved.index});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(themeProvider);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return c.read(themeProvider);
    }

    expect(await loaded(AppThemeMode.chrome), AppThemeMode.chrome);
    for (final retired in kRetiredThemes) {
      expect(await loaded(retired), AppThemeMode.sunny);
    }
  });

  test('free skins are always owned', () {
    for (final skin in kSkins.where((s) => !s.premium)) {
      expect(ownsSkin(const {}, skin, locked: true), isTrue);
    }
  });

  test('premium skins need their product or the bundle', () {
    expect(ownsSkin(const {}, matcha, locked: true), isFalse);
    expect(ownsSkin({matcha.productId!}, matcha, locked: true), isTrue);
    expect(ownsSkin({matcha.productId!}, velvet, locked: true), isFalse);
    expect(ownsSkin({kAllThemesProductId}, velvet, locked: true), isTrue);
  });

  test('unlocked catalog owns everything', () {
    for (final skin in kSkins) {
      expect(ownsSkin(const {}, skin, locked: false), isTrue);
    }
  });

  test('purchases survive a reload', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    addTearDown(first.dispose);
    expect(
      await first.read(purchasesProvider.notifier).buy(matcha.productId!),
      BuyOutcome.purchased,
    );
    expect(first.read(entitlementProvider), contains(matcha.productId));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(entitlementProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(entitlementProvider), contains(matcha.productId));
  });
}
