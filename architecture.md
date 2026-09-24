# Architecture: Pop Calc

A small, offline, single-module Flutter app. The guiding rule: **keep the math engine pure Dart, keep animation in the UI layer, and keep monetization behind one interface.** That makes the app easy to test, easy to change, and hard to break.

> Package names and versions below are starting points. Check pub.dev for the current stable versions and read each package's changelog before pinning.

---

## 1. Tech stack

| Concern | Choice | Why |
|---|---|---|
| Framework | Flutter (current stable), Dart 3 | Your stack, one codebase, Impeller renderer on Android |
| State management | `flutter_riverpod` | Simple, testable, no context needed in logic |
| Decimal math | `decimal` (+ `rational`) | Exact base-10 arithmetic, no `0.1 + 0.2` bugs |
| Settings storage | `shared_preferences` | Tiny key-value data: theme, toggles, Pro flag cache |
| History storage | JSON lines file via `path_provider` | Zero extra dependencies, plenty for 50 to a few thousand rows |
| Purchases | `in_app_purchase` (+ `in_app_purchase_android`) | Official plugin, wraps Play Billing |
| Haptics | Flutter `HapticFeedback` (built in) | No extra package needed |
| Sound (Pro) | `flutter_soloud` or `audioplayers` (low latency mode) | Sub-50 ms playback for key clicks |
| Tilt (Pro) | `sensors_plus` | Accelerometer stream for parallax |
| Animation | Built-in `AnimationController`, `SpringSimulation`, `CustomPainter`; optionally `flutter_animate` | Full control of the 3D numeral effect |
| Fonts | Bundled Antonio variable font (SIL OFL) | Offline, variable weight axis |
| Lints | `flutter_lints` or `very_good_analysis` | Keeps code consistent |
| Tests | `flutter_test`, `mocktail`, golden tests | Engine correctness plus visual regression |

Keep the dependency list short. Every plugin is code you must keep updated, and each one can change your Data Safety answers or permissions.

## 2. High-level structure

```
lib/
  main.dart
  app/
    app.dart                  MaterialApp, theme wiring, locale
    router.dart               (only needed if you add more screens)
  core/
    engine/                   PURE DART, no Flutter imports
      token.dart              Token types: number, operator, percent, parens
      expression.dart         Expression model + editing rules
      parser.dart             Tokens to AST
      evaluator.dart          AST to Decimal, percent semantics
      formatter.dart          Decimal to display string (locale, sci notation)
    haptics/haptics_service.dart
    audio/sound_service.dart
    storage/
      settings_store.dart
      history_store.dart
    theme/
      app_theme.dart          ThemeData from tokens
      theme_tokens.dart       Color tokens per theme
      typography.dart
  features/
    calculator/
      application/
        calculator_controller.dart   Notifier: input to expression to state
        calculator_state.dart
      presentation/
        calculator_screen.dart
        widgets/
          extruded_number.dart       CustomPainter numeral
          expression_line.dart
          keypad.dart
          key_button.dart
          top_bar.dart
    history/
      application/history_controller.dart
      presentation/history_sheet.dart
    themes/
      presentation/theme_picker.dart
    pro/
      domain/entitlement.dart
      data/purchase_service.dart     Interface + Play Billing implementation
      application/pro_controller.dart
      presentation/pro_sheet.dart    Paywall bottom sheet
    settings/
      presentation/settings_screen.dart
assets/
  fonts/Antonio/...
  sounds/...
  textures/noise.png
  licenses/
test/
  engine/                     Heavy unit tests
  golden/                     Visual regression
```

Feature-first folders keep everything about one feature together. The `core/engine` folder has **no Flutter imports** so it runs in plain Dart tests and could be reused on another platform.

## 3. Math engine

### 3.1 Data flow

```
Key press
  -> CalculatorController.onKey(KeyId)
  -> Expression.apply(key)          (edit rules: replace operator, block double decimal, etc.)
  -> Parser.parse(tokens)           (tolerant: ignores a trailing operator for preview)
  -> Evaluator.evaluate(ast)        (Decimal result or error)
  -> Formatter.format(decimal)      (display string)
  -> CalculatorState
  -> UI rebuilds
```

### 3.2 Tokens and grammar

Tokens: `Number`, `Plus`, `Minus`, `Multiply`, `Divide`, `Percent`, and later `LParen`, `RParen`.

Grammar (percent binds to the number before it):

```
expr    := term (('+' | '-') term)*
term    := factor (('x' | '/') factor)*
factor  := '-'? primary
primary := NUMBER '%'? | '(' expr ')' '%'?
```

### 3.3 Percent semantics in the evaluator

Percent depends on its neighbor operator, so the evaluator carries the left operand when it sees `a op b%`:

```dart
Decimal applyBinary(Decimal a, Op op, Operand b) {
  final bVal = b.isPercent ? b.value / hundred : b.value; // "b%" as a plain fraction
  switch (op) {
    case Op.add:      return b.isPercent ? a + a * bVal : a + bVal;
    case Op.subtract: return b.isPercent ? a - a * bVal : a - bVal;
    case Op.multiply: return a * bVal;                 // 80 x 25% = 20
    case Op.divide:   return divide(a, bVal);          // 50 / 25% = 200
  }
}
```

