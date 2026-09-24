# Phases: Pop Calc

A build order designed around one fact: **a new personal Play account needs a closed test with at least 12 opted-in testers for 14 continuous days before you can apply for production.** So the plan gets a feature-complete free build into closed testing as early as possible, then builds Pro while the 14-day clock runs.

Estimates assume solo, part-time work (about 10 to 15 hours per week). Adjust to your pace.

```
Week 1     Week 2     Week 3     Week 4     Week 5     Week 6     Week 7
[P0][--P1--][---P2---][--P3--][P4]
                          [ closed test starts ~ end of week 4 ........14 days........ ]
                                    [------ P5 Pro / IAP ------]
                                                              [-P6 listing-][P7 launch]
```

---

## Phase 0: Setup (Completed)

**Goal:** a clean project and a clear identity.

- [x] Decide app name: Pop Calc (working title for Not Boring Calculator style app).
- [x] Create project and clean architecture folder structure (`lib/core/...`, `lib/features/...`, `assets/...`).
- [x] Add dependencies: `flutter_riverpod`, `decimal`, `rational`, `shared_preferences`, `path_provider`.
- [x] Bundle Antonio variable font (`assets/fonts/Antonio-VariableFont_wght.ttf`) and OFL license.
- [x] Generate tactile noise texture asset (`assets/textures/noise.png`).
- [x] Configure Android manifest: lock portrait orientation (`android:screenOrientation="portrait"`), add `VIBRATE` permission.
- [ ] Draft one-page privacy policy (before closed test).
- [ ] Upload keystore for Play publishing (before closed test).

**Exit criteria:** project builds cleanly, assets are bundled, clean architecture scaffolded. Status: **DONE**.

---

## Phase 1: Math engine (Completed)

**Goal:** a correct calculator with no UI polish.

- [x] Token, expression, parser, evaluator, formatter in `core/engine`.
- [x] Percent semantics exactly as in the PRD (`1,024 + 5% = 1,075.2`, `255 + 5% = 267.75`, `200 - 15% = 170`, `80 x 25% = 20`, `50 / 25% = 200`, `12% = 0.12`).
- [x] Editing rules: operator replacement, leading zeros, single decimal, backspace, clear, sign toggle.
- [x] Error handling: divide by zero, limits.
- [x] Unit tests for every row of the test plan in `architecture.md` section 3.5 (21/21 tests passing).
- [x] `CalculatorController` with state and live preview, verified with tests.

**Exit criteria:** all engine tests pass. No Flutter imports in `core/engine`. Status: **DONE**.

---

## Phase 2: Static UI (Completed)

**Goal:** it looks right when standing still.

- [x] Theme tokens for Sunny and Ink, `ThemeData` wiring, system theme option (`theme_tokens.dart`, `app_theme.dart`).
- [x] Calculator screen layout: top bar, expression line, result zone, keypad (`calculator_screen.dart`).
- [x] Key buttons with glyph-only style and tactile press highlight (`key_button.dart`).
- [x] Custom backspace icon matching the angular reference badge (`backspace_icon.dart`).
- [x] Auto-fit result text in `ExtrudedNumberPainter`.
- [x] Right alignment, insets, small-screen and large-font behavior.
- [x] Film grain overlay (`grain_overlay.dart`).
- [x] `ExtrudedNumber` painter with 3D layered extrusion, contact shadow, and chamfer bevel rim highlight.

**Exit criteria:** side by side with the reference images, the static screens look right in both themes, 27/27 unit & widget tests passing. Status: **DONE**.

---

## Phase 3: Motion (Completed)

**Goal:** the part that sells the app.

- [x] `AnimatedExtrudedNumber` (`numeral_animator.dart`) with depth spring, scale punch, error shake, and idle breathing loop.
- [x] Digit-in scale punch and physical depth spring overshoot.
- [x] Equals depth rise and tactile response.
- [x] Error shake with decaying oscillation amplitude.
- [x] Idle breathing loop (subtle 4-second oscillation).
- [x] Lite effects mode toggle support.
- [x] Smooth interruption: new keystroke instantly retargets controllers without freeze or glitch.

**Exit criteria:** 60 fps, tactile physical feel, instant interruptibility. Status: **DONE**.

---

## Phase 4: Free feature completion and closed-test build

**Goal:** a complete free app ready for testers.

- [x] Haptics on all key events (selection clicks on digits, impact on equals, haptic feedback).
- [x] History store: persistent JSON Lines store (`history_store.dart`), bottom sheet (`history_sheet.dart`), tap to reuse, swipe to delete, cap at 50.
- [x] Copy result on long press with clipboard toast and tactile haptic feedback.
- [x] Responsive layout with centered phone frame on web/desktop.
- [x] Accessibility pass: Semantics labels on all keys, TalkBack labels.
- [ ] Add `in_app_purchase` dependency for Play Billing.
- [ ] App icon (adaptive plus monochrome).
- [ ] Release build test with R8 on.
- [ ] Upload signed AAB to Closed testing track.

### Recruit testers starting day one, not now

