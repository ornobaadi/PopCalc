# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PopCalc — offline, Android-first Flutter calculator with extruded 3D numerals, tactile motion, sounds and haptics. Portrait-only. Version lives in `pubspec.yaml` (`version: x.y.z+build`); user-facing notes go in `RELEASE_NOTES.md`.

Design/product docs at repo root: `PRD.md`, `design.md`, `architecture.md`, `phases.md`. Note: `architecture.md` is a **plan** — it describes things not yet built (Pro/in-app purchase, golden tests, `app/` folder, theme picker). Trust `lib/` over it.

## Commands

```bash
flutter pub get
flutter run                                        # Android device/emulator
flutter analyze                                    # lints: flutter_lints
flutter test                                       # all tests
flutter test test/engine/engine_test.dart          # single file
flutter test --plain-name "some test name"         # single test by name
flutter build apk --release                        # or appbundle
dart run flutter_native_splash:create              # after editing flutter_native_splash.yaml
python tool/generate_sounds.py                     # regenerate assets/sounds/<pack>/*.wav
```

`flutter_soloud` is pinned to 4.x on purpose: 5.x uses native build hooks requiring a host C++ toolchain (Visual Studio) just to run `flutter test`. Don't upgrade it.

## Architecture

Feature-first layout: `lib/core/*` (shared services) and `lib/features/<feature>/{application,presentation}`. State management is Riverpod **`StateNotifierProvider`** (not the newer Notifier API).

**Math engine (`lib/core/engine/`) is pure Dart — no Flutter imports.** Pipeline:
`Expression` (immutable token list + `currentNumber` being typed; editing rules, limits of 15 digits/number, 60 tokens) → `Parser` (tokens → AST, `ast.dart`) → `Evaluator` (AST → `Decimal`, exact base-10; percent semantics depend on the neighboring operator) → `NumberFormatter` (display strings). Errors are `CalcError`. Tests for this live in `test/engine/`.

One setting, **Scientific & Converter** (`settings_advanced_tools`), puts two top-bar buttons in place. **Scientific** adds `^`, parentheses (auto-closed on evaluate), functions (`TokenType.function`, text includes the `(`, e.g. `sin(`), constants `π`/`e` and `!`; implicit multiplication (`2π`, `2(3)`) is handled in the parser, but two bare numbers stay malformed. Arithmetic, integer powers and factorials stay exact; trig/log/roots/fractional powers go through `dart:math` and are rounded to 15 significant digits. Trig takes an `AngleUnit` (`settings_angle_unit`, toggled by the DEG/RAD badge in the display). The top-bar f(x) button flips between simple and scientific keys (`settings_scientific_active`). Keys live in `widgets/scientific_tray.dart` (second row folds away, `settings_scientific_expanded`). **Unit Converter**: the ruler button pushes `features/converter/presentation/converter_screen.dart`; unit data is `lib/core/units/` (pure Dart, exact `Rational` factors, temperature uses an offset).

**`CalculatorController`** (`features/calculator/application/calculator_controller.dart`, largest logic file) drives everything: key input, live preview, evaluate, token selection/in-place editing (`editingTokenIndex`, `isReplacingEditedToken`), and pushes completed calculations to history via an `onHistoryAdded` callback wired in `calculatorProvider`. State is `CalculatorState` with `copyWith`.

**Storage** (`core/storage/`):
- `settingsProvider` / `SettingsNotifier` — `shared_preferences`, keys prefixed `settings_*` (live preview, haptics on/strength, lite mode, sound on/volume/pack). `SettingsNotifier.initAudio()` is called in `main()` before `runApp` (with a 1.5 s timeout) so the splash can play sound.
- `historyProvider` — JSON history file via `path_provider`.
- `themeProvider` + `core/theme/`: `AppThemeMode` enum (index persisted — only append new values), `ThemeColors.of(mode)` resolves tokens (incl. `isDark`, `burst`). Adding a skin = enum value + `ThemeColors` const + switch case + `SkinInfo` in `core/theme/skin_catalog.dart` (label, tagline, description, model code, and a `productId` if it is premium) + a `_Layout` in `tool/generate_skin_mockups.dart`, then regenerate the mockups. Skin names: Charcoal (ink), Marigold (sunny), Peony, Obsidian, Synthwave, Matcha, Frost, Velvet. Never use the names "Andy" or "Graphite".
- **Materials** (Clay, Chrome, Glass, Wood, Candy, Neon, Mechanical): exclusive sets of look + sound + haptics, sold singly or in the everything bundle, and never mixed with other skins or sound packs. They are `kMaterials` in `skin_catalog.dart` (a `SkinInfo` with one or more `MaterialFeel`s; Mechanical has three: clicky, tactile, linear, chosen with `settings_mech_switch`). The eight ordinary skins and the three sound packs are deliberately untouched by this. How the three parts hang together:
  - *Look*: an `AppThemeMode` + `ThemeColors` like any skin, plus `ThemeColors.finish` (`SkinFinish`): `extruded_number.dart` lays a gradient over the numeral face (`_finishShader`) and a halo for neon; `keycap` instead makes `KeyButton` draw keycaps via `KeycapScope` (wrapped round the keypad).
  - *Sound*: folders under `assets/sounds/` (`clay`, …, `mech_clicky`, `mech_tactile`, `mech_linear`) generated by `MATERIAL_PACKS` in `tool/generate_sounds.py`, each with its own RNG seed so adding one never changes existing WAVs. They are not `SoundPack` values and never appear in the pack picker; `AppSounds.setMaterial(folder)` overrides the chosen pack and loads the folder on first use.
  - *Haptics*: `HapticFeel` in `app_haptics.dart` swaps the patterns for digit, operator, utility and backspace (same native primitives, no Kotlin change).
  - *Applying*: `materialFeelProvider` (`core/theme/material_feel.dart`) derives the feel from the active skin, and `PopCalcApp` calls `applyMaterialFeel` on every build, so setting the skin is all it takes. In settings, the sound-pack chips are replaced by a note, or by the switch chips for Mechanical. The everything bundle (`themes_all`, `kBundleItems`) unlocks every premium skin and every material; each can also be bought singly.
  - Adding a material = enum value + `ThemeColors` (with a finish) + switch case + `kMaterials` entry + a pack in `MATERIAL_PACKS` and its folder in `pubspec.yaml` + a `HapticFeel` + a `_Layout` for its mockup.