Standalone `b%` evaluates to `b / 100`.

### 3.4 Precision rules

- Parse input strings straight into `Decimal`, never through `double`.
- Division returns a `Rational` in the `decimal` package. Convert with a fixed scale (for example 12 fractional digits) and round half-even or half-up, then trim trailing zeros.
- Cap displayed significant digits at 15. Beyond that, use scientific notation.
- Guard against absurd input: limit each number to about 15 digits and the expression to about 60 tokens.
- Division by zero returns a typed error (`CalcError.divideByZero`), never an exception in the UI.

### 3.5 Test plan for the engine

Target 100 percent branch coverage on `core/engine`.

| Category | Examples |
|---|---|
| Basics | `2+3=5`, `7-10=-3`, `6x7=42`, `9/3=3` |
| Precision | `0.1+0.2=0.3`, `1/3` shows 12 digits, `2.50` shows `2.5` |
| Precedence | `2+3x4=14`, `10-6/2=7` |
| Percent | `1024+5%=1075.2`, `255+5%=267.75`, `200-15%=170`, `80x25%=20`, `50/25%=200`, `12%=0.12` |
| Editing rules | `5++3` becomes `5+3`, `007` becomes `7`, `1.2.3` blocks the second `.` |
| Errors | `5/0` returns divide-by-zero, recovers on the next key |
| Limits | Long inputs, huge exponents, negative zero |
| Formatting | Locale separators, scientific notation threshold |

Add a property-based test if you like: random valid expressions evaluated by your engine and by a trusted reference implementation in test code.

## 4. State management

One `CalculatorController` (a Riverpod `Notifier`) owns the state:

```dart
class CalculatorState {
  final Expression expression;     // tokens the user has entered
  final String expressionText;     // formatted for the top line
  final String resultText;         // main numeral text
  final String? previewText;       // live preview while typing
  final CalcError? error;
  final bool justEvaluated;        // true right after "="
}
```

Rules:

- The controller does not know about animations. It emits state, and the UI reacts.
- UI-only animation state (depth, weight, shake) lives in widget-level controllers, driven by listening to state changes and by key events.
- Other providers: `settingsProvider`, `themeProvider`, `historyProvider`, `proProvider` (entitlement).
- Provider overrides make widget tests simple: swap in a fake `PurchaseService` or an in-memory `HistoryStore`.

## 5. Rendering and animation architecture

### 5.1 ExtrudedNumber widget

```
ExtrudedNumber(
  text: '1,075.2',
  depth: animatedDepth,       // 0.0 to 1.0
  weight: animatedWeight,     // 100 to 700 (variable font axis)
  theme: extrudeColors,
  tilt: tiltOffset,           // Pro, otherwise Offset.zero
)
```

- Implemented with a `CustomPainter` and `TextPainter` layers, wrapped in `RepaintBoundary` so the keypad never repaints with it.
- Auto-fit: measure text width at the target size, then scale the font size down so the text fits the available width. Animate the scale with a tween so size changes are smooth.
- Variable weight uses `FontVariation('wght', value)` on the `TextStyle`.
- Cache `TextPainter` results keyed by (text, weight, size) to avoid re-layout while only depth animates.

### 5.2 Animation driver

A small `NumeralAnimator` class owns the controllers for depth, weight, and shake, and exposes intent methods:

| Method | When |
|---|---|
| `digitEntered()` | Spring depth from 0 to 1 on the newest digit |
| `evaluated()` | Weight 200 to 700 and depth up over `resultMorph` |
| `cleared()` | Collapse and drop |
| `error()` | Shake |

Because the controller only calls intent methods, animation code stays out of business logic and can be tuned in one place.

### 5.3 Performance budget

| Item | Budget |
|---|---|
| Frame time | Under 16 ms average, no jank frames during typing |
| Extrusion layers | 12 default, 4 in Lite mode |
| Blur | One shadow blur per numeral, none in Lite mode |
| Rebuild scope | Keypad is `const` where possible, numeral in its own `RepaintBoundary` |
| Startup | Under 1 second to interactive on a mid-range device |
| APK/AAB size | Under 15 MB, mostly fonts and sounds |

Profile with Flutter DevTools in profile mode on a real, low-end device, not only an emulator.

## 6. Persistence

| Data | Store | Notes |
|---|---|---|
| Selected theme, toggles (haptics, sound, Lite, tilt) | `shared_preferences` | Loaded before `runApp` to avoid a theme flash |
| History | JSON lines file in app documents dir | Append on `=`, cap at 50 for free, more for Pro. Write off the UI thread if it grows |
| Pro entitlement cache | `shared_preferences` | A cache only. Play Billing is the source of truth and is re-queried on start |
| Current expression | Optional, saved on app pause | Restores after process death |

No network, no accounts, no cloud backup of history unless you enable Android Auto Backup deliberately. Decide this on purpose: exclude history from backup if you want to keep the Data Safety story simple.