Start recruiting testers in Phase 0. You need at least 12 people who actually opt in and stay opted in for 14 days, and Google looks at real engagement. Good sources: friends, family, classmates, former colleagues, developer communities, and tester-exchange groups. Aim for 15 to 20 to leave a safety margin. Send each person the opt-in link, remind them to use the app a few times, and check the opted-in count every couple of days. If the count drops below the required number, the clock can reset.

---

## Phase 5: Pro and in-app purchase (7 to 10 days, runs during the 14-day test)

**Goal:** the paid layer, built while the test clock runs.

- [ ] Set up a merchant (payments) profile. It links permanently to your developer account, so double-check names and bank details.
- [ ] Create the `pro_unlock` one-time product and set the base price.
- [ ] Add license testers.
- [ ] Implement `PurchaseService` (Play and Fake), `ProController`, and the paywall sheet.
- [ ] Handle purchased, pending, canceled, error, and restore.
- [ ] Pro content: 6 to 8 extra themes, accent picker, unlimited history and search, alternate fonts.
- [ ] Sounds and tilt parallax if time allows (both can slip to v1.1).
- [ ] Theme preview for locked themes (5 second try).
- [ ] Test on a Play track: buy, cancel, pending, refund, reinstall, restore.
- [ ] Ship as an update to the closed test track. Ask testers to try the purchase flow with license-tester accounts.

**Exit criteria:** a Pro purchase completes, unlocks instantly, survives reinstall through Restore, and no math feature is locked.

---

## Phase 6: Store listing (3 to 4 days, overlaps with the end of the test)

**Goal:** a listing that converts.

- [ ] App name and short description (80 chars), long description with natural keywords, no keyword stuffing.
- [ ] Icon, feature graphic (1024 x 500), 4 to 8 screenshots, promo video.
- [ ] Screenshots 1 and 2 are the giant extruded result. They decide the click.
- [ ] Verify every screenshot matches the real app.
- [ ] Localize the listing into a few high-value languages (Spanish, Portuguese, German, French, Hindi, Arabic, Indonesian, Japanese) using careful translations, and localize the app strings with `intl` if you add them.
- [ ] Set up pricing and countries. Start with all available regions.
- [ ] Final policy review: Data Safety matches reality, no misleading claims, no brand impersonation.

**Exit criteria:** the listing is complete and the Play Console dashboard shows no policy warnings.

---

## Phase 7: Production access and launch (about 1 week after the 14 days)

**Goal:** go live.

- [ ] Confirm the dashboard shows the tester requirement as met.
- [ ] Apply for production access and answer the questionnaire honestly: how you recruited testers, what feedback you got, what you changed.
- [ ] Wait for the review (Google gives an estimate on the dashboard). Do not upload new builds carelessly while waiting.
- [ ] Create the production release from your tested build and submit.
- [ ] Prepare launch posts: a short screen-recording clip, a Reddit or community post where self-promotion is allowed, Product Hunt, and your portfolio.
- [ ] Ask early users for a rating using the in-app review API after a positive moment (not on first launch), at most once in a while.

**Exit criteria:** the app is live on Google Play.

---

## Phase 8: After launch (ongoing)

| Timeframe | Focus |
|---|---|
| Week 1 | Watch Android vitals (crashes, ANRs), read every review, answer quickly, hotfix anything serious |
| Weeks 2 to 4 | Small updates: fixes, a new free theme, a limited-time Pro discount |
| Month 2 to 3 | v1.1 candidates: widget, tip and split helper, unit converter, sounds and tilt if not shipped yet |
| Later | Tablet layouts, iOS release, seasonal themes, localization for the app UI |

Track: listing conversion, retention, crash-free rate, rating, Pro conversion. Change one thing at a time so you know what worked.

---

## Milestone summary

| Milestone | Target |
|---|---|
| M1: Engine passes all tests | End of week 1 |
| M2: Static UI matches references | Middle of week 2 to 3 |
| M3: Motion feels great on device | End of week 3 to 4 |
| M4: Closed test live | End of week 4 |
| M5: Pro purchase works | Middle of the 14-day window |
| M6: Listing complete | End of the 14-day window |
| M7: Production access granted and launch | About week 7 to 8 |

## Risk register for the schedule

| Risk | Likelihood | Response |
|---|---|---|
| Not enough testers stay opted in | Medium | Recruit 15 to 20, check counts every 2 to 3 days, keep a reserve list |
| Animation performance problems | Medium | Lite mode, fewer layers, profile early in Phase 3 |
| Billing setup delays (merchant profile, verification) | Medium | Start the merchant profile during Phase 4, not Phase 5 |
| Production review takes longer than expected | Medium | Keep the listing and policies clean the first time, avoid last-minute changes |
| Scope creep | High | Anything not in the PRD MVP goes to the v1.1 list |

## Definition of done for v1.0

- [ ] All MVP features in the PRD work
- [ ] Engine tests pass, including every percent example
- [ ] 60 fps on a mid-range device, smooth in Lite mode on a low-end device
- [ ] Both themes and all Pro themes pass contrast checks
- [ ] TalkBack, large font, and Reduce Motion verified
- [ ] Pro purchase and restore verified on a real Play track
- [ ] Data Safety and privacy policy match the shipped app
- [ ] Listing assets match the real app
- [ ] Crash-free rate above 99 percent during closed testing
