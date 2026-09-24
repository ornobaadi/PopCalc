# Design: Pop Calc

Design language: **bold, condensed, tactile.** Huge numerals that feel like physical objects, a calm keypad, and motion that rewards every tap without ever slowing you down.

Reference material: the orange phone mockup, the dark phone mockup, and the hero video (13 seconds, 1280 x 720, 30 fps).

---

## 1. What the references show

| Observation | Design consequence |
|---|---|
| Numerals are ultra-condensed, heavy, and extruded with a visible side wall and soft drop shadow | Use a condensed display face, render depth as stacked layers |
| In the hero video, the same number goes from a thin outline weight to a heavy solid weight | Use a **variable font** and animate the weight axis |
| The expression line sits above the result, small, with orange operators and the active term in white | Two-level hierarchy: expression small, result huge |
| Keypad is minimal: glyphs only, no button boxes | Keys are tap targets with no visible background at rest |
| The phone is tilted in the mockups, which reads as depth | Optional tilt parallax adds the same feeling in-app |
| Only two colors plus one accent per theme | Keep each theme to three or four colors |

## 2. Themes

Colors were sampled from the reference images. Treat them as starting points and tune on a real device.

### Sunny (default light)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#FFA600` | Screen background |
| `bgShade` | `#E29103` | Background gradient shade, extrusion side |
| `ink` | `#1A1410` | Digits, keys |
| `inkSoft` | `#5A3F00` | Secondary text, disabled |
| `accent` | `#E5332A` | Equals key, error highlight |
| `extrudeTop` | `#2B221B` | Result numeral face |
| `extrudeSide` | `#0F0B08` | Result numeral side wall |

### Ink (default dark)

| Token | Hex | Use |
|---|---|---|
| `bg` | `#1C1C1C` | Screen background |
| `bgShade` | `#2D2D2D` | Subtle gradient and panels |
| `ink` | `#E3E3E3` | Digits, keys |
| `inkSoft` | `#7C7C7C` | Clear, backspace, percent, secondary text |
| `accent` | `#F5A800` | Operators, equals |
| `extrudeTop` | `#E3E3E3` | Result numeral face |
| `extrudeSide` | `#8E8E8E` | Result numeral side wall |

### Pro theme ideas

Mint (`#B8F2D0` on `#0E2A22`), Bubblegum (`#FF8FB8` on `#2A0F1B`), Paper (`#F4EFE6` on `#1F1B16` with a subtle grain), Neon (`#39FF88` on `#0A0A0A`), Mono (pure black and white), Sky (`#8CC8FF` on `#0B1B2B`).

**Contrast rule:** body text and key glyphs must reach WCAG AA (4.5:1). Check every theme with a contrast tool before shipping. The result numeral is large text, so 3:1 is the minimum there.

Add a subtle film grain over the background (the dark reference has visible noise). A pre-rendered tileable noise PNG at low opacity is cheap and adds a lot of richness.

## 3. Typography

| Role | Face | Notes |
|---|---|---|
| Result numeral | **Antonio** (variable, weight 100 to 700) | Condensed, heavy, close to the reference. Animate `wght` |
| Expression line | Antonio, weight 500 | Same family keeps it cohesive |
| Keys | Antonio, weight 400 to 500 | |
| Alternates (Pro) | Big Shoulders Display, Bebas Neue, Oswald | Check each license |

Rules:

- Bundle fonts in the app. Do not fetch fonts at runtime with the `google_fonts` package, so the app stays fully offline and no network access is needed.
- All suggested faces are SIL Open Font License. Keep the license text in `assets/licenses/` and in the app's About screen.
- Use **tabular figures** if the face supports them so digits do not jitter as the number changes.
- Minimum expression size: 20 sp. Result numeral: fills available width, auto-shrinks.

## 4. Layout

Portrait only. Three zones, from top to bottom:

```
+--------------------------------+
|  [history]            [theme]  |  Top bar: 48dp, quiet icons
|                                |
|          1,024 + 5%            |  Expression: right-aligned, 24sp
|                                |
|             1,075.2            |  Result: giant, right-aligned,
|                                |  extruded, auto-fit
|                                |
|   C     %     <x     /         |  Keypad: 5 rows x 4 columns
|   7     8     9     x         |  No key backgrounds at rest
|   4     5     6     -         |
|   1     2     3     +         |
|   0     .    +/-    =         |
+--------------------------------+
```

- Result zone takes roughly 45 percent of the height, keypad about 45 percent, top bar the rest.
- Keypad keys are at least 64 x 64 dp with 48 dp minimum touch targets even on small phones.
- Respect system insets (gesture bar, notch). Content stays out of the status and navigation areas.
- Right-align numbers and expression, like a physical calculator.
- History opens as a bottom sheet, not a new screen, so the calculator never loses context.

### Key styling

| Key type | Rest | Pressed |
|---|---|---|
| Digits | `ink` glyph, no background | Circle highlight fades in (12% ink), glyph scales to 0.92 |
| Operators | `accent` glyph | Same, plus glyph glows briefly |
| Utility (C, %, backspace, +/-) | `inkSoft` glyph | Same as digits |
| Equals | `accent` glyph, slightly larger | Fill sweep in accent color, then result animation |

The reference backspace icon is a hexagon with an x. Draw it as a custom icon so it matches the angular character of the numerals.

## 5. The 3D numeral technique

To achieve the tactile, physical look of the reference ((NOT BORING) Calculator), use **layered extrusion with chamfer/bevel edge highlighting**:

