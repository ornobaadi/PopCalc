import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/material_feel.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/splash/presentation/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load sounds with the saved settings so the splash can play right away.
  // Capped so a slow audio device can never hold up app launch.
  await SettingsNotifier.initAudio()
      .timeout(const Duration(milliseconds: 1500), onTimeout: () {});

  // Lock portrait orientation
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set edge-to-edge transparent system overlay
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    const ProviderScope(
      child: PopCalcApp(),
    ),
  );
}

class PopCalcApp extends ConsumerWidget {
  const PopCalcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    // A material brings its own sound and haptics; keep the engines in step
    // with whichever skin is active.
    applyMaterialFeel(ref.watch(materialFeelProvider));

    // A premium skin that is not owned (refunded, or the phone is on another
    // Google account now) cannot stay on. Listening here also starts the
    // store at launch, which is when it checks the Play account.
    void keepToOwnedSkin() {
      final purchases = ref.read(purchasesProvider);
      final skin = skinOf(ref.read(themeProvider));
      if (purchases.loaded && !ownsSkin(purchases.owned, skin)) {
        ref.read(themeProvider.notifier).setTheme(AppThemeMode.sunny);
      }
    }

    ref.listen(purchasesProvider, (_, _) => keepToOwnedSkin());
    ref.listen(themeProvider, (_, _) => keepToOwnedSkin());

    return MaterialApp(
      title: 'PopCalc',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getThemeData(themeMode),
      home: const SplashScreen(),
      builder: (context, child) {
        final isDark = AppTheme.colorsOf(themeMode).isDark;
        final icons = isDark ? Brightness.light : Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: icons,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
            systemNavigationBarColor: Colors.transparent,
            systemNavigationBarIconBrightness: icons,
          ),
          child: child!,
        );
      },
    );
  }
}
