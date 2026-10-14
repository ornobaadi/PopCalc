# CLAUDE.md

Complete working documentation for PopCalc. It exists so a session never has to re-read the codebase to find out what is where. **Read this first; open source files only to edit them.**

## Standing rules for Claude (from the owner)

1. **After every change, however small, update this file in the same session**: the file map, the relevant section, the "Where to change X" table if a location moved, and a dated line in [Change log](#change-log). If you add a file, a setting key, a provider, a sound, a skin, a test, a gotcha — it goes here.
2. **Pull `main` before starting work** (`git fetch origin && git pull --ff-only origin main`). `macos/Flutter/GeneratedPluginRegistrant.swift` is a perpetual unrelated local modification; ignore it, never commit it.
3. **Never run `flutter build …`** (apk/appbundle). Give the user the command in a `bash` block and let them run it. `flutter analyze` and `flutter test` are fine to run.
4. Skin names: Charcoal (ink), Marigold (sunny), Blueprint, Obsidian, Synthwave, Matcha, Frost, Velvet; secret: Newsprint. Peony and Prism are gone. Never use the names "Andy" or "Graphite".
5. `flutter_soloud` stays pinned to 4.x (5.x needs a host C++ toolchain just to run `flutter test`). Don't upgrade it.
6. Don't trust `architecture.md` (a plan, partly different from what was built). Trust `lib/`.
7. No phone/emulator has ever been connected in a session: verify UI with widget tests / test-rendered screenshots (recipe below). Sounds, haptics, landscape and real Play purchases have never been tried on hardware; say so when reporting.

## Project at a glance

PopCalc — offline, Android-first Flutter calculator with extruded 3D numerals, tactile motion, sounds and haptics. No ads, no account, no data collected. Package `com.ornobaadi.popcalc` (debug/profile get `.dev` suffix and label "PopCalc Dev"). Dart SDK `^3.13.4`, so Dart 3 syntax is used freely (null-aware elements `?x`, wildcard params `(_, _)`, records, switch expressions).

- **Version**: `pubspec.yaml` `version: 1.4.1+13`. Must be repeated by hand in `_SignatureFooter._appVersion` (`'1.4.1'` — **version name only, never the build number**; `lib/features/settings/presentation/settings_sheet.dart`), `README.md` and a new entry at the top of `RELEASE_NOTES.md`.
- **Portrait-only, except scientific mode**, which may rotate to landscape (see [Orientation](#orientation)). The converter, splash, store and history are portrait.
- **Skins**: 3 free (Marigold, Charcoal, Blueprint) + 5 premium skins + 7 "materials" (premium; look + sound + haptics as one set) + 1 secret skin (Newsprint, found not bought) = 16 `AppThemeMode`s. Premium ones are one-time Google Play products, plus an "everything" bundle.
- **Test status** (2026-10-15): `flutter test` → 231 tests, all pass.
- Docs at repo root: `PRD.md`, `design.md`, `architecture.md` (plan, unreliable), `phases.md`, `README.md`, `RELEASE_NOTES.md` (user-facing notes + Play "What's new" ≤500 chars per release), `docs/privacy-policy.html`.

## Commands

```bash
flutter pub get
flutter run                                        # Android device/emulator (debug = FakePurchaseService)
flutter analyze                                    # flutter_lints; android/ ios/ web/ etc. excluded
flutter test                                       # all tests (~20 s)
flutter test test/engine/engine_test.dart          # single file
flutter test --plain-name "some test name"         # single test by name
flutter build apk --release                        # or appbundle — USER RUNS THESE, not Claude
dart run flutter_native_splash:create              # after editing flutter_native_splash.yaml
python tool/generate_sounds.py                     # regenerate assets/sounds/**/*.wav
```

Release signing reads `android/key.properties` (+ `android/app/popcalc.keystore`); both are local secrets, never commit or print them. `android/*.log` (`hs_err_pid*`, `replay_pid*`) are JVM crash junk.

## Folder map

```
lib/
  main.dart                              entry; PopCalcApp (MaterialApp, skin fallback, system bars)
  core/
    engine/        token, expression, parser, ast, evaluator, formatter, calc_error   (PURE DART)
    units/         units.dart                                                          (PURE DART)
    storage/       settings_store, history_store, entitlement_store, play_purchase_service
    theme/         theme_tokens, app_theme, skin_catalog, material_feel
    audio/         app_sounds.dart
    haptics/       app_haptics.dart
  features/
    calculator/application/   calculator_controller, calculator_state
    calculator/presentation/  calculator_screen + widgets/ (keypad, key_button, top_bar,
                              scientific_tray, expression_line, extruded_number,
                              numeral_animator, celebration_burst, ink_spill, grain_overlay, backspace_icon)
    converter/application/    converter_controller
    converter/presentation/   converter_screen
    history/presentation/     history_sheet
    settings/presentation/    settings_sheet, hunt_note_sheet
    splash/presentation/      splash_screen
    themes/presentation/      theme_store_screen, theme_detail_sheet, theme_bundle_sheet,
                              theme_card, theme_preview_overlay, store_widgets, purchase_feedback
test/        engine/, core/, units/, + widget tests (see Tests)
tool/        generate_sounds.py
assets/      fonts/, sounds/<folder>/, textures/noise.png, splash/,
             brand_assets/, ornob-aadi-signature/, readme/, licenses/
android/app/src/main/kotlin/com/ornobaadi/popcalc/MainActivity.kt   native haptics channel
```

Layering rule: `core/engine` and `core/units` import **no Flutter**. Feature-first otherwise; state is Riverpod **`StateNotifierProvider`** everywhere (not the newer Notifier API). Fonts (bundled): **BebasNeue** headings/keys/numerals, **Inter** body/descriptions/small labels (≈12% wider than Antonio/Bebas, size it ~12% smaller), **Antonio** only for the lowercase `e` constant, numeral fallback and splash wordmark (Bebas is caps-only).

## App startup flow

`main()` → `WidgetsFlutterBinding.ensureInitialized` → `SettingsNotifier.initAudio()` (reads prefs, `AppSounds.init`, **1.5 s timeout** so audio can never block launch) → lock portrait → transparent system bars → `runApp(ProviderScope(PopCalcApp))`.

`PopCalcApp` (ConsumerWidget): watches `themeProvider`; calls `applyMaterialFeel(ref.watch(materialFeelProvider))` **inside build** (side effect on every rebuild, idempotent); `ref.listen`s purchases and theme to `keepToOwnedSkin()` — if purchases are `loaded` and the active skin is not owned, `setTheme(AppThemeMode.sunny)` (Marigold). Watching `purchasesProvider` here is also what starts the store at launch. `builder` wraps in `AnnotatedRegion<SystemUiOverlayStyle>` so status/nav icon brightness follows `colors.isDark`. Home is `SplashScreen`.

`SplashScreen`: `AppSounds.launch()` (typewriter "skrr"), 1500 ms animation (mark pop 0–60 %, "POP CALC" wordmark 30–90 %, Antonio w700), then `_goHome`: re-lock portrait, `pushReplacement` to `CalculatorScreen` with a 420 ms fade. Native splash colours/images: `flutter_native_splash.yaml` (#FFAE00 light / #141414 dark; follows device setting, not the in-app skin).

## Math engine (`lib/core/engine/`, pure Dart)

Pipeline: `Expression` (immutable) → `Parser` → AST → `Evaluator` → `Decimal` → `NumberFormatter`. Errors are `CalcError` (`calc_error.dart`): `divideByZero` (`5÷0`, `0^-1`), `zeroByZero` (`0÷0`), `overflow` (past 1000 digits, `n!` with n > 450, double ∞), `negativeRoot` (`√(-4)`, negative base to a fractional power), `badLog` (`ln`/`log` of ≤ 0), `badInverseTrig` (`sin⁻¹`/`cos⁻¹` outside −1..1), `tanUndefined` (`tan 90°`, `tan π/2`), `badFactorial` (`2.5!`, `(-3)!`), `invalidExpression` (malformed, NaN). Each has `plainMessage` (sober reason, used as the screen-reader label) and `messages`: a pool of 3-5 fun lines shown in the hero numerals. **Lines must be CAPITALS (Bebas has no lowercase) and ≤ 19 characters** (a test enforces both). **How an error is shown** (so it never passes for a result): the line is set much smaller than a number (`ExtrudedNumber.maxFontSize` 60 instead of 200) with a shallow block (depth × 0.4), both applied in `numeral_animator.dart` when `hasError`; and `calculator_screen.dart` puts `plainMessage` under it in small Inter (`ValueKey('error-reason')`, 54 px below centre). No warning colour is used. The evaluator throws `CalcException(error)`. Not errors, silent by design: the 15-digit and 60-token limits, `=` on a dangling `sin(`.

**`token.dart`**: `TokenType {number, plus, minus, multiply, divide, percent, power, leftParen, rightParen, function, constant, factorial}`. `Token(type, text)` with `==`/hashCode. Helpers: `isOperator` (+ − × ÷ ^), `isNumber`, `isPercent`, `isOpener` (leftParen or function), `endsOperand` (number, percent, rightParen, constant, factorial), `functionName` (text minus trailing `(`; function token text includes the `(`, e.g. `sin(`). Operator symbols: `+`, `-` (ASCII hyphen on the keypad's token), `×`, `÷`, `^`.

**`expression.dart`**: tokens (committed) + `currentNumber` (string being typed, e.g. `-`, `0.`, `-12.5`). Limits: `maxDigitsPerNumber = 15`, `maxTokens = 60`. Key rules:
- `appendDigit`: no-op at limits; `0`→digit replaces; `-0`→`-d`. `appendDecimal`: one dot; empty → `0.`.
- `appendOperator`: commits number (drops trailing `.`); consecutive operator replaces previous; after `endsOperand` appends; at start or after an opener only **minus** is accepted and becomes `currentNumber = '-'` (negative number). Otherwise returns `this`.
- `appendOpener` (`(`/`sin(`), `appendRightParen` (needs `openParenDepth > 0` and an operand before), `appendConstant`, `appendFactorial` (needs operand, not after `%`), `appendPowerOf('10')` (inserts `×` if after an operand, then `10`, `^`), `appendPercent` (only after a number). All go through `_committedTokens()` which turns a lone `-` currentNumber into a minus token (`-sin(30)`, `-π`) and strips a trailing `.`.
- `toggleSign` (current number or last number token — moves it back into currentNumber), `backspace` (char by char; `-` alone clears; non-number token removed), `replaceTokenAt`, `removeTokenAt`, **`removeTokenCleanly`** (number takes its `%` and one neighbouring operator with it; removing an operator between two numbers joins them: `10 × 11` → `1011`), `insertTokenAfter`.
- `fromTokens` (last number token becomes `currentNumber`), `fromResult`, `clear`, `toDisplayString` (operators spaced ` + `, but `^` and unary minus unspaced).
- `canEvaluate`, `getAllTokens()` (tokens + currentNumber as a number token).

**`parser.dart`** — grammar, lowest→highest: `expr → term (± term)*`; `term → unary (× ÷ or implicit × unary)*`; `unary → '−' unary | power`; `power → postfix ('^' unary)?` (right-assoc; `-2^2 = -4`; `2^3^2 = 512`); `postfix → primary '!'*`; `primary → number '%'? | constant | '(' expr ')' | function expr ')'`. `Parser.parse(tokens, {tolerant = true})`: tolerant trims trailing operators and dangling openers (live preview, `2 × sin(`); **in both modes unclosed `(` are auto-closed** and a stray `)` returns null; leftover tokens (e.g. `5 3`, `5 % 3` after token edits) → null (malformed, never silently dropped). Implicit multiply: next token is an opener or constant (`2π`, `2(3)`, `(1)(2)`, `2sin(30)`), or a number directly after `)`/constant/`!`. Two bare numbers stay malformed.

**`evaluator.dart`**: `Decimal` exact base-10; division via `Rational` → `scaleOnInfinitePrecision: 32`. `AngleUnit {degrees, radians}` (`fromName`). Percent semantics depend on the neighbour: `a + b%` = `a + a·b/100`, `a − b%`, `a × b%` = `a·b/100`, `a ÷ b%` = `a ÷ (b/100)`, `a ^ b%` = `a^(b/100)`; a lone `b%` = `b/100`. Powers: integer exponents exact (`Rational.pow`), fast-fail estimate first (`> 1000` digits → overflow, `< −1000` → 0), `0^neg` → divideByZero, `±1` base shortcut; fractional exponent via `dart:math` and a negative base → domainError. Factorial: non-integer/negative → domainError, `n > 450` → overflow. Functions: `sin cos tan sin⁻¹ cos⁻¹ tan⁻¹ ln log √ ∛` (`log` = log₁₀). **Degree trig reduces exactly mod 360 and special-cases multiples of 90** so `sin 180 = 0`, `tan 90` = domainError; radian results with |v| < 1e-15 snap to 0; `cos|<1e-15|` for tan → domainError. Double results go through `_fromDouble` = `toStringAsPrecision(15)` (NaN → domainError, ∞ → overflow). Constants `pi`, `e` are 33-digit Decimals.

**`formatter.dart`**: `NumberFormatter.format(Decimal)` — 15 significant digits max, **rounds** (not truncates; `1÷3×3 = 1`), commas every 3, trims trailing zeros, `-0` → `0`, integer part > 15 digits → scientific `1.5e20` (mantissa 6 dp, computed from the exact decimal so it never hits `Infinity`). `formatInputNumber(raw)` adds commas while typing (keeps `.`/`-`; empty → `0`).

## Calculator state & controller

`CalculatorState` (`calculator_state.dart`): `expression`, `expressionText` (display string), `resultText` (hero number, default `'0'`), `previewText?`, `error?` (CalcError), `justEvaluated`, `editingTokenIndex?`, `isReplacingEditedToken`, `celebrationId` (++ on every successful `=`; triggers the pop/burst). `isZeroState` = idle `0` (hero drawn dim). `copyWith` uses `clearPreview` / `clearError` / `clearEditingTokenIndex` flags (pass `true` to null a field).

`CalculatorController` (`calculator_controller.dart`, 744 lines, the biggest logic file); `calculatorProvider` wires `onHistoryAdded` → `historyProvider.addEntry`, `angleUnit` → `settingsProvider.angleUnit`, and re-previews when the angle unit changes. Public API used by UI: `onDigit`, `onDecimal`, `onOperator(type, symbol)`, `onPercent`, `onToggleSign`, `onBackspace`, `onClear`, `onEquals`, `selectToken(i)` / `deselectToken()`, `loadResult`, `loadExpression(exprStr, result)`, `refreshPreview`, and the scientific set `onOpener(Token)`, `onRightParen`, `onConstant(sym)`, `onFactorial`, `onSquare` (`^2`), `onExpE` (`e^`), `onExp10` (`10^`).

Behaviours worth knowing:
- After `=` (`justEvaluated`): a **digit/decimal/opener/constant** starts a fresh expression; an **operator, %, +/−, !, x²** continue from the displayed answer (`_baseExpression()` = `Expression.fromResult(resultText)`). `onEquals` is ignored when already evaluated (no duplicate history/celebration). Backspace after `=` clears.
- `onEquals`: first **drops trailing operators** (and a lone `-` currentNumber), so `99 + 66 +` `=` gives 165 and the expression line/history show `99 + 66` without the hanging operator (state `expression` is replaced by the trimmed one); nothing left → no-op. Then strict parse; a dangling opener (`sin(`) is ignored quietly, any other malformed expression shows `invalidExpression`. Success adds to history, sets `justEvaluated`, `celebrationId + 1`. `_showError` picks one of `error.messages` at random (injectable `Random` in the constructor), never the same line twice running, and clears editing/preview.
- Live preview (`_computePreview`): needs ≥ 2 tokens, tolerant parse; stored in `previewText` always, but only *shown* when `settings.showLivePreview`.
- **Token editing** (tap a token in the expression line): `selectToken` sets `editingTokenIndex`, `isReplacingEditedToken = true`, hero shows the token. First digit replaces the token; later digits extend (cap 15 digits). Operator on a highlighted operator/percent replaces it; on a highlighted number swaps the *following* operator or inserts one after. `%` on a number inserts a percent token after it (selection moves to it); on an operator it is ignored. Backspace → `removeTokenCleanly`. `_applyAdvanced` first calls `deselectToken()`.
- `loadExpression` (history tap) re-tokenises the saved display string by hand: numbers `[0-9.,]` (+ `e` only when a digit follows, so `1.5e20` stays one token and `2e` is number+constant), operators `+ − - × * ÷ /`, `%`, `^`, parens, `!`, `π`/`e`, and function names from `_functionNames`. **Add any new function name to `_functionNames`** or history restore breaks.

## Storage & settings

`settingsProvider` / `SettingsNotifier` (`core/storage/settings_store.dart`) — SharedPreferences, `AppSettings` fields and keys:

| field | key | default |
|---|---|---|
| showLivePreview | `settings_show_live_preview` | false |
| hapticsEnabled | `settings_haptics_enabled` | true |
| hapticStrength | `settings_haptic_strength` | 1.0 |
| liteMode | `settings_lite_mode` | false |
| soundEnabled | `settings_sound_enabled` | true |
| soundVolume | `settings_sound_volume_v2` (v2 reset when default dropped to 50 %) | 0.5 |
| soundPack | `settings_sound_pack` (`pop`/`mellow`/`typewriter`) | pop |
| mechSwitch | `settings_mech_switch` (`clicky`/`tactile`/`linear`) | clicky |
| advancedTools ("Scientific & Converter") | `settings_advanced_tools` | false |
| scientificActive (f(x) toggle) | `settings_scientific_active` | true |
| scientificExpanded (tray 2nd row) | `settings_scientific_expanded` | true |
| angleUnit | `settings_angle_unit` | degrees |
| secretUnlocked (secret skin found) | `settings_secret_unlocked` | false |
| huntStep (newsroom hunt notes solved, 0–5) | `settings_hunt_step` | 0 |

Other keys: theme `settings_theme_mode` (**int index of `AppThemeMode`** — only ever append enum values), converter `converter_category` / `converter_from` / `converter_to`, purchases `purchases_owned` (Play build) and `settings_owned_products` (fake store). Setters mirror state into `AppHaptics.enabled/strength` and `AppSounds.configure`. Sliders: `setHapticStrength`/`setSoundVolume` apply live while dragging; call `saveHapticStrength`/`saveSoundVolume` on drag end. `setAdvancedTools(true)` also turns `scientificActive` on. `advanceHunt(from)` solves a hunt note (see Secret skin); `unlockSecret()` sets `secretUnlocked`; `secretFoundProvider` (a `StateProvider<int>` in the same file) counts up at the moment of finding, which is what the calculator screen listens to for its announcement (the saved flag also turns true at every launch, so it cannot be used for that).

`historyProvider` / `HistoryNotifier` (`history_store.dart`): newest-first `List<HistoryEntry{id, expression, result, timestamp}>`, **cap 50**, append-only JSONL `calc_history.jsonl` in the app documents dir (compacted via `_saveAll` when the file has > 100 lines; `removeEntry` rewrites). `savePendingPreview` stores the in-progress expression + preview (skips if equal to newest; the screen strips trailing operators first, so `1 + 2 +` is saved as `1 + 2`) — called by `CalculatorScreen.didChangeAppLifecycleState` on paused/detached/hidden when live preview is on and the answer isn't already evaluated.

## Theme, skins, materials

- `core/theme/theme_tokens.dart`: `enum AppThemeMode {ink, sunny, blueprint, obsidian, synthwave, matcha, frost, velvet, clay, chrome, glass, wood, candy, neon, mechanical, newsprint}` (**index persisted — append only**; index 2 was Bubblegum, then Peony, now `blueprint`, so anyone with those saved lands on Blueprint). `ThemeColors` (`bg, bgShade, ink, inkSoft, accent, extrudeTop, extrudeSide, extrudeShadow, extrudeChamfer, burst, isDark, finish`) with one `const` per skin and `ThemeColors.of(mode)`. `SkinFinish {standard, matte, mirror, glass, grain, gloss, glow, keycap, wireframe, halftone}`. Materials use the first group; `wireframe` is Blueprint (face = background so the block is hollow, the white chamfer is the drawn line, and a `GridPaper` drafting grid is laid in `calculator_screen.dart` and in `SkinPhone`); `halftone` is Newsprint (an `ImageShader` of `_halftoneTile`, one dot drawn once with `toImageSync`, in `extruded_number.dart`).
- `core/theme/app_theme.dart`: `themeProvider` (`ThemeNotifier`, default `sunny`; loads/saves index; `ThemeNotifier.preview(mode)` is fixed, never persists — used by hold-to-preview and by tests that need a fixed skin), `AppTheme.getThemeData` (font BebasNeue, ColorScheme from tokens), `AppTheme.colorsOf`.
- `core/theme/skin_catalog.dart`: `kPremiumLocked` (**master switch**: `false` ⇒ everything free), `kAllThemesProductId = 'themes_all'`, `SkinInfo` (mode, label, tagline, description, modelCode, productId?, feels), `MaterialFeel` (id, label, description, soundFolder, haptics), lists `kSkins` (8, order shown in settings grid), `kMaterials` (7), `kBundleItems` (premium skins and materials interleaved), `kProductIds`, `skinOf(mode)`, plus `kSecretSkins` (`SkinInfo.secret`), `kHuntNotes`, `kHuntAgainHint`, `kHuntErrorLine`, `kHuntErrorNote`, `kHuntEditionTitle`/`Line`, `kHuntHeadline`/`Note`.
  - Product ids: `theme_obsidian|synthwave|matcha|frost|velvet`, `material_clay|chrome|glass|wood|candy|neon|mechanical`, `themes_all`.
- `core/theme/material_feel.dart`: `materialFeelProvider` (active skin's feel, using `settings.mechSwitch` for Mechanical, null for ordinary skins) and `applyMaterialFeel(feel)` → `AppSounds.setMaterial(folder)` + `AppHaptics.feel`.

**Materials** (Clay, Chrome, Glass, Wood, Candy, Neon, Mechanical) are exclusive look + sound + haptics sets, never mixed with other skins or sound packs; the 8 ordinary skins and 3 packs are untouched by them.
- *Look*: `ThemeColors.finish`. `extruded_number.dart` lays `_finishShader` gradient over the face (matte soft light, mirror sky/horizon, glass top-edge, grain repeated bands, gloss highlight, glow white-hot core) and a blurred halo for glow; `keycap` draws no numeral finish but makes `KeyButton` render keycaps via `KeycapScope.wrap` around the keypad (Mechanical).
- *Sound*: folders `clay chrome glass wood candy neon mech_clicky mech_tactile mech_linear` under `assets/sounds/`, built by `MATERIAL_PACKS` (seed `100 + index`, so adding one never changes existing WAVs). Not `SoundPack` values; never in the pack picker.
- *Haptics*: `HapticFeel` enum + `_feels` map in `app_haptics.dart` swaps digit/operator/utility/backspace patterns (same native primitives, no Kotlin change).
- Settings sound section: pack chips replaced by a note, or by switch chips for Mechanical.

**Secret skin (Newsprint) and the newsroom hunt**: `AppThemeMode.newsprint`, ink on paper with halftone dots and a red stamp accent. It is the one entry in `kSecretSkins`, has no `productId` (so `ownsSkin` is always true for it), and is not in `kSkins`, `kBundleItems` or the store. It is earned through a 5-step **newsroom hunt** (since 1.4.1; the old "any calculation = 1,337" unlock is gone). Each step is a note from "the editor" (`kHuntNotes` in `skin_catalog.dart`, all wording there) pointing at a feature: **0** divide by zero (the error shows `kHuntErrorLine` "NOW THAT'S A STORY" with `kHuntErrorNote` under it instead of a joke: `CalculatorController.onDivideByZero` callback → `CalculatorState.errorNote`; `errorNote` is **never carried over by `copyWith`**, it lasts only until the next state change; the screen shows the small line whenever `error != null || errorNote != null`), **1** pick the Typewriter sound pack (hook in `setSoundPack`), **2** turn Live Preview on (hook in `setShowLivePreview`), **3** open the converter and come back (the top-bar ruler, only there with Scientific & Converter on; counted in `onConverterTap`'s `whenComplete` in `calculator_screen.dart`, so the pill shows on the calculator), **4** tap "TODAY'S EDITION", a planted row at the top of History (`_EditionEntry` in `history_sheet.dart`, key `hunt-edition`, shown only at step 4 and even with empty history; it pops the sheet then `advanceHunt(4)`). Progress: `huntStep` (0–5, `settings_hunt_step`, `kHuntLength = 5`), `SettingsNotifier.advanceHunt(from)` only advances when `huntStep == from` (order enforced; already-on settings must be flipped again, the note says so via `kHuntAgainHint`), fires `AppHaptics.success` and bumps `huntSolvedProvider` → pill "STORY n OF 5 FILED". `huntDone` = `secretUnlocked || huntStep >= kHuntLength`; old 1,337 finders are done. **Finale**: when `huntStep == 5`, not yet unlocked, and `CalculatorScreen` is the current route (History has just closed itself, or next launch), it lays `InkSpill` (`widgets/ink_spill.dart`, 2.2 s: blobs flood from the hero centre, black at 0.5 where `onCovered` → `_finishHunt` = `unlockSecret()` + `setTheme(newsprint)` + `secretFoundProvider++` → "SECRET SKIN FOUND · NEWSPRINT" pill, and `CalculatorController.showHeadline(kHuntHeadline, kHuntHeadlineNote)` resets the calculator to "EXTRA! EXTRA!" with "Newsprint is yours. Welcome to the paper." under it (so the ÷0 line and its note are gone), then a halftone dot grid shrinks from the origin out; lite mode = plain fade). Settings grid: the secret slot is **second, between Marigold and Charcoal**: `_MysteryTile` ("?" + `HuntPips`, key `mystery-tile`) opens `HuntNoteSheet` (`features/settings/presentation/hunt_note_sheet.dart`, a `StoreSheet`: "FROM THE EDITOR", current note in monospace on top, solved ones struck through with a red FILED stamp); after unlock the skin itself sits there. Tests: `test/secret_skin_test.dart`.

**Shelved looks** (tried as secret-skin candidates on 2026-10-12, liked by the owner, removed from the app; could return as paid skins). Blackout: bg `#050505`/`#0E0E0E`, ink `#5A5A5A`, inkSoft `#333333`, accent `#8A8A8A`, top `#0A0A0A`, side `#1C1C1C`, shadow `#CC000000`, chamfer `#59FFFFFF`, standard finish. Pixel: bg `#9BBC0F`/`#A8C81A`, ink and accent `#0F380F`, inkSoft and side `#306230`, no shadow or chamfer, wall drawn in 4 hard steps instead of 36-64. Chalkboard: bg `#1F3B2D`/`#28493A`, ink and top `#F2EFE6`, inkSoft `#9DB3A6`, accent `#F4D35E`, side `#5E7A6B`, slanted repeating dark strokes over the face. Prism (rainbow foil) was rejected outright: no rainbow skins.

**Add a skin** = `AppThemeMode` value (append!) + `ThemeColors` const + `ThemeColors.of` case + `SkinInfo` in `kSkins` (with `productId` if premium) + create/activate the product in Play Console. No artwork: the store draws every skin live (`SkinSwatch`).
**Add a material** = also a `finish`, a `kMaterials` entry with `MaterialFeel`s, a pack in `MATERIAL_PACKS` + folder under `flutter.assets` in `pubspec.yaml`, a `HapticFeel` + `_feels` entry; update tests that count them (`test/materials_test.dart`).

## Purchases (`core/storage/entitlement_store.dart`, `play_purchase_service.dart`)

- `PurchaseService extends StateNotifier<PurchaseState>`: `buy(productId) → BuyOutcome {purchased, pending, cancelled, unavailable, failed}`, `refresh()` (prices + what the account holds; also what Restore calls; returns false if Play unreachable). `PurchaseState`: `owned`, `pending`, `prices` (Play's own text — never hardcoded), `amounts` (numbers), `loaded`, `checking`; `canBuy(id)` = has a price and not pending; `bundleSaving` = whole % off buying everything singly, **null unless every product has a price and saving ≥ 5 %**.
- `purchasesProvider`: **`kReleaseMode ? PlayPurchaseService() : FakePurchaseService()`** — debug/profile (app id `.dev`, which Play can't sell to) and tests get the fake: free, instant, placeholder prices (`$0.99` skins, `$1.99` materials, `$2.99` Mechanical, `$6.99` bundle), persisted in `settings_owned_products`.
- `PlayPurchaseService` talks to Play through `BillingGateway` (tests inject a scripted fake in `test/core/play_purchase_service_test.dart`). Start: listen to the purchase stream first, load saved `purchases_owned` (so skins work offline), then `refresh()` → `_matchPlayAccount` **replaces** saved owned with what Play holds (refunds taken back, purchases from another phone appear; if Play can't say, the saved set stands). Paid purchases are acknowledged (Play refunds unacknowledged after 3 days); pending ones are neither owned nor acknowledged until paid. Patience 12 s per call. An error flow re-checks the account (Play reports an error for "already owned").
- `entitlementProvider` = owned ids; `ownsSkin(owned, skin, {locked = kPremiumLocked})` = free ∨ unlocked ∨ has bundle ∨ has product.
- Manifest has `com.android.vending.BILLING` + `VIBRATE`.

## Skin store UI (`features/themes/presentation/`)

- `theme_store_screen.dart` — `ThemeStoreScreen.open` (fade+slide route; opened from the settings banner). Rechecks prices on init. Back + "SKIN STORE"; `_BundleCard` (key `bundle-card`, 176 px hero: saving chip, "EVERYTHING", counts, "SEE THE BUNDLE", and three `SkinPhone`s fanned on the right from `_phones`; a `Row` of words (flex 11, one `FittedBox` so they shrink together on narrow phones instead of overflowing) and phones (flex 10, `BoxFit.cover`); **no price**; opens `BundleDetailSheet` in the current skin's colours); then two-column grids of `SkinCard`s: **MATERIALS** and **SKINS** hold only what is still for sale, **YOURS** holds what is owned (an empty section is not drawn); "RESTORE PURCHASES" with its result note.
- `theme_card.dart` — **`SkinPhone`** (the store's mockup, drawn live, no images: a 228 × 470 phone showing the top-bar icons, `32 × 4 =`, a real `ExtrudedNumber` "128" and the five keypad rows in the skin's colours; keycaps for Mechanical, the drafting grid for Blueprint; `IgnorePointer`, scale it with a `FittedBox`). **`SkinSwatch`** (the shop window: a `SkinPhone` leaning −0.07 rad on a backdrop of `lerp(bg, extrudeSide, 0.5)`, running off the bottom edge; `aspectRatio` decides how much keypad shows; laid out at 300 px wide inside a `FittedBox`, so it works from a 46 px chip to a full card). `SkinCard` (swatch at `swatchAspect` 0.82 + label + model code + `_StandingPill`, `captionHeight` 58), `SkinStanding {active, owned, forSale, notForSale}`.
- `theme_detail_sheet.dart` — `SkinDetailSheet.show(ctx, skin, {fromBundle})`: drawn in that skin's colours; swatch, tagline, description; materials get "tap to hear and feel it" demo buttons (`AppSounds.previewMaterial` + `AppHaptics.demo`, each tap = next digit); footer: **hold to preview** (`ThemePreview` on pointer down/up), then ACTIVE / APPLY / UNLOCK+price, purchase note, and "Or everything for $X [n% OFF]" unless opened from the bundle sheet.
- `theme_bundle_sheet.dart` — `BundleDetailSheet`: every swatch in a 4-col grid (each opens its skin sheet with `fromBundle: true`), `_ValueCard` (contents summed singly, struck through, vs bundle, "You save …"), GET EVERYTHING / OWNED.
- `theme_preview_overlay.dart` — `ThemePreview`: inserts an `OverlayEntry` on the root overlay with the real `CalculatorScreen` inside a nested `ProviderScope` overriding `themeProvider` with `ThemeNotifier.preview(skin.mode)`; saved skin untouched; fades out then removes itself.
- `store_widgets.dart` — `SavingChip` ("64% OFF"), `Pressable` (0.97 scale), `StoreButton` (54 px pill, text shrinks to fit prices), `StoreSheet` (rounded frame; body scrolls, footer buttons stay in view; max 90 % height).
- `purchase_feedback.dart` — `priceTag`, `purchaseNote`, `purchaseHaptic`, `recheckPrices(ref, ids)` (microtask refresh when any price is missing), `moneyLike` (writes a computed total in Play's own currency format), `BundleValue.of`, `PurchaseNote`.
- Settings grid shows **only what can be put on** (locked skins and materials are in the store only, so the grid stays short): Marigold → the secret slot ("?" or the found skin) → Charcoal, Blueprint → owned premium skins → owned materials. Locked materials never show there. A locked tile opens its `SkinDetailSheet`. The `_StoreBanner` fans three `SkinSwatch` chips.

## Calculator screen & widgets (`features/calculator/presentation/`)

**`calculator_screen.dart`** (`CalculatorScreen`, `ConsumerStatefulWidget` + `WidgetsBindingObserver`): `scientific = advancedTools && scientificActive`; `landscape = scientific && width > height*1.2 && height < 560` (tall wide windows like tablets keep the centred frame). Portrait column (max width 440, SafeArea): `TopBar` → `ExpressionLine` → hero (`TweenAnimationBuilder` flex ×10: **44** simple / **24** scientific expanded / **34** scientific folded, 260 ms) → `ScientificTray` (in an `AnimatedSwitcher`/SizeTransition, padding 18/0/18/6) → `Keypad` (flex 520, padding 24/0/24/20). Landscape row: display 34 % (top bar compact, expression, hero) | `ScientificTray(grid: true)` 31 % | keypad 35 %. Background: radial gradient `bgShade→bg` + `GrainOverlay`. Hero stack: `CelebrationBurst`, `AnimatedExtrudedNumber` (tap toggles whole-result highlight, long-press copies result without commas → clipboard + snackbar), DEG/RAD `_AngleBadge` (portrait scientific only; toggles `AngleUnit` with `AppHaptics.shift`). `_resultHighlighted` makes the next digit/decimal replace the result (`Keypad.highlightMode`, consumed via `onHighlightConsumed`). Converter button: `AppHaptics.mode(true)`, `_allowLandscape(false)`, push converter, rebuild on return.

<a name="orientation"></a>**Orientation**: `main()` and `SplashScreen._goHome` lock portrait; `CalculatorScreen._allowLandscape(scientific)` adds landscapeLeft/Right only while scientific is on (cached in `_landscapeAllowed`); `ConverterScreen` forces portrait on init and restores (incl. landscape if it was scientific) on dispose.

**`top_bar.dart`** (height 44): left = History (`access_time_rounded`) + (if `advancedTools`) `_ScientificToggle` f(x) (accent-lit while scientific; `AppHaptics.mode`); right = (if `advancedTools`) converter ruler `straighten_rounded` + Settings `tune_rounded` (`SettingsSheet.show`). `compact` shrinks side padding for landscape.

**`keypad.dart`**: 5 rows × 4 — `C % ⌫ ÷` / `7 8 9 ×` / `4 5 6 −` / `1 2 3 +` / `0 . +/- =`. Each `KeyButton` has a `haptic` and `sound` fired on touch-down. Operators → `AppHaptics.operatorKey`/`AppSounds.operatorKey`; C → `clear`; % and +/- and `.` → utility; `=` → `selectionClick`, no key sound (the answer plays `success`). Font sizes 32–48. Wrapped in `KeycapScope.wrap`.

**`key_button.dart`**: press scale 1→0.88 (70 ms / 120 ms), pressed fill = colour @16 %; `onTapDown` fires haptic + panned sound (pan = `(x/width − 0.5) × 0.6`), `onTapUp` fires `onTap`. `KeycapScope` InheritedWidget switches to the keycap look (dark skirt, lighter top face that sinks).

**`scientific_tray.dart`**: `ScientificTray({colors, grid})`. Portrait: handle (tap or swipe ±150 velocity folds/unfolds row 2, persisted in `scientificExpanded`), row 1 (swap `⇄`, xʸ, √, `(`, `)`, π) and row 2 (sin cos tan ln log !), key height `rowHeight = 46`. The **⇄ "second" key flips every key to its inverse**: row 1 → x², ∛, `(`, `)`, e; row 2 → sin⁻¹ cos⁻¹ tan⁻¹ eˣ 10ˣ !; a used 2nd-layer key drops back (`once`). `grid: true` (landscape) lays out all 5×4 keys at once (`( ) π e` / `x² xʸ √ ∛` / `sin cos tan DEG|RAD` / `sin⁻¹ cos⁻¹ tan⁻¹ !` / `ln log eˣ 10ˣ`), no swap key. `_Feel` enum pairs each key kind with an `AppHaptics` pattern and `Sfx`. Function keys call `controller.onOpener(Token(function, 'name('))`. `_TrayKey` draws superscripts/root index manually (fonts lack glyphs); `e` uses Antonio.

**`expression_line.dart`**: 56 px tall, 40 pt Bebas, horizontal scroll `reverse: true` (newest in view). Each token is a `_TokenChip` (fixed padding + 2 px border so selection never shifts layout; only colours animate, 130 ms). Operators and `%` accent-coloured. Trailing `=` chip after evaluate; or `= preview` when live preview is on.

**`extruded_number.dart`** (`ExtrudedNumber`, stateful, + `_ExtrudedNumberPainter`): font = min(height × 0.88, 200) ≥ 64, shrunk to fit width − 40 (≥ 40) by `_fitFontSize` (cached); a refit within 0.7×–1.4× **eases over 140 ms** through a `TweenAnimationBuilder` (bigger jumps and lite mode snap). Layers, split into `_paintUnder` (neon halo, blurred contact shadow) and `_paintBody` (**36–64 stamped copies** from `extrudeSide` to a rim colour along the extrusion vector = base lower-right `(0.55, 0.82) × 18 × depth` + tilt × 0.55, then front face, finish shader, chamfer stroke). **Typing**: `stableLength` + `enterProgress` split the text into a settled run and an arriving run; the arriving digits are painted through a horizontal `canvas.scale` about their own centre (0.35 → 1, easeOutCubic) with their extrusion growing from 30 %, all "under" layers before all "body" layers so no shadow crosses a neighbour's face. **Lite mode paints one flat face** (+ finish) and never animates. `_painterCache` (max 16) keyed by text/font size/colours. `isZero` ⇒ opacity 0.28, depth 0.35. Small fixed-size uses (`SkinPhone`) wrap it in a `FittedBox`, because of the 64 px minimum.

**`numeral_animator.dart`** (`AnimatedExtrudedNumber`): 7 controllers — depth spring (240 ms easeOutBack), scale, error shake (320 ms, ±12 px), idle breathing (4 s, 0.97–1.0), drag spring-back (600 ms elasticOut), typing (160 ms, drives `enterProgress`), celebration (720 ms pop + wobble). `didUpdateWidget` order: error → shake + `AppHaptics.error` + `AppSounds.error`; `celebrationId` increase → pop + `AppHaptics.success` + `AppSounds.success`; text change → typing: **the block never moves**; if the text grew, `_stableLength` = the old length when the new text starts with the old one, otherwise length − 1 (formatting reshuffled it, e.g. `999` → `1,000`), and the new digit turns in; backspace only dips the depth (from 0.8). (The old rise-from-below, squash and drop were removed in 1.4.0: users found them hard on the eyes.) Touch drag (< 7 px = tap → `onTap`) + **accelerometer** (`sensors_plus`, EMA 0.86/0.14, `setState` each event) drive 3D tilt (perspective `0.001`, ±0.28 rad) and the extrusion light. Lite mode skips the perspective transform. The converter reuses this widget.

**`celebration_burst.dart`**: 22 random speed-line rays, 750 ms, fires when `trigger` increases. **`grain_overlay.dart`**: `assets/textures/noise.png` repeated at 4.5 % opacity. **`backspace_icon.dart`**: custom-painted hexagon-with-x.

## Unit converter

- `core/units/units.dart` (pure Dart): `Unit(id, name, symbol, factor: Rational, offset)`; base value = `x·factor + offset`, result = `(base − to.offset)/to.factor` → `Decimal` (32 dp). `Units.convert`, `Units.categories`, `Units.byId`. **10 categories**: length (default km→mi), mass "Weight" (kg→lb), temperature "Temp" (c→f; Celsius factor 1 offset 273.15, Fahrenheit factor 5/9 offset 459.67·5/9, base = kelvin), volume (l→gal; US + UK gallon), area (m²→ft²), speed (km/h→mph), time (h→min; year = 365.25 d), data (GB→MB; KB/MB/GB decimal, KiB/MiB/GiB binary, bit = 1/8 B), pressure (bar→psi), energy (kcal→kJ). Add a unit/category here; `test/units/units_test.dart` checks unique ids and defaults.
- `features/converter/application/converter_controller.dart`: `converterProvider` (`ConverterController`, persists category/from/to; the typed number is not persisted). `ConverterState` → `inputText`, `outputText`, `referenceText` (`1 km = 0.621371192237334 mi`). `selectCategory` keeps the input; `setFrom/setTo` swap sides if the other unit is picked; `swap` carries the converted value as the new input (not when it contains `e`); `onDigit/onDecimal/onBackspace/onToggleSign/onClear` reuse `Expression`'s `currentNumber` rules (15-digit cap); `loadValue` (ANS) refuses `e` notation.
- `features/converter/presentation/converter_screen.dart`: `ConverterScreen.open` (fade+slide). `_Header` ("CONVERT"), `_CategoryTabs` (scrollable text tabs + dot, fading edges, detent haptic+sound every 64 px of user swipe, end bump), `_Readout` (flex 48: from `_UnitDial`, hero `AnimatedExtrudedNumber`, `_SwapDivider`, to `_UnitDial`, 64 pt accent output, reference line), `_UnitDial` (tap opens `_UnitSheet` list; vertical swipe steps units every 34 px with detents, skips the other side's unit, a11y increase/decrease), `_ConverterKeypad` (flex 44: digits, ⌫, C, +/-, **ANS** = calculator's answer, `.`, copy). Back/leave plays `AppHaptics.mode(false)`.

## Audio (`core/audio/app_sounds.dart`)

Static `AppSounds` on `flutter_soloud` 4.x: all sounds decoded up front, `play` is synchronous (low latency, overlapping presses OK), buffer 1024 frames, 32 voices, media stream, no audio-focus (music keeps playing). Silent no-op until `init` succeeds (tests never touch the engine). `Sfx` enum: `digit0..9, operator, utility, backspace, clear, success, error` + scientific `trig, log, power, root, bracketOpen, bracketClose, constant, factorial, shiftOn, shiftOff` (file name = snake_case; `digit_N`). `_folder = _material ?? _pack.name`; selectable packs stay loaded, material folders lazy-load (`setMaterial`), `previewMaterial(folder, sfx)` for the store demo, `previewPack`. Pitch: digits/melodic/success exact; others ±4 % drift; backspace winds down 3 %/press within 600 ms (floor 0.8). `_gain = volume × 0.4` (files are mastered loud). Shared outside the packs: `launch.wav` (copy of typewriter `clear`, `AppSounds.launch()`), `detent.wav` (`AppSounds.detent(up:)`, converter notches, 40 ms throttle). `playWhenReady` queues a sound requested before load (TTL 1.2 s). `panned(pan, fn)` positions the sound in stereo.

**Where sound plays**: keypad keys, scientific tray keys, converter keypad, answer (`success`) / error, launch, converter detents. Toggles, settings, DEG/RAD and converter taps are **haptics only**. Volume slider preview = `digit7`; sound toggle preview = `success`.

**Generation**: `tool/generate_sounds.py` (pure-Python synthesis, deterministic seeds: `Random(42)` for the 3 packs, `100+k` per material, `9` detent). Re-run rather than hand-editing WAVs. Output must keep identical file names per folder; `test/core/sound_files_test.dart` and `test/materials_test.dart` assert completeness. New folders must be listed under `flutter.assets` in `pubspec.yaml`.

## Haptics (`core/haptics/app_haptics.dart` + `MainActivity.kt`)

Static `AppHaptics` (`enabled`, `strength`, `feel`). Each call builds `List<_Hit(primitive, scale, delayMs)>` and sends `MethodChannel('popcalc/haptics').invokeMethod('play', {hits:[{p,s,d}], strength})`; Dart falls back to Flutter `HapticFeedback` if the native call returns false/throws (and then stops trying). Kotlin: Android 11+ composed primitives (`click tick lowTick thud quickRise slowRise quickFall spin`; unsupported primitives are swapped for the nearest cousin), else a waveform of amplitude-scaled pulses (min amplitude 60), else a plain vibrate; `boost(x) = x^0.8 × 1.1` lifts weak motors. **Adding a primitive means editing both Dart and `MainActivity.kt`.** Vocabulary: `selectionClick`, `lightImpact`, `mediumImpact`, `heavyImpact`, `digit`, `operatorKey`, `utility`, `backspace`, `clear`, scientific (`trig log power root bracketOpen bracketClose constant factorial`), `shift(on)`, `mode(on)`, converter (`swap category unitPick detent detentEnd`), `success`, `error`, `demo(feel)`. The four everyday keys are overridden by the active `HapticFeel`.

## Other screens

- **`history_sheet.dart`**: modal bottom sheet 65 % height; list of entries (expression small, `= result` big); tap → `loadExpression` + pop; swipe left to delete; "CLEAR ALL"; empty text "No calculations yet".
- **`settings_sheet.dart`** (72 % height, scrolls): title "SKINS" → 4-column hex tile grid (`_SkinTile`, lock on unowned; usable skins first, see Skin store UI; `_MysteryTile` in the second slot until the secret skin is found) → `_StoreBanner` (fanned mockups, "SKIN STORE", saving chip or "Everything unlocked" / "N skins and M materials") → rows: Scientific & Converter, Live Preview on Top, Haptic Feedback + strength slider, Lite Effects Mode → SOUND section (Sound Effects switch + volume slider, pack chips or Mechanical switch chips, descriptive note) → `_SignatureFooter` (signature PNG chosen by `isDark`, version line, "OFFLINE · NO ADS · NO TRACKING"; **tapping the signature 5× within 1.5 s each opens ornobaadi.vercel.app** — hidden).
- Switch styling: `activeThumbColor: colors.accent`, track accent @35 %.

## Tests (`test/`, 231 tests, all green on 2026-10-15)

| file | covers |
|---|---|
| `engine/engine_test.dart` | basic ops, decimal exactness, precedence, percent semantics, expression editing, divide-by-zero |
| `engine/scientific_test.dart` | precedence of ^/!/unary, implicit multiply, parens, exact results, trig deg/rad, roots/logs, errors, expression editing rules |
| `engine/calculator_controller_test.dart` | typing, preview, continue-after-=, errors, token editing (many cases), huge results, history restore |
| `engine/scientific_controller_test.dart` | sin auto-close, angle switch, implicit multiply, x²/!/10ˣ/eˣ, domain errors, history round-trip |
| `units/units_test.dart` | exact conversions, temperature, categories, `ConverterController` |
| `core/entitlement_test.dart` | catalog completeness, `ownsSkin`, persistence |
| `core/play_purchase_service_test.dart` | scripted `BillingGateway`: buy/pending/cancel/error/refund/other-phone, bundle saving, `moneyLike` formatting |
| `core/sound_files_test.dart` | every `Sfx` has a file in every pack, shared sounds, snake_case |
| `materials_test.dart` | sound sets per feel, finishes/prices/haptics, bundle contents, applying feel, settings chips |
| `theme_store_widget_test.dart` | buy→apply, hold to preview, bundle card and sheet, owned items under YOURS, Play states, fallback to Marigold |
| `secret_skin_test.dart` | newsroom hunt: each note, order gating, special ÷0 line, persistence, old finders, 1,337 does nothing; ink-spill finale on `CalculatorScreen` ending in the EXTRA! headline; today's edition in History; settings grid order, ??? tile opens the note |
| `advanced_mode_widget_test.dart` | top-bar buttons, f(x) toggle, tray fold, converter open/swipe, **landscape grid** |
| `live_preview_history_test.dart` | pending preview saved to history on pause |
| `widget_test.dart` | calculator smoke test |

Tests run under the **Ahem** font (every glyph a square), so text is far wider than on a phone: an overflow in a widget test is a hint, not proof. Mock the sensors channels (`dev.fluttercommunity.plus/sensors/*`) when pumping screens: `for (final c in ['method','accelerometer','gyroscope','user_accel']) messenger.setMockMethodCallHandler(MethodChannel('dev.fluttercommunity.plus/sensors/$c'), (_) async => null);`. For a fixed skin override `themeProvider` with `ThemeNotifier.preview(mode)`; for a fixed store override `purchasesProvider` with a small `PurchaseService` subclass (see `FixedStore` in `theme_store_widget_test.dart`).

**Screenshot recipe (no device)**: write a temporary `test/zz_shot_test.dart` that loads the real fonts with `FontLoader` (BebasNeue, Antonio, Inter from `assets/fonts/`, MaterialIcons from `C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf`), precaches asset images inside `tester.runAsync`, sets `debugDisableShadows = false` (restore `true` before the test ends), and `expectLater(find…, matchesGoldenFile('zz_shots/<name>.png'))` with `flutter test --update-goldens`. Golden paths must be relative (absolute `C:/` silently writes nothing). Copy PNGs to the scratchpad, show with SendUserFile, then delete the test and `test/zz_shots`. Git Bash heredocs with mixed quotes fail here ("unexpected EOF"): write patch scripts with the Write tool instead.

## Tools

- `tool/generate_sounds.py` — see Audio. Voices: bloop, marimba, noise_burst, resonant_click, bell, sweep, whoosh, partials, chirp; `pack_pop/mellow/typewriter`, `material_pack(...)` builders, `scientific_sounds(tone)` per pack, `mech_key` for switches; `normalize` = tanh drive, `fade_edges` 3 ms.
- (The skin mockup generator and `assets/skins/` were removed in 1.4.0; the store draws skins live.)

## Where to change X (quick lookup)

| I want to… | Go to |
|---|---|
| Change an operator/percent/typing rule | `core/engine/expression.dart` (+ `test/engine/`) |
| Change precedence or add grammar | `core/engine/parser.dart` |
| Add a math function | token text in `scientific_tray.dart` (`fn('name')`) + `evaluator.dart` `_function` + `calculator_controller.dart` `_functionNames` + tests |
| Change rounding / number display | `core/engine/formatter.dart` |
| Change `=` / editing / preview behaviour | `calculator_controller.dart` |
| Add a setting | `AppSettings` + key + load + setter in `settings_store.dart`, row in `settings_sheet.dart` |
| Change the keypad layout/labels | `widgets/keypad.dart` |
| Change top-bar buttons | `widgets/top_bar.dart` |
| Change result/keypad proportions or landscape layout | `calculator_screen.dart` |
| Change 3D numeral look/animation | `extruded_number.dart`, `numeral_animator.dart` |
| Change a skin's colours | `core/theme/theme_tokens.dart` (the store follows by itself) |
| Change or add an error line | `messages` in `core/engine/calc_error.dart` |
| Change the hunt's clues or the secret skin | `kHuntNotes` / `kHuntErrorLine` / `kSecretSkins` in `core/theme/skin_catalog.dart`; step hooks see Secret skin section |
| Change typing motion | `numeral_animator.dart` (`didUpdateWidget`) and the arriving-run code in `extruded_number.dart` |
| Change what a skin/material is called or costs info | `core/theme/skin_catalog.dart` (price itself is in Play Console) |
| Make everything free / locked | `kPremiumLocked` in `skin_catalog.dart` |
| Change store layout | `features/themes/presentation/` (see its section) |
| Change a purchase rule | `play_purchase_service.dart` / `entitlement_store.dart` |
| Change a key sound | `tool/generate_sounds.py` then run it |
| Change haptic feel | `core/haptics/app_haptics.dart` (and Kotlin if a new primitive) |
| Add a unit | `core/units/units.dart` |
| Bump the version | `pubspec.yaml`, `_appVersion` in settings sheet, `README.md`, new entry in `RELEASE_NOTES.md` |
| Native splash | `flutter_native_splash.yaml` then `dart run flutter_native_splash:create` |

## Gotchas & conventions

- **Edge-to-edge** (Android 15+ forces it for target SDK 35+; Flutter 3.47 targets 36 and draws edge-to-edge on older Android too; `main.dart` makes both system bars transparent). No native code is needed (`MainActivity` is a plain `FlutterActivity`); insets are handled in Dart: full screens and `StoreSheet`/`_UnitSheet` use `SafeArea`, and the settings and history sheets add `MediaQuery.viewPaddingOf(context).bottom` to their scroll padding. **Any new screen or bottom sheet must do one of the two**, or its last row sits under the navigation bar. Play Console shows a generic "Edge-to-edge may not display for all users" notice for every app targeting 35+; it is advice, not a blocker.

- State classes use `copyWith` with explicit `clearX` booleans for nullable fields; follow that pattern.
- `AppSounds` / `AppHaptics` are static singletons, deliberately fire-and-forget; wrap UI taps with them rather than awaiting.
- Comments in this codebase explain *why*; keep that voice, don't narrate what.
- Premium gating always goes through `ownsSkin`; never compare product ids directly in UI.
- Money is shown only as Play wrote it (`prices`), never hardcoded or formatted by the app; use `moneyLike` for totals.
- `ThemeNotifier.toggleTheme` (ink↔sunny) exists but the UI picks skins through `setTheme`.
- The minus *token* text is an ASCII `-` while the keypad key shows `−`; `loadExpression` accepts both.
- Heavy paint: the extruded numeral stamps up to 64 TextPainters per frame; keep new per-frame work out of it and respect `isLite`.
- The accelerometer subscription lives in every `AnimatedExtrudedNumber` (calculator hero and converter input).
- `architecture.md` mentions a theme picker, golden tests and `app/` folder that were not built as written.

## Planned, not built

**Alternate app icons (Phase B of the 1.4.0 plan)**: waiting for the owner's logo files (one 1024 px PNG per icon, ideally separate foreground and background, in `assets/brand_assets/icons/<name>/`). Design: one `<activity-alias>` per icon in `AndroidManifest.xml` (each with its own icon and the MAIN/LAUNCHER filter; `MainActivity` loses its launcher filter), a `popcalc/app_icon` channel in `MainActivity.kt` that enables the chosen alias with `PackageManager.setComponentEnabledSetting(..., DONT_KILL_APP)`, `settings_app_icon`, an "APP ICON" row in settings, and the Flutter `SplashScreen` showing the chosen mark. The native splash cannot differ per alias, so its fixed logo would be dropped. Limits: launchers update slowly, some drop the home-screen shortcut or close the app, and it needs a real phone to verify.

## Change log

Newest first. Add a line for every change (date, what, files).

- **2026-10-15 — 1.4.1+13**: release with the newsroom hunt (entries below). `pubspec.yaml`, `_appVersion`, README, new `RELEASE_NOTES.md` entry (the 1.4.0 entry is back to what shipped). 1.4.0+12 is live in production.

- **2026-10-15** — Hunt reworked to 5 steps after owner feedback: the converter step counts on return, a new last step taps "TODAY'S EDITION" in History (closing History starts the ink spill, no converter round-trip). Fix: after unlocking, the old ÷0 line and "editor left you a note" stayed on screen; the finale now resets the calculator to an "EXTRA! EXTRA!" headline (`showHeadline`), and `errorNote` no longer survives `copyWith`. Files: `skin_catalog.dart`, `settings_store.dart`, `calculator_state.dart`, `calculator_controller.dart`, `calculator_screen.dart`, `history_sheet.dart`, `secret_skin_test.dart` (231 tests).

- **2026-10-15** — **Newsroom hunt replaces the 1,337 unlock** for Newsprint: 4 editor's notes (÷0 → Typewriter pack → Live Preview → open the converter), `huntStep`/`advanceHunt`/`huntSolvedProvider` (`settings_store.dart`), `kHuntNotes` & co. (`skin_catalog.dart`, `kSecretAnswer` removed), `onDivideByZero` + `errorNote` (`calculator_controller.dart`, `calculator_state.dart`), new `hunt_note_sheet.dart` and `widgets/ink_spill.dart`, pill + finale in `calculator_screen.dart`, `_MysteryTile` opens the note (`settings_sheet.dart`); `secret_skin_test.dart` rewritten (229 tests). Not yet bumped or committed; not run on a phone.

- **2026-10-13** — Build number bumped to `1.4.0+12` for the release build (aab + apk); `RELEASE_NOTES.md` 1.4.0 entry now says build 12.
- **2026-10-12** — Owner's picks: **Peony removed, Blueprint is the third free skin** (takes Peony's enum index), **Newsprint is the secret skin**; Prism and the other candidates deleted with their finishes (`theme_tokens.dart`, `skin_catalog.dart`, `extruded_number.dart`, tests, README). Store mockups are back as live phones: `SkinPhone` + rebuilt `SkinSwatch`, bundle hero with three phones (`theme_card.dart`, `theme_store_screen.dart`, `theme_detail_sheet.dart`); Blueprint's settings tile uses its line colour (`settings_sheet.dart`).
- **2026-10-12** — Five secret-skin candidates added for the owner to try in the app (`theme_tokens.dart`, `skin_catalog.dart`, finishes in `extruded_number.dart`, grid in `calculator_screen.dart`, listed in `settings_sheet.dart` behind `kShowSecretCandidates`). Temporary.
- **2026-10-12** — Settings skin grid no longer lists locked premium skins (owner: five locked tiles broke the layout); they are reached through the store banner (`settings_sheet.dart`, `secret_skin_test.dart`).
- **2026-10-12** — Error lines made smaller and shallower with the plain reason beneath (`maxFontSize` on `ExtrudedNumber`, `numeral_animator.dart`, `calculator_screen.dart`). Secret slot moved to second place in the settings grid (`settings_sheet.dart`, `secret_skin_test.dart`). Owner rejected Prism; replacement pending their pick.
- **2026-10-12 — 1.4.0+11 (Phase A of the plan)**:
  - *Errors*: `CalcError` split into nine cases with rotating fun lines (`calc_error.dart`, `evaluator.dart`, `_showError` in `calculator_controller.dart`); hero numerals get the plain reason as their semantics label.
  - *Typing*: rise-from-below removed; per-digit turn-in, eased refit (`extruded_number.dart` rewritten, `numeral_animator.dart`).
  - *Secret skin* (first as Prism with a rainbow `holo` finish, replaced the same day by Newsprint, see above): `kSecretSkins`/`kSecretAnswer`, `secretUnlocked`, `secretFoundProvider`, pill on `calculator_screen.dart`, `_MysteryTile`; `test/secret_skin_test.dart`.
  - *Owned first*: settings grid order; YOURS section in the store.
  - *Store* (first as flat numeral swatches, then as live `SkinPhone` mockups, see above): `SkinSwatch` cards replace PNG mockups and the carousel (`theme_store_screen.dart` rewritten, `theme_card.dart`); `assets/skins/` and `tool/generate_skin_mockups.dart` deleted, `pubspec.yaml` asset entry removed.
  - README, `RELEASE_NOTES.md`, `_appVersion` → 1.4.0. `calculator_screen.dart` was reformatted by `dart format` in passing. Nothing here has run on a phone.

- **2026-10-12** — Promo v3 `assets/Mockup Videos/popcalc_promo_9x16_v3.mp4` (17 s): skins scene cut to 3 s (owner: not every skin needs showing), a slow push-in on every shot, light grade and vignette, and the Google Play badge (`_edit/badge.png`, downloaded from a URL the owner gave) in place of the text call to action. `_edit/build2.py` and `_edit/music.py` now produce v3.
- **2026-10-12** — Promo v2 `assets/Mockup Videos/popcalc_promo_9x16_v2.mp4` (18 s, 1080x1920, cuts on a 120 BPM grid). Its scripts are kept beside it in `_edit/` (ignored): `music.py` synthesizes the backing track in pure Python (no numpy/PIL on this machine), `build2.py` cuts the shots with ffmpeg (`zoompan` punch-ins, `drawtext` lower thirds over a `geq` scrim); run both from a scratch folder. The skins clip was replaced by the owner with a 10.7 s `... - Trim.mp4` (ends at Chrome). `.claude/skills/` and `.agents/` are in `.gitignore`; the installed skills (`product-launch-video`, `video-edit`) were not used for this cut.
- **2026-10-12** — Marketing: `assets/Mockup Videos/` (raw 4K mockup clips, ~146 MB, plus edits such as `popcalc_promo_9x16.mp4`) is now in `.gitignore`; it is not bundled in the app (not under `flutter.assets`). The 2026-10-10 clip in it is a different app (ZeroPuff), never use it. Promo cuts are made with ffmpeg (installed via WinGet); in `drawtext` use a relative `fontfile` (absolute Windows paths crash it).
- **2026-10-12** — Edge-to-edge check after the Play Console notice: main screens already used `SafeArea`; history list and settings scroll now add the bottom system inset (`history_sheet.dart`, `settings_sheet.dart`). Gotcha added.
- **2026-10-12** — Build number bumped to `1.3.1+10` (version name unchanged) for the open-testing release; `RELEASE_NOTES.md` 1.3.1 entry now says build 10.
- **2026-10-12** — Settings footer shows `VERSION 1.3.1` without the build number (`_appVersion` in `settings_sheet.dart`). Pending live-preview history entries no longer keep a trailing operator (`_savePendingPreviewIfNeeded` in `calculator_screen.dart`; test extended in `live_preview_history_test.dart`). README version → 1.3.1; added the 1.3.1 entry to `RELEASE_NOTES.md`.
- **2026-10-11** — Fix: `=` now works when the expression ends with an operator (`99+66+99+88+` → 352); trailing operators / lone `-` are trimmed in `CalculatorController.onEquals` (`calculator_controller.dart`). 3 new tests in `test/engine/calculator_controller_test.dart` (216 total).
- **2026-10-11** — Rewrote this file as full documentation (folder map, engine rules, controller behaviour, storage keys, skins/materials, purchases, store UI, widgets, converter, audio, haptics, tests, tool recipes, lookup table). Confirmed `main` up to date with origin; 213/213 tests pass. Noted stale README version (1.3.0) and missing 1.3.1 release-notes entry (not yet fixed).
- **v1.3.1+9 (e8c638c)** — Scientific landscape layout (all keys at once, `ScientificTray(grid: true)`, `_allowLandscape`), flat lite mode (single face, no extrusion/tilt), live-preview auto-save to history on app pause (`savePendingPreview`), tests `live_preview_history_test.dart` and landscape cases in `advanced_mode_widget_test.dart`.
- **a69580c** — Google Play purchases (`PlayPurchaseService`, `BillingGateway`, fake store for debug/tests) and skin store redesign (carousel, sheets, restore).
- **f26c64a** — Materials: Clay, Chrome, Glass, Wood, Candy, Neon, Mechanical with sound folders, `HapticFeel`s and finishes.
- **ebc0e94** — Skin store with premium skins, bundle carousel, hold-to-preview.
- **v1.2.0+5** — Scientific & Converter (engine powers/parens/functions/constants/factorial, scientific tray, unit converter, per-kind scientific sounds/haptics, launch sound, converter detents).
- **v1.1.1+4** — Six new skins; Marigold/Charcoal renames; token-editing bug fixes.
- **v1.1.0+3** — Sound packs, native haptics, typing/celebration animations.
