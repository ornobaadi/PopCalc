# PRD: Pop Calc (working title)

A calculator that feels like a toy and works like a tool. Big, bold, extruded 3D numbers that grow out of the screen as you type, satisfying haptics, and a clean everyday calculator underneath.

> Working title only. Before you commit, search the Play Store and trademark databases for the final name. Generic names like "Calculator" are hard to rank and easy to clash with.

---

## 1. Summary

| Item | Decision |
|---|---|
| Platform | Android first (Flutter), iOS possible later from the same codebase |
| Category | Tools (not Finance) |
| Audience | Everyone, 13 and up. Not designed for children |
| Business model | Free download with a one-time "Pro" in-app purchase (recommended, see section 7) |
| Data collected | None in v1. No accounts, no ads, no analytics |
| Offline | 100% offline |
| Publishing account | Personal Google Play developer account |

## 2. Problem and opportunity

Every phone already ships with a calculator, so a new one only wins on **feel**. Default calculators are correct but forgettable. People customize almost everything else on their phone (wallpapers, icon packs, widgets, keyboards), and a calculator is opened several times a day.

The bet: a calculator with a strong visual identity, tactile motion, and a few delightful details will earn installs from people who want their tools to look good, and a fraction of them will pay a few dollars to unlock the full look.

Inspiration (from the reference images and hero video you shared):

- Condensed, heavy display numerals rendered as **extruded 3D letterforms** with a soft shadow.
- Two themes: a **sunny orange** one and a **dark ink** one with white numerals and orange operators.
- Expression line above the result, with operators highlighted in orange and the active term emphasized.
- Numerals that **morph in weight** (thin outline to heavy solid) as the result changes.

## 3. Goals and non-goals

### Goals

1. A calculator that is correct, fast, and obvious to use in under five seconds.
2. A look and motion style that is instantly recognizable in a 5 second screen recording.
3. A first release small enough to build solo in roughly 4 to 5 weeks part time.
4. A policy-clean listing that passes Play review on a personal account.
5. A fair Pro upgrade that funds the app without nagging.

### Non-goals for v1

- Scientific mode, graphing, matrices, programmer mode.
- Currency conversion or anything requiring internet.
- Loan, mortgage, investment, or tax calculators. These pull the app toward the Finance category and its extra declarations. Revisit later with care.
- Cloud sync, accounts, social sharing feeds.
- Ads. Ads would change the Data Safety form and hurt the premium feel.

## 4. Target users

| Persona | Need | What wins them |
|---|---|---|
| **Style-first phone user** | Wants their phone to look good | Themes, bold typography, screenshots worth sharing |
| **Student** | Quick arithmetic and percentages | Fast, correct, history strip |
| **Shopper and tipper** | "20% off 1,499", "tip on 86.50" | Percent that behaves the way people expect |
| **Small business owner** | Repeated quick totals | Tape/history, copy result, big readable numbers |

## 5. Features

### 5.1 MVP (v1.0, free)

| ID | Feature | Notes |
|---|---|---|
| F1 | Core arithmetic | Add, subtract, multiply, divide, decimal, sign toggle, backspace, clear |
| F2 | Percent that works like people expect | See section 6 |
| F3 | Expression line | Shows the full expression above the result, operators tinted |
| F4 | Live result preview | Result updates as you type when the expression is valid |
| F5 | Extruded 3D numerals | Layered extrusion with depth animation |
| F6 | Weight morph on result | Thin to heavy transition on `=` |
| F7 | Haptics | Light tick per key, stronger on `=`, soft error buzz |
| F8 | History | Last 50 calculations, tap to reuse, swipe to delete |
| F9 | Copy result | Long-press the result |
| F10 | Two themes | Sunny (orange) and Ink (dark), plus follow-system option |
| F11 | Auto-fit large numbers | Digits shrink, never clip, up to 15 significant digits |
| F12 | Accessibility | TalkBack labels, large text support, Reduce Motion support |

### 5.2 Pro (one-time purchase)

| ID | Feature | Notes |
|---|---|---|
| P1 | Extra themes (6 to 8) | Mint, Bubblegum, Paper, Neon, Mono, and so on |
| P2 | Accent color picker | Pick any accent within a curated, contrast-safe palette |
| P3 | Sound packs | Soft click, mechanical, marimba. Off by default |
| P4 | Unlimited history | Plus search and pin |
| P5 | Tilt parallax | Numerals shift subtly with device tilt (accelerometer) |
| P6 | Alternate typefaces | 2 or 3 more condensed display fonts |
| P7 | Home-screen widget | Small calculator or "last result" widget (post v1.0 if time is tight) |

Rule of thumb: **nothing needed to do math is locked.** Pro is cosmetic and comfort only. That keeps reviews healthy and refund requests low.

### 5.3 Later (v1.x and beyond)

- Tip and split helper (kept generic, not framed as finance).
- Unit converter with the same visual language.
- Percent helper cards ("X% of Y", "what percent is X of Y").
- Tablet and foldable layouts.
- iOS release.

## 6. Calculation behavior (must be exact)

Correctness is the trust foundation. Use **decimal arithmetic**, not binary floating point, so `0.1 + 0.2` shows `0.3`.

### Order of operations

Standard precedence: multiply and divide before add and subtract, left to right within the same level.

