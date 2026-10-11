# CLAUDE.md

Complete working documentation for PopCalc. It exists so a session never has to re-read the codebase to find out what is where. **Read this first; open source files only to edit them.**

## Standing rules for Claude (from the owner)

1. **After every change, however small, update this file in the same session**: the file map, the relevant section, the "Where to change X" table if a location moved, and a dated line in [Change log](#change-log). If you add a file, a setting key, a provider, a sound, a skin, a test, a gotcha — it goes here.
2. **Pull `main` before starting work** (`git fetch origin && git pull --ff-only origin main`). `macos/Flutter/GeneratedPluginRegistrant.swift` is a perpetual unrelated local modification; ignore it, never commit it.
3. **Never run `flutter build …`** (apk/appbundle). Give the user the command in a `bash` block and let them run it. `flutter analyze` and `flutter test` are fine to run.
4. Skin names: Charcoal (ink), Marigold (sunny), Peony, Obsidian, Synthwave, Matcha, Frost, Velvet. Never use the names "Andy" or "Graphite".
5. `flutter_soloud` stays pinned to 4.x (5.x needs a host C++ toolchain just to run `flutter test`). Don't upgrade it.
6. Don't trust `architecture.md` (a plan, partly different from what was built). Trust `lib/`.
7. No phone/emulator has ever been connected in a session: verify UI with widget tests / test-rendered screenshots (recipe below). Sounds, haptics, landscape and real Play purchases have never been tried on hardware; say so when reporting.

## Project at a glance

PopCalc — offline, Android-first Flutter calculator with extruded 3D numerals, tactile motion, sounds and haptics. No ads, no account, no data collected. Package `com.ornobaadi.popcalc` (debug/profile get `.dev` suffix and label "PopCalc Dev"). Dart SDK `^3.13.4`, so Dart 3 syntax is used freely (null-aware elements `?x`, wildcard params `(_, _)`, records, switch expressions).

- **Version**: `pubspec.yaml` `version: 1.3.1+10` (build 9 was the first 1.3.1 upload; 10 adds the `=` fix and goes to open testing). Must be repeated by hand in `_SignatureFooter._appVersion` (`'1.3.1'` — **version name only, never the build number**; `lib/features/settings/presentation/settings_sheet.dart`), `README.md` and a new entry at the top of `RELEASE_NOTES.md`.
- **Portrait-only, except scientific mode**, which may rotate to landscape (see [Orientation](#orientation)). The converter, splash, store and history are portrait.
- **Skins**: 3 free (Marigold, Charcoal, Peony) + 5 premium skins + 7 "materials" (premium; look + sound + haptics as one set) = 15 `AppThemeMode`s. Premium ones are one-time Google Play products, plus an "everything" bundle.
- **Test status** (2026-10-12): `flutter test` → 216 tests, all pass (the old failing smoke test `test/widget_test.dart` is fixed).
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
flutter test tool/generate_skin_mockups.dart --update-goldens   # regenerate assets/skins/*.png
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
                              numeral_animator, celebration_burst, grain_overlay, backspace_icon)
    converter/application/    converter_controller
    converter/presentation/   converter_screen
    history/presentation/     history_sheet
    settings/presentation/    settings_sheet
    splash/presentation/      splash_screen
    themes/presentation/      theme_store_screen, theme_detail_sheet, theme_bundle_sheet,
                              theme_card, theme_preview_overlay, store_widgets, purchase_feedback
test/        engine/, core/, units/, + widget tests (see Tests)
tool/        generate_sounds.py, generate_skin_mockups.dart
assets/      fonts/, sounds/<folder>/, skins/<mode>.png, textures/noise.png, splash/,
             brand_assets/, ornob-aadi-signature/, readme/, licenses/
android/app/src/main/kotlin/com/ornobaadi/popcalc/MainActivity.kt   native haptics channel
```

Layering rule: `core/engine` and `core/units` import **no Flutter**. Feature-first otherwise; state is Riverpod **`StateNotifierProvider`** everywhere (not the newer Notifier API). Fonts (bundled): **BebasNeue** headings/keys/numerals, **Inter** body/descriptions/small labels (≈12% wider than Antonio/Bebas, size it ~12% smaller), **Antonio** only for the lowercase `e` constant, numeral fallback and splash wordmark (Bebas is caps-only).

## App startup flow

`main()` → `WidgetsFlutterBinding.ensureInitialized` → `SettingsNotifier.initAudio()` (reads prefs, `AppSounds.init`, **1.5 s timeout** so audio can never block launch) → lock portrait → transparent system bars → `runApp(ProviderScope(PopCalcApp))`.

`PopCalcApp` (ConsumerWidget): watches `themeProvider`; calls `applyMaterialFeel(ref.watch(materialFeelProvider))` **inside build** (side effect on every rebuild, idempotent); `ref.listen`s purchases and theme to `keepToOwnedSkin()` — if purchases are `loaded` and the active skin is not owned, `setTheme(AppThemeMode.sunny)` (Marigold). Watching `purchasesProvider` here is also what starts the store at launch. `builder` wraps in `AnnotatedRegion<SystemUiOverlayStyle>` so status/nav icon brightness follows `colors.isDark`. Home is `SplashScreen`.

`SplashScreen`: `AppSounds.launch()` (typewriter "skrr"), 1500 ms animation (mark pop 0–60 %, "POP CALC" wordmark 30–90 %, Antonio w700), then `_goHome`: re-lock portrait, `pushReplacement` to `CalculatorScreen` with a 420 ms fade. Native splash colours/images: `flutter_native_splash.yaml` (#FFAE00 light / #141414 dark; follows device setting, not the in-app skin).

## Math engine (`lib/core/engine/`, pure Dart)

Pipeline: `Expression` (immutable) → `Parser` → AST → `Evaluator` → `Decimal` → `NumberFormatter`. Errors are `CalcError` (`divideByZero` "Can't divide by zero", `overflow` "Overflow", `invalidExpression` "Error", `domainError` "Not defined"); evaluator throws `CalcException(error)`.

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
- `onEquals`: first **drops trailing operators** (and a lone `-` currentNumber), so `99 + 66 +` `=` gives 165 and the expression line/history show `99 + 66` without the hanging operator (state `expression` is replaced by the trimmed one); nothing left → no-op. Then strict parse; a dangling opener (`sin(`) is ignored quietly, any other malformed expression shows `invalidExpression`. Success adds to history, sets `justEvaluated`, `celebrationId + 1`. `_showError` clears editing/preview.
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

Other keys: theme `settings_theme_mode` (**int index of `AppThemeMode`** — only ever append enum values), converter `converter_category` / `converter_from` / `converter_to`, purchases `purchases_owned` (Play build) and `settings_owned_products` (fake store). Setters mirror state into `AppHaptics.enabled/strength` and `AppSounds.configure`. Sliders: `setHapticStrength`/`setSoundVolume` apply live while dragging; call `saveHapticStrength`/`saveSoundVolume` on drag end. `setAdvancedTools(true)` also turns `scientificActive` on.

`historyProvider` / `HistoryNotifier` (`history_store.dart`): newest-first `List<HistoryEntry{id, expression, result, timestamp}>`, **cap 50**, append-only JSONL `calc_history.jsonl` in the app documents dir (compacted via `_saveAll` when the file has > 100 lines; `removeEntry` rewrites). `savePendingPreview` stores the in-progress expression + preview (skips if equal to newest; the screen strips trailing operators first, so `1 + 2 +` is saved as `1 + 2`) — called by `CalculatorScreen.didChangeAppLifecycleState` on paused/detached/hidden when live preview is on and the answer isn't already evaluated.

## Theme, skins, materials

- `core/theme/theme_tokens.dart`: `enum AppThemeMode {ink, sunny, peony, obsidian, synthwave, matcha, frost, velvet, clay, chrome, glass, wood, candy, neon, mechanical}` (**index persisted — append only**; `peony` kept Bubblegum's index). `ThemeColors` (`bg, bgShade, ink, inkSoft, accent, extrudeTop, extrudeSide, extrudeShadow, extrudeChamfer, burst, isDark, finish`) with one `const` per skin and `ThemeColors.of(mode)`. `SkinFinish {standard, matte, mirror, glass, grain, gloss, glow, keycap}` — only materials use non-standard.
- `core/theme/app_theme.dart`: `themeProvider` (`ThemeNotifier`, default `sunny`; loads/saves index; `ThemeNotifier.preview(mode)` is fixed, never persists — used by hold-to-preview and the mockup generator), `AppTheme.getThemeData` (font BebasNeue, ColorScheme from tokens), `AppTheme.colorsOf`.
- `core/theme/skin_catalog.dart`: `kPremiumLocked` (**master switch**: `false` ⇒ everything free), `kAllThemesProductId = 'themes_all'`, `SkinInfo` (mode, label, tagline, description, modelCode, productId?, feels), `MaterialFeel` (id, label, description, soundFolder, haptics), lists `kSkins` (8, order shown in settings grid), `kMaterials` (7), `kBundleItems` (premium skins and materials interleaved), `kProductIds`, `skinOf(mode)`.
  - Product ids: `theme_obsidian|synthwave|matcha|frost|velvet`, `material_clay|chrome|glass|wood|candy|neon|mechanical`, `themes_all`.
- `core/theme/material_feel.dart`: `materialFeelProvider` (active skin's feel, using `settings.mechSwitch` for Mechanical, null for ordinary skins) and `applyMaterialFeel(feel)` → `AppSounds.setMaterial(folder)` + `AppHaptics.feel`.

**Materials** (Clay, Chrome, Glass, Wood, Candy, Neon, Mechanical) are exclusive look + sound + haptics sets, never mixed with other skins or sound packs; the 8 ordinary skins and 3 packs are untouched by them.
- *Look*: `ThemeColors.finish`. `extruded_number.dart` lays `_finishShader` gradient over the face (matte soft light, mirror sky/horizon, glass top-edge, grain repeated bands, gloss highlight, glow white-hot core) and a blurred halo for glow; `keycap` draws no numeral finish but makes `KeyButton` render keycaps via `KeycapScope.wrap` around the keypad (Mechanical).
- *Sound*: folders `clay chrome glass wood candy neon mech_clicky mech_tactile mech_linear` under `assets/sounds/`, built by `MATERIAL_PACKS` (seed `100 + index`, so adding one never changes existing WAVs). Not `SoundPack` values; never in the pack picker.
- *Haptics*: `HapticFeel` enum + `_feels` map in `app_haptics.dart` swaps digit/operator/utility/backspace patterns (same native primitives, no Kotlin change).
- Settings sound section: pack chips replaced by a note, or by switch chips for Mechanical.

**Add a skin** = `AppThemeMode` value (append!) + `ThemeColors` const + `ThemeColors.of` case + `SkinInfo` in `kSkins` (with `productId` if premium) + a `_Layout` in `tool/generate_skin_mockups.dart` + regenerate mockup + create/activate the product in Play Console.
**Add a material** = also a `finish`, a `kMaterials` entry with `MaterialFeel`s, a pack in `MATERIAL_PACKS` + folder under `flutter.assets` in `pubspec.yaml`, a `HapticFeel` + `_feels` entry; update tests that count them (`test/materials_test.dart`).

## Purchases (`core/storage/entitlement_store.dart`, `play_purchase_service.dart`)

- `PurchaseService extends StateNotifier<PurchaseState>`: `buy(productId) → BuyOutcome {purchased, pending, cancelled, unavailable, failed}`, `refresh()` (prices + what the account holds; also what Restore calls; returns false if Play unreachable). `PurchaseState`: `owned`, `pending`, `prices` (Play's own text — never hardcoded), `amounts` (numbers), `loaded`, `checking`; `canBuy(id)` = has a price and not pending; `bundleSaving` = whole % off buying everything singly, **null unless every product has a price and saving ≥ 5 %**.
- `purchasesProvider`: **`kReleaseMode ? PlayPurchaseService() : FakePurchaseService()`** — debug/profile (app id `.dev`, which Play can't sell to) and tests get the fake: free, instant, placeholder prices (`$0.99` skins, `$1.99` materials, `$2.99` Mechanical, `$6.99` bundle), persisted in `settings_owned_products`.
- `PlayPurchaseService` talks to Play through `BillingGateway` (tests inject a scripted fake in `test/core/play_purchase_service_test.dart`). Start: listen to the purchase stream first, load saved `purchases_owned` (so skins work offline), then `refresh()` → `_matchPlayAccount` **replaces** saved owned with what Play holds (refunds taken back, purchases from another phone appear; if Play can't say, the saved set stands). Paid purchases are acknowledged (Play refunds unacknowledged after 3 days); pending ones are neither owned nor acknowledged until paid. Patience 12 s per call. An error flow re-checks the account (Play reports an error for "already owned").
- `entitlementProvider` = owned ids; `ownsSkin(owned, skin, {locked = kPremiumLocked})` = free ∨ unlocked ∨ has bundle ∨ has product.
- Manifest has `com.android.vending.BILLING` + `VIBRATE`.

## Skin store UI (`features/themes/presentation/`)

- `theme_store_screen.dart` — `ThemeStoreScreen.open` (fade+slide route; opened from the settings banner). Rechecks prices on init. Layout: back + "SKIN STORE", `BundleCarousel`, **MATERIALS** row (card width = 1.75 across), **PREMIUM SKINS** row (2.3 across), "RESTORE PURCHASES" button with result note. `BundleCarousel`: endless wheel driven by an **unbounded `AnimationController`** (not a PageView); auto-turns every `BundleCarousel.dwell` (2200 ms, 520 ms ease), one skin per swipe however hard (clamped ±1), recolours only its own box to the front skin, shows only the "n% OFF" chip (no price); tap → `BundleDetailSheet`.
- `theme_card.dart` — `SkinMockup` (square `assets/skins/<mode>.png` in a rounded border), `SkinCard` (mockup + label + model code + `_StandingPill`), `SkinStanding {active, owned, forSale, notForSale}`.
- `theme_detail_sheet.dart` — `SkinDetailSheet.show(ctx, skin, {fromBundle})`: drawn in that skin's colours; mockup, tagline, description; materials get "tap to hear and feel it" demo buttons (`AppSounds.previewMaterial` + `AppHaptics.demo`, each tap = next digit); footer: **hold to preview** (`ThemePreview` on pointer down/up), then ACTIVE / APPLY / UNLOCK+price, purchase note, and "Or everything for $X [n% OFF]" unless opened from the bundle sheet.
- `theme_bundle_sheet.dart` — `BundleDetailSheet`: every mockup in a 4-col grid (each opens its skin sheet with `fromBundle: true`), `_ValueCard` (contents summed singly, struck through, vs bundle, "You save …"), GET EVERYTHING / OWNED.
- `theme_preview_overlay.dart` — `ThemePreview`: inserts an `OverlayEntry` on the root overlay with the real `CalculatorScreen` inside a nested `ProviderScope` overriding `themeProvider` with `ThemeNotifier.preview(skin.mode)`; saved skin untouched; fades out then removes itself.
- `store_widgets.dart` — `SavingChip` ("64% OFF"), `Pressable` (0.97 scale), `StoreButton` (54 px pill, text shrinks to fit prices), `StoreSheet` (rounded frame; body scrolls, footer buttons stay in view; max 90 % height).
- `purchase_feedback.dart` — `priceTag`, `purchaseNote`, `purchaseHaptic`, `recheckPrices(ref, ids)` (microtask refresh when any price is missing), `moneyLike` (writes a computed total in Play's own currency format), `BundleValue.of`, `PurchaseNote`.
- Settings sheet shows free + premium skins always, materials only once owned; locked tile tap opens its `SkinDetailSheet`.

## Calculator screen & widgets (`features/calculator/presentation/`)

**`calculator_screen.dart`** (`CalculatorScreen`, `ConsumerStatefulWidget` + `WidgetsBindingObserver`): `scientific = advancedTools && scientificActive`; `landscape = scientific && width > height*1.2 && height < 560` (tall wide windows like tablets keep the centred frame). Portrait column (max width 440, SafeArea): `TopBar` → `ExpressionLine` → hero (`TweenAnimationBuilder` flex ×10: **44** simple / **24** scientific expanded / **34** scientific folded, 260 ms) → `ScientificTray` (in an `AnimatedSwitcher`/SizeTransition, padding 18/0/18/6) → `Keypad` (flex 520, padding 24/0/24/20). Landscape row: display 34 % (top bar compact, expression, hero) | `ScientificTray(grid: true)` 31 % | keypad 35 %. Background: radial gradient `bgShade→bg` + `GrainOverlay`. Hero stack: `CelebrationBurst`, `AnimatedExtrudedNumber` (tap toggles whole-result highlight, long-press copies result without commas → clipboard + snackbar), DEG/RAD `_AngleBadge` (portrait scientific only; toggles `AngleUnit` with `AppHaptics.shift`). `_resultHighlighted` makes the next digit/decimal replace the result (`Keypad.highlightMode`, consumed via `onHighlightConsumed`). Converter button: `AppHaptics.mode(true)`, `_allowLandscape(false)`, push converter, rebuild on return.

<a name="orientation"></a>**Orientation**: `main()` and `SplashScreen._goHome` lock portrait; `CalculatorScreen._allowLandscape(scientific)` adds landscapeLeft/Right only while scientific is on (cached in `_landscapeAllowed`); `ConverterScreen` forces portrait on init and restores (incl. landscape if it was scientific) on dispose.

**`top_bar.dart`** (height 44): left = History (`access_time_rounded`) + (if `advancedTools`) `_ScientificToggle` f(x) (accent-lit while scientific; `AppHaptics.mode`); right = (if `advancedTools`) converter ruler `straighten_rounded` + Settings `tune_rounded` (`SettingsSheet.show`). `compact` shrinks side padding for landscape.

**`keypad.dart`**: 5 rows × 4 — `C % ⌫ ÷` / `7 8 9 ×` / `4 5 6 −` / `1 2 3 +` / `0 . +/- =`. Each `KeyButton` has a `haptic` and `sound` fired on touch-down. Operators → `AppHaptics.operatorKey`/`AppSounds.operatorKey`; C → `clear`; % and +/- and `.` → utility; `=` → `selectionClick`, no key sound (the answer plays `success`). Font sizes 32–48. Wrapped in `KeycapScope.wrap`.

**`key_button.dart`**: press scale 1→0.88 (70 ms / 120 ms), pressed fill = colour @16 %; `onTapDown` fires haptic + panned sound (pan = `(x/width − 0.5) × 0.6`), `onTapUp` fires `onTap`. `KeycapScope` InheritedWidget switches to the keycap look (dark skirt, lighter top face that sinks).

**`scientific_tray.dart`**: `ScientificTray({colors, grid})`. Portrait: handle (tap or swipe ±150 velocity folds/unfolds row 2, persisted in `scientificExpanded`), row 1 (swap `⇄`, xʸ, √, `(`, `)`, π) and row 2 (sin cos tan ln log !), key height `rowHeight = 46`. The **⇄ "second" key flips every key to its inverse**: row 1 → x², ∛, `(`, `)`, e; row 2 → sin⁻¹ cos⁻¹ tan⁻¹ eˣ 10ˣ !; a used 2nd-layer key drops back (`once`). `grid: true` (landscape) lays out all 5×4 keys at once (`( ) π e` / `x² xʸ √ ∛` / `sin cos tan DEG|RAD` / `sin⁻¹ cos⁻¹ tan⁻¹ !` / `ln log eˣ 10ˣ`), no swap key. `_Feel` enum pairs each key kind with an `AppHaptics` pattern and `Sfx`. Function keys call `controller.onOpener(Token(function, 'name('))`. `_TrayKey` draws superscripts/root index manually (fonts lack glyphs); `e` uses Antonio.

**`expression_line.dart`**: 56 px tall, 40 pt Bebas, horizontal scroll `reverse: true` (newest in view). Each token is a `_TokenChip` (fixed padding + 2 px border so selection never shifts layout; only colours animate, 130 ms). Operators and `%` accent-coloured. Trailing `=` chip after evaluate; or `= preview` when live preview is on.

**`extruded_number.dart`** (`ExtrudedNumber` + `_ExtrudedNumberPainter`): font = min(height × 0.88, 200) ≥ 64, shrunk to fit width − 40 (≥ 40). Layers: neon halo → blurred contact shadow → **36–64 stamped copies** of the text from `extrudeSide` to a rim colour along the extrusion vector (direction = base lower-right `(0.55, 0.82) × 18 × depth` + tilt × 0.55) → front face → finish shader → chamfer stroke. **Lite mode paints one flat face** (+ finish). `_painterCache` (max 16) keyed by text/size/colours/lite. `isZero` ⇒ opacity 0.28, depth 0.35.

**`numeral_animator.dart`** (`AnimatedExtrudedNumber`): 7 controllers — depth spring (240 ms easeOutBack), scale, error shake (320 ms, ±12 px), idle breathing (4 s, 0.97–1.0), drag spring-back (600 ms elasticOut), typing stamp (280 ms rise/drop), celebration (720 ms pop + wobble). `didUpdateWidget` order: error → shake + `AppHaptics.error` + `AppSounds.error`; `celebrationId` increase → pop + `AppHaptics.success` + `AppSounds.success`; text change → type animation. Touch drag (< 7 px = tap → `onTap`) + **accelerometer** (`sensors_plus`, EMA 0.86/0.14, `setState` each event) drive 3D tilt (perspective `0.001`, ±0.28 rad) and the extrusion light. Lite mode skips the perspective transform. The converter reuses this widget.

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
- **`settings_sheet.dart`** (72 % height, scrolls): title "SKINS" → 4-column hex tile grid (`_SkinTile`, lock on unowned) → `_StoreBanner` (fanned mockups, "SKIN STORE", saving chip or "Everything unlocked" / "N skins and M materials") → rows: Scientific & Converter, Live Preview on Top, Haptic Feedback + strength slider, Lite Effects Mode → SOUND section (Sound Effects switch + volume slider, pack chips or Mechanical switch chips, descriptive note) → `_SignatureFooter` (signature PNG chosen by `isDark`, version line, "OFFLINE · NO ADS · NO TRACKING"; **tapping the signature 5× within 1.5 s each opens ornobaadi.vercel.app** — hidden).
- Switch styling: `activeThumbColor: colors.accent`, track accent @35 %.

## Tests (`test/`, 216 tests, all green on 2026-10-12)

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
| `theme_store_widget_test.dart` | buy→apply, hold to preview, bundle sheet, carousel behaviour, Play states, fallback to Marigold |
| `advanced_mode_widget_test.dart` | top-bar buttons, f(x) toggle, tray fold, converter open/swipe, **landscape grid** |
| `live_preview_history_test.dart` | pending preview saved to history on pause |
| `widget_test.dart` | calculator smoke test |

Tests run under the **Ahem** font (every glyph a square), so text is far wider than on a phone: an overflow in a widget test is a hint, not proof. Mock the sensors channels (`dev.fluttercommunity.plus/sensors/*`) when pumping screens (see `tool/generate_skin_mockups.dart`).

**Screenshot recipe (no device)**: write a temporary `test/zz_shot_test.dart` that loads the real fonts with `FontLoader` (BebasNeue, Antonio, Inter from `assets/fonts/`, MaterialIcons from `C:/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf`), precaches asset images inside `tester.runAsync`, sets `debugDisableShadows = false` (restore `true` before the test ends), and `expectLater(find…, matchesGoldenFile('zz_shots/<name>.png'))` with `flutter test --update-goldens`. Golden paths must be relative (absolute `C:/` silently writes nothing). Copy PNGs to the scratchpad, show with SendUserFile, then delete the test and `test/zz_shots`. Git Bash heredocs with mixed quotes fail here ("unexpected EOF"): write patch scripts with the Write tool instead.

## Tools

- `tool/generate_sounds.py` — see Audio. Voices: bloop, marimba, noise_burst, resonant_click, bell, sweep, whoosh, partials, chirp; `pack_pop/mellow/typewriter`, `material_pack(...)` builders, `scientific_sounds(tone)` per pack, `mech_key` for switches; `normalize` = tanh drive, `fade_edges` 3 ms.
- `tool/generate_skin_mockups.dart` — a *test* (`flutter test … --update-goldens`) that renders the real calculator (digits 1-2-8) per skin in `_layouts` (only store-sold skins, 12) inside a tilted phone frame with the skin name in its accent colour → 600 px `assets/skins/<mode>.png`. Regenerate after changing a skin's colours; never edit PNGs by hand.

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
| Change a skin's colours | `core/theme/theme_tokens.dart`, then regenerate mockups |
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

## Change log

Newest first. Add a line for every change (date, what, files).

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
