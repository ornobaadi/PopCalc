import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final obsidian = skinOf(AppThemeMode.obsidian);
  final velvet = skinOf(AppThemeMode.velvet);

  test('every theme mode has a catalog entry', () {
    for (final mode in AppThemeMode.values) {
      expect(skinOf(mode).mode, mode);
    }
  });

  test('free skins are always owned', () {
    for (final skin in kSkins.where((s) => !s.premium)) {
      expect(ownsSkin(const {}, skin, locked: true), isTrue);
    }
  });

  test('premium skins need their product or the bundle', () {
    expect(ownsSkin(const {}, obsidian, locked: true), isFalse);
    expect(ownsSkin({obsidian.productId!}, obsidian, locked: true), isTrue);
    expect(ownsSkin({obsidian.productId!}, velvet, locked: true), isFalse);
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
      await first.read(entitlementProvider.notifier).buy(obsidian.productId!),
      isTrue,
    );
    expect(first.read(entitlementProvider), contains(obsidian.productId));

    final second = ProviderContainer();
    addTearDown(second.dispose);
    second.read(entitlementProvider);
    await Future<void>.delayed(Duration.zero);
    expect(second.read(entitlementProvider), contains(obsidian.productId));
  });
}