- **Skin store** (`features/themes/presentation/`): `theme_store_screen.dart` (materials and premium skins; free ones stay in the settings grid, as do materials once owned. `BundleCarousel`: an endless wheel of mockups that turns by itself every `BundleCarousel.dwell`, moves exactly one skin per swipe, and recolours only its own box to the front skin; it shows no price, and tapping it opens `theme_bundle_sheet.dart` (where the bundle is bought, and each thumbnail opens that skin's sheet); it is driven by an unbounded `AnimationController`, not a `PageView`. Then square skin cards; opened from the settings sheet), `theme_card.dart` (`SkinMockup` shows `assets/skins/<mode>.png`: square 600 px mockups, materials and premium skins, of the real calculator in an extruded phone with the skin name in its accent colour, rendered by `flutter test tool/generate_skin_mockups.dart --update-goldens`; regenerate after changing a skin's colours rather than editing the PNGs), `theme_detail_sheet.dart` (per-skin sheet drawn in that skin's colours: buy / apply), `theme_preview_overlay.dart` (hold to preview: the real `CalculatorScreen` in a nested `ProviderScope` that overrides `themeProvider` with `ThemeNotifier.preview`, so the saved skin is untouched). Ownership is `entitlementProvider` in `core/storage/entitlement_store.dart` (set of owned product ids, `ownsSkin`), behind a `PurchaseService` interface. The only implementation is `FakePurchaseService` (grants for free, placeholder prices, stored in `settings_owned_products`); real Play Billing is not built. `kPremiumLocked` in `skin_catalog.dart` turns locking on; **set it to `false` for any release until real billing exists.**

**Audio** (`core/audio/app_sounds.dart`): static `AppSounds` on `flutter_soloud`; sound packs `pop`, `mellow`, `typewriter` in `assets/sounds/<pack>/` (digit_0..9, operator, utility, backspace, clear, success, error). Sound plays for keys (main keypad, scientific tray, converter keypad), results, the launch and converter swipe detents; toggles, settings, DEG/RAD and converter taps are haptics only. Scientific keys have one sound per kind (trig, log, power, root, bracket_open/close, constant, factorial, shift_on/off) with a matching `AppHaptics` pattern as firm as the main keypad. Shared sounds outside the packs: `launch.wav` (copy of the typewriter `clear` "skrr", `AppSounds.launch()`) and `detent.wav` (`AppSounds.detent()`, the converter's swipe-to-step notches, paired with `AppHaptics.detent()`). All sounds are procedurally generated by `tool/generate_sounds.py` (pentatonic digits) — regenerate rather than hand-editing WAVs. New packs must also be listed under `flutter.assets` in `pubspec.yaml`.

**Haptics** (`core/haptics/app_haptics.dart`): uses a native `MethodChannel('popcalc/haptics')` implemented in `android/app/src/main/kotlin/com/ornobaadi/popcalc/MainActivity.kt` (composed primitives on Android 11+, waveform fallback). Changing haptic patterns may require editing both sides.

**UI** (`features/calculator/presentation/widgets/`): `extruded_number.dart` (CustomPainter 3D numerals), `numeral_animator.dart` (typing/change animations), `celebration_burst.dart` (answer celebration), `expression_line.dart` (tappable tokens for editing), `keypad.dart`/`key_button.dart`, `grain_overlay.dart` (texture). Tilt parallax via `flutter_tilt`/`sensors_plus`. "Lite mode" setting disables heavy effects. App starts at `features/splash`, then the calculator screen; history and settings are bottom sheets.

Fonts (bundled): BebasNeue for headings, keys and numerals; Inter for body text, descriptions and small labels; Antonio only for the lowercase `e` constant, as a numeral fallback and the splash wordmark. Inter is much wider than the other two, so size it about 12% smaller than you would Antonio. Privacy policy HTML in `docs/`.
