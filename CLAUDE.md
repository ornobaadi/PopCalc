# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

PopCalc — offline, Android-first Flutter calculator with extruded 3D numerals, tactile motion, sounds and haptics. Portrait, except that scientific mode may turn sideways. Version lives in `pubspec.yaml` (`version: x.y.z+build`); user-facing notes go in `RELEASE_NOTES.md`.

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

One setting, **Scientific & Converter** (`settings_advanced_tools`), puts two top-bar buttons in place. **Scientific** adds `^`, parentheses (auto-closed on evaluate), functions (`TokenType.function`, text includes the `(`, e.g. `sin(`), constants `π`/`e` and `!`; implicit multiplication (`2π`, `2(3)`) is handled in the parser, but two bare numbers stay malformed. Arithmetic, integer powers and factorials stay exact; trig/log/roots/fractional powers go through `dart:math` and are rounded to 15 significant digits. Trig takes an `AngleUnit` (`settings_angle_unit`, toggled by the DEG/RAD badge in the display). The top-bar f(x) button flips between simple and scientific keys (`settings_scientific_active`). Keys live in `widgets/scientific_tray.dart` (second row folds away, `settings_scientific_expanded`; the swap key ⇄ flips to the inverse layer). **Landscape**: `CalculatorScreen._allowLandscape` unlocks rotation only while scientific mode is showing (the converter forces portrait while open). Sideways on a phone the screen becomes three columns, display / `ScientificTray(grid: true)` / keypad; the grid shows both layers at once (4 × 5, with a DEG/RAD key instead of the badge), so it has no swap key. **Unit Converter**: the ruler button pushes `features/converter/presentation/converter_screen.dart`; unit data is `lib/core/units/` (pure Dart, exact `Rational` factors, temperature uses an offset).

**`CalculatorController`** (`features/calculator/application/calculator_controller.dart`, largest logic file) drives everything: key input, live preview, evaluate, token selection/in-place editing (`editingTokenIndex`, `isReplacingEditedToken`), and pushes completed calculations to history via an `onHistoryAdded` callback wired in `calculatorProvider`. State is `CalculatorState` with `copyWith`.

**Storage** (`core/storage/`):
- `settingsProvider` / `SettingsNotifier` — `shared_preferences`, keys prefixed `settings_*` (live preview, haptics on/strength, lite mode, sound on/volume/pack). `SettingsNotifier.initAudio()` is called in `main()` before `runApp` (with a 1.5 s timeout) so the splash can play sound.
- `historyProvider` — JSON history file via `path_provider`.
- `themeProvider` + `core/theme/`: `AppThemeMode` enum (index persisted — only append new values), `ThemeColors.of(mode)` resolves tokens (incl. `isDark`, `burst`). Adding a skin = enum value + `ThemeColors` const + switch case + `SkinOption` in `settings_sheet.dart`. Skin names: Charcoal (ink), Marigold (sunny), Peony, Obsidian, Synthwave, Matcha, Frost, Velvet. Never use the names "Andy" or "Graphite".

**Audio** (`core/audio/app_sounds.dart`): static `AppSounds` on `flutter_soloud`; sound packs `pop`, `mellow`, `typewriter` in `assets/sounds/<pack>/` (digit_0..9, operator, utility, backspace, clear, success, error). Sound plays for keys (main keypad, scientific tray, converter keypad), results, the launch and converter swipe detents; toggles, settings, DEG/RAD and converter taps are haptics only. Scientific keys have one sound per kind (trig, log, power, root, bracket_open/close, constant, factorial, shift_on/off) with a matching `AppHaptics` pattern as firm as the main keypad. Shared sounds outside the packs: `launch.wav` (copy of the typewriter `clear` "skrr", `AppSounds.launch()`) and `detent.wav` (`AppSounds.detent()`, the converter's swipe-to-step notches, paired with `AppHaptics.detent()`). All sounds are procedurally generated by `tool/generate_sounds.py` (pentatonic digits) — regenerate rather than hand-editing WAVs. New packs must also be listed under `flutter.assets` in `pubspec.yaml`.

**Haptics** (`core/haptics/app_haptics.dart`): uses a native `MethodChannel('popcalc/haptics')` implemented in `android/app/src/main/kotlin/com/ornobaadi/popcalc/MainActivity.kt` (composed primitives on Android 11+, waveform fallback). Changing haptic patterns may require editing both sides.

**UI** (`features/calculator/presentation/widgets/`): `extruded_number.dart` (CustomPainter 3D numerals), `numeral_animator.dart` (typing/change animations), `celebration_burst.dart` (answer celebration), `expression_line.dart` (tappable tokens for editing), `keypad.dart`/`key_button.dart`, `grain_overlay.dart` (texture). Tilt parallax via `flutter_tilt`/`sensors_plus`. "Lite mode" setting disables heavy effects. App starts at `features/splash`, then the calculator screen; history and settings are bottom sheets.

Fonts: BebasNeue and Antonio (bundled). Privacy policy HTML in `docs/`.