1. **Ambient Drop Shadow**: Render the base numeral stack with a Gaussian blur (radius ~12-16dp) offset along the extrusion vector to cast a rich contact shadow on the textured background.
2. **Extrusion Side Walls**: Render the text N times (N = 10 to 16 layers, or 4 in Lite mode). Offset each layer incrementally along an oblique/isometric vector (e.g., +1.0 dp horizontal, +1.2 dp vertical per layer). Shade the side layers gradually from a deep ambient shadow at the base up to `extrudeSide`.
3. **Top Front Face**: Render the front face in `extrudeTop`.
4. **Chamfer / Bevel Highlight**: To capture the sculpted ceramic/molded plastic edge seen in the reference, render an inner chamfer stroke along the glyph perimeter in a crisp highlight tint (`#FFFFFF` with 70% opacity in Ink theme, or warm highlight in Sunny), giving the crisp angled bevel visible on `25%` in the reference.

Implementation notes:

- Build it as a `CustomPainter` (`ExtrudedNumberPainter`) that renders via `TextPainter` and canvas path/shadow operations, wrapped in a `RepaintBoundary`.
- Depth is a single animated value from 0.0 (flat) to 1.0 (full). Layer offsets and shadow spread scale with depth.
- Cache the laid-out `TextPainter` when the text and style do not change.
- Provide a **Lite effects** setting that drops to 4 layers and disables the Gaussian blur for low-end phones.
- Tilt parallax (Pro) adds a small offset vector from the accelerometer, low-pass filtered, to the extrusion direction, capped at about 6 dp.

## 6. Motion

Motion is the product, so give it a system instead of one-off tweens.

### Principles

- **Fast in, soft out.** Input feedback under 100 ms, settling animations 250 to 450 ms.
- **Springs over curves** for anything that feels physical (digit entry, result).
- **One hero moment per action.** Do not animate everything at once.
- **Never block input.** Every animation is interruptible. A new key press retargets the animation.

### Timing tokens

| Token | Value | Use |
|---|---|---|
| `tapFeedback` | 90 ms | Key press highlight |
| `digitIn` | 220 ms spring (stiffness 500, damping 26) | New digit extrudes up |
| `resultMorph` | 420 ms, `easeOutCubic` | Weight and depth on equals |
| `clearCollapse` | 260 ms, `easeInCubic` | Depth to 0 and drop |
| `themeSwap` | 350 ms | Cross-fade plus radial reveal |

### Animation catalog

| Trigger | Animation |
|---|---|
| Digit typed | New digit grows from depth 0 to 1 with a small overshoot. Existing digits nudge left with a spring |
| Operator typed | Operator glyph pops (scale 1.0 to 1.25 to 1.0), expression line tints it |
| Live preview | Preview result fades in at low opacity (60%) in the result zone, weight 200 |
| Equals | Expression slides up and shrinks into the top line. Result morphs from weight 200 to 700 while depth rises. Brief accent glow on the sweep |
| Clear | Digits collapse flat (depth to 0), fall 12 dp, and fade. Then the display resets to `0` |
| Backspace | Last digit retracts (depth to 0), then removes |
| Error | Short horizontal shake (3 cycles, 6 dp) with the soft error haptic |
| Large result | Auto-fit scales smoothly instead of jumping between sizes |
| Theme change | Radial reveal from the tapped icon |
| Idle | After 8 seconds, the numeral does a very subtle depth breathing loop (0.95 to 1.0). Disabled with Reduce Motion |

### Reduce Motion

Read `MediaQuery.disableAnimations`. When on: no springs, no shake, no idle loop, no tilt. Keep instant state changes and a plain fade for the result. The app must remain fully usable and still look good.

## 7. Haptics and sound

| Event | Haptic | Sound (Pro, off by default) |
|---|---|---|
| Digit or operator | `selectionClick` | Soft tick |
| Equals | `mediumImpact` | Low thud plus tone |
| Clear | `lightImpact` | Whoosh |
| Error | `heavyImpact` once, short | Dull knock |

Keep sounds under 200 ms, normalized, and use a low-latency player so there is no audible lag. Respect the device's silent mode.

## 8. Icons and store visuals

### App icon

- A bold, condensed `%` or `=` in the extruded style on a flat orange or dark tile.
- Must read clearly at 48 px. Test it on light and dark launcher backgrounds.
- Provide adaptive icon layers (foreground and background) and a monochrome layer for themed icons.

### Store graphics

| Asset | Plan |
|---|---|
| Screenshots 1 and 2 | Giant extruded result with a short caption ("Math, but fun"). These decide the click |
| Screenshot 3 | Dark theme |
| Screenshot 4 | Theme picker with Pro themes |
| Screenshot 5 | History sheet |
| Promo video | 10 to 15 second screen recording of typing an expression and the result morphing, with no voice-over needed |
| Feature graphic | 1024 x 500, giant `=` or `%` numeral with the app name |

Use real device frames sparingly. Google requires screenshots to represent the app accurately, so do not use mockups that show features the app does not have.

## 9. Accessibility

- Semantics label on every key ("seven", "plus", "equals", "backspace").
- Announce the result on `=` through a live region so TalkBack reads it.
- Support system font scaling up to 200 percent: the keypad grid stays intact, the expression wraps to a second line, and the result auto-fits.
- Do not rely on color alone. Errors also change text and haptics.
- Minimum touch target 48 x 48 dp.
- Test with TalkBack, large font, and Reduce Motion before every release.

## 10. Design QA checklist

- [ ] Every theme passes contrast checks
- [ ] 60 fps on a mid-range device with effects on
- [ ] Lite effects mode is smooth on a low-end device
- [ ] No text clipping at 200% font scale
- [ ] Animations interruptible with rapid tapping
- [ ] Reduce Motion behaves correctly
- [ ] Icon reads at small sizes and in themed-icon mode
- [ ] Screenshots match the real app