### Percent semantics

These follow what mainstream phone calculators do:

| Input | Meaning | Example | Result |
|---|---|---|---|
| `a + b%` | a + (a x b / 100) | `1,024 + 5%` | `1,075.2` |
| `a - b%` | a - (a x b / 100) | `200 - 15%` | `170` |
| `a x b%` | a x (b / 100) | `80 x 25%` | `20` |
| `a / b%` | a / (b / 100) | `50 / 25%` | `200` |
| `b%` alone | b / 100 | `12%` | `0.12` |

The hero video shows exactly this behavior: `255 + 5%` gives `267.75`. Use both examples as automated test cases.

### Edge cases

| Case | Behavior |
|---|---|
| Divide by zero | Show "Can't divide by zero", soft error haptic, keep the expression editable |
| Consecutive operators | The latest operator replaces the previous one |
| Leading zeros | `007` becomes `7` |
| Multiple decimals in one number | Ignore the second decimal point |
| Very large or small results | Switch to scientific notation (`1.2345e15`) past 15 digits |
| Trailing zeros | Trimmed (`2.50` shows `2.5`) |
| Negative numbers | `+/-` toggles the current number, shown with a proper minus sign |
| Rotation | Portrait only in v1 (lock orientation) |
| Locale | Decimal and thousands separators follow device locale. Digits stay Western Arabic in v1 |

## 7. Monetization

### Recommendation: free app plus one-time "Pro" unlock

| Option | Pros | Cons |
|---|---|---|
| **Free + one-time Pro (recommended)** | Far more installs, users try the look before paying, easy to gather reviews and ratings, can add more Pro later | Needs in-app billing code |
| Paid upfront | Simplest code, no billing flow | Big drop in installs, no try-before-buy for a visual product, harder to rank |
| Free + subscription | Recurring revenue | Feels wrong for a calculator, users resent it |

Important: **a free app cannot later be changed to paid on Google Play**, while a paid app can be made free. If you might ever want a paid version, decide before your first production release. Confirm the current rule in Play Console help when you get there.

### Pricing guidance

- Start with one non-consumable product: `pro_unlock`.
- Choose a base price in USD (for example 2.99 to 4.99) and let Play localize regional prices.
- Consider a small launch discount instead of a permanent low price.

### Prerequisites

- A payments profile linked to Play Console. Google states the payments profile link is permanent, so choose the name and bank details carefully.
- The billing permission must exist in an uploaded build before in-app products can be created, so include the billing dependency in your first closed-test build.

## 8. Success metrics

Because v1 collects no analytics, use the data Play Console already gives you:

| Metric | Source | Early target |
|---|---|---|
| Store listing conversion | Play Console acquisition reports | 25%+ (varies by category) |
| Day-1 and Day-7 retention | Play Console statistics | 25% / 8% |
| Crash-free users | Android vitals | 99%+ |
| ANR rate | Android vitals | Below Google's bad-behavior threshold |
| Rating | Play Console | 4.5+ |
| Pro conversion | Play Console financial reports | 2% to 4% of active users |

If you later add Firebase Crashlytics or Analytics, you must update the Data Safety form and privacy policy first.

## 9. Policy and approval checklist

| Area | Plan |
|---|---|
| Account type | Personal account. Closed test with at least 12 opted-in testers for 14 continuous days before production access (verify the current numbers in Play Console) |
| Category | Tools. Avoid financial-product features that could trigger the Finance declaration |
| Data Safety | "No data collected, no data shared" (true only if you add no analytics, ads, or accounts) |
| Privacy policy | Required. Host a short page (GitHub Pages works) and link it in the listing |
| Target audience | 13+ and adults. Do not select under-13 to avoid the Families Policy |
| Content rating | Complete the questionnaire. Expect "Everyone" |
| Permissions | Vibrate (implicit), Billing. Sensors do not need a runtime prompt on Android. No internet permission needed unless a dependency adds it |
| Target API | Meet the current requirement: Android 16 (API 36) from 31 August 2026 |
| Format | Signed Android App Bundle (.aab) |
| Impersonation | Do not use a name, icon, or screenshot that resembles Google, Apple, Casio, or other calculator brands |
| Fonts and assets | Use only fonts and sounds with licenses that allow bundling in a commercial app (SIL OFL fonts, CC0 sounds, or your own) |

## 10. Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Crowded category | Low discoverability | Lean on visuals: strong first 2 screenshots, a short video, and a distinctive icon |
| 3D effect feels slow on low-end phones | Bad reviews | Layered 2D extrusion (cheap), RepaintBoundary, a "Lite effects" toggle, test on a low-end device |
| Percent behavior surprises users | Trust loss | Follow mainstream behavior, add unit tests, show the interpreted expression |
| 12-tester requirement stalls launch | Weeks of delay | Start recruiting on day one, ship a closed-test build early |
| Low Pro conversion | Little revenue | Show Pro themes as live previews, never lock math |
| Font or asset license problems | Takedown | Keep a LICENSES file, only use OFL or CC0 assets |

## 11. Open questions

1. Final app name and icon direction.
2. Base price for Pro.
3. Will you release the paid-upfront version at all? (This decides free versus paid before launch.)
4. Do you want tilt parallax in v1.0 or as a Pro-only surprise in v1.1?