## 7. Monetization architecture

### 7.1 Abstraction

```dart
abstract class PurchaseService {
  Stream<Entitlement> get entitlement;
  Future<List<ProductInfo>> loadProducts();   // price strings come from Play
  Future<void> buyPro();
  Future<void> restore();
}
```

Two implementations: `PlayPurchaseService` (real) and `FakePurchaseService` (tests, and a debug toggle). The rest of the app only knows `Entitlement.free` or `Entitlement.pro`.

### 7.2 Product setup

| Item | Value |
|---|---|
| Product ID | `pro_unlock` |
| Type | One-time (non-consumable) in-app product |
| Price | Set base price in Play Console, let Play localize |

### 7.3 Purchase flow

1. On launch, connect and query owned purchases. Set entitlement from the result.
2. Paywall reads the product's localized `price` string from Play. Never hardcode prices.
3. `buyPro()` starts the billing flow. Listen to the purchase stream.
4. On `purchased`, grant Pro, then complete and acknowledge the purchase. Unacknowledged purchases are refunded automatically after a few days.
5. Handle `pending` (show "Waiting for payment"), `canceled` (silent), and `error` (friendly message).
6. Provide a **Restore purchases** button that re-queries owned items.

### 7.4 Feature gating

```dart
final isPro = ref.watch(proProvider).isPro;
```

Gate at the UI and settings layer only. Locked items show a live preview (for example, tap a Pro theme to preview it for 5 seconds) then the paywall. Never gate calculation features.

### 7.5 Security note

For a $3 cosmetic unlock, client-side entitlement is acceptable in v1. If piracy becomes real, add server-side verification (a tiny Cloud Function calling the Play Developer API) or move to a purchase service like RevenueCat. Doing that later will not require changing the UI thanks to the `PurchaseService` interface.

### 7.6 Testing purchases

- Add license testers in Play Console with your test Gmail accounts.
- Use an internal or closed test track build. Purchases do not work on sideloaded debug builds signed with a different key.
- Test: buy, cancel, pending, refund, reinstall, restore, airplane mode.

## 8. Platform configuration (Android)

| Item | Setting |
|---|---|
| `minSdk` | 24 or 26 (covers nearly all active devices, tune to your plugin needs) |
| `targetSdk` | 36 (Android 16), the current requirement for new releases |
| Orientation | Locked to portrait in `AndroidManifest.xml` |
| Permissions | Only what plugins add (Billing). Confirm with the merged manifest report |
| Signing | Use Play App Signing. Keep your upload keystore backed up in two places, never in git |
| Build output | Android App Bundle: `flutter build appbundle --release` |
| Shrinking | R8 and resource shrinking on. Test the release build, not just debug |
| Obfuscation | Optional: `--obfuscate --split-debug-info=build/symbols`. Keep the symbols for crash decoding |
| Edge-to-edge | Enabled by default on the newest Android. Make sure insets are handled |

## 9. Testing strategy

| Layer | Tool | What |
|---|---|---|
| Engine | `flutter_test` (pure Dart) | Every rule in section 3.5 |
| Controller | `flutter_test` + Riverpod overrides | Key sequences produce expected state |
| Widgets | `flutter_test` | Keypad taps, history sheet, paywall states |
| Golden | `flutter_test` goldens | Each theme, small and large text, error state |
| Integration | `integration_test` | Type an expression end to end on a device |
| Manual | Real devices | Low-end phone, a tablet or foldable, TalkBack, large fonts, Reduce Motion |

Run the analyzer and the test suite in CI on every push (GitHub Actions is enough).

## 10. CI/CD and release

1. GitHub Actions: `flutter analyze`, `flutter test`, build a release AAB on tags.
2. Store the upload keystore and passwords as encrypted secrets, or build locally if you prefer.
3. Upload manually to Play Console at first. Automate with Fastlane or the Play Developer API later if you ship often.
4. Use version codes that always increase. Keep a simple `CHANGELOG.md` and reuse it for Play release notes.

## 11. Privacy and data architecture

| Question | Answer in v1 |
|---|---|
| Does the app send data anywhere? | No |
| Accounts? | No |
| Advertising ID or analytics SDKs? | None |
| Third-party SDKs | Play Billing through the official plugin only |
| Data Safety form | No data collected, no data shared |
| Privacy policy | A short static page saying the app stores its data on-device only |

If you later add Crashlytics or Analytics, update the Data Safety form, the privacy policy, and consider a consent prompt first.

## 12. Decisions log

| Decision | Choice | Alternative | Reason |
|---|---|---|---|
| Extrusion | Layered 2D painting | Real 3D (Flutter GPU, three.js in WebView) | Cheaper, crisper, works on low-end phones |
| History store | JSON lines | drift, Hive, Isar | Zero dependencies, small data |
| State | Riverpod | Bloc, Provider | Less boilerplate for a small app |
| Math | `decimal` package | `double` | Correctness users can see |
| Monetization | Free + one-time Pro | Paid upfront | Higher installs, try before buy |
| Analytics | None in v1 | Firebase | Keeps Data Safety trivial |
