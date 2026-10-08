# PopCalc v1.2.1 (build 6) — Currency, landscape & a clearer swap key

## ✨ What's new

### 💱 Currency converter
- A new **Currency** tab in the unit converter, with 33 currencies
- **Works with no connection:** exchange rates are built into the app
- Tap **Update** to fetch today's rates. That is the only time the app goes online, and it shows the date of the rates it is using
- Rates are indicative, rounded like money, and not meant for transactions

### 🔄 Scientific mode
- **Turn your phone sideways** in scientific mode to see every function at once, next to the keypad: no second layer to switch to
- The **2nd** key is now a **⇄ swap** icon, so it is clearer that it shows more functions

### 🔐 Permissions
- PopCalc now asks for the **internet permission**, used only for the currency Update button. Nothing about you is sent

---

### Play Store "What's new" (under 500 chars)
```
New in 1.2.1:
• Currency converter: 33 currencies, works offline with built-in rates. Tap Update for today's rates
• Scientific mode in landscape: every function at once
• The 2nd key is now a clearer swap icon
• Internet permission added, used only when you tap Update for currency rates
```

---

# PopCalc v1.2.0 (build 5) — Scientific & Converter

## ✨ What's new

### 🧮 Scientific calculator
- Turn on **Scientific & Converter** in Settings to get an **f(x)** button in the top bar. It switches between simple and scientific keys in one tap
- Powers (xʸ, x²), roots (√, ∛), brackets, π, e and factorial
- sin, cos, tan and their inverses, ln, log, eˣ and 10ˣ, with **2nd** to flip keys to their inverse
- **DEG/RAD** badge on the display. In degrees, sin 180 is exactly 0 and tan 90 shows "Not defined"
- Smart input: brackets close themselves on `=`, and `2π` or `2(3)` multiply automatically
- Exact answers for everyday maths. Trig and logs are accurate to 15 digits
- The second row of keys folds away with the handle when you want more room for the answer
- Every kind of key has its own sound and feel: trig waves, logs settle, powers climb, roots step down, brackets open and close, constants sparkle

### 📏 Unit converter
- A **ruler** button in the top bar opens a clean, dedicated converter screen
- 10 categories: length, weight, temperature, volume, area, speed, time, data, pressure and energy
- Exact conversion factors, a one-unit reference line, swap, ANS (bring in your last answer) and copy
- **Swipe like a slider:** swipe the category strip or a unit row up and down to click through notches, with a mechanical tick and vibration
- Remembers your last category and units

### 🔊 Sound & haptics
- New launch sound: the Typewriter "skrr", whichever sound pack you use
- Sound stays where it matters: keys, answers and converter notches. Toggles and settings are haptics only
- Scientific and converter haptics are as firm as the main keypad
- **Stronger haptics on phones with weaker vibration motors**, while phones that already felt good stay about the same

---

### Play Store "What's new" (under 500 chars)
```
New in 1.2.0: Scientific & Converter
• Turn it on in Settings: f(x) and ruler buttons appear in the top bar
• Scientific keys: powers, roots, brackets, trig (DEG/RAD), logs, π, e, n!
• Unit converter: 10 categories, exact factors, swipe through units like a slider
• New launch sound and calmer, more focused sound design
• Stronger haptics on phones with weak vibration
```

---

# PopCalc v1.1.1 (build 4) — Theme update & bug fixes

## 🎨 New skins
- **Six new skins**: **Obsidian** (black lacquer & gold), **Synthwave** (retro neon), **Matcha** (sage paper & terracotta), **Frost** (Nordic ice), **Velvet** (wine & rose gold) and **Peony** (blush & rose quartz)
- The sunny yellow skin is now called **Marigold**, and the dark skin is now **Charcoal**
- Skin picker tiles now preview each skin's numerals and accent colour
- Status bar icons now switch between light and dark to stay readable on every skin
- Pro skins are **free for everyone** during launch

## 🐞 Bug fixes
- Fixed `=` doing nothing after editing a number in a finished calculation — edits now recalculate instantly
- Fixed the answer disappearing after tapping a number and tapping away
- Fixed typing after an edit creating a separate number instead of extending it
- Fixed operators doubling up (e.g. `10 + × 11`) when changing an operator via a highlighted number
- Deleting a number now removes its operator too; deleting an operator joins the numbers around it
- `%` can no longer replace an operator or be added twice

---

### Play Store "What's new" (under 500 chars)
```
New in 1.1.1 — Theme update & bug fixes:
• 6 new skins: Obsidian, Synthwave, Matcha, Frost, Velvet & Peony
• Marigold & Charcoal skins renamed, new skin previews
• Status bar adapts to light and dark skins
• Fixed = not updating after editing a number
• Smoother editing: no doubled operators, no lost answers, cleaner deletes
```

---

# PopCalc v1.1.0 (build 3)

## ✨ What's new

### 🔊 Sound effects
- Brand-new tap sounds with **three sound packs**: **Pop**, **Mellow** and **Typewriter**
- Number keys play a little pentatonic melody as you type
- Subtle stereo panning based on where you tap, plus a satisfying wind-down on backspace
- A fun launch "skrrr" on the splash screen
- Sounds play on the media stream and won't pause your music

### 📳 Haptics update
- Rebuilt haptics using native Android vibration for crisper, richer feedback
- Unique vibration patterns per key type, matched to the sounds
- Uses composed haptic primitives on Android 11+, with a smooth fallback on older devices
- New **haptic strength** slider

### 🎉 Typing & answer animations
- Numbers now type up and drop into place as you enter them
- A speed-line burst and pop celebration when your answer lands
- Larger expression line that always keeps the newest input in view

### ⚙️ Settings
- Sound on/off toggle, volume control, and sound pack picker with instant previews
- Haptic strength control
- Settings sheet now scrolls on smaller screens

## 🐞 Bug fixes
- Fixed "Infinity" showing on very large results
- Fixed wrong answers after editing malformed expressions
- Fixed `+/-` and `%` behaving incorrectly right after `=`
- Fixed rounding/truncation issues and `-0` results
- Fixed duplicate results when pressing `=` repeatedly
- Fixed digit limit not applying when editing a number
- Fixed restoring scientific-notation numbers from history
- History file size is now capped

---

### Play Store "What's new" (under 500 chars)
```
New in 1.1.0:
• Sound effects with 3 packs: Pop, Mellow & Typewriter
• Richer native haptics with adjustable strength
• Typing animation & answer celebration
• Volume, sound pack & haptic settings
• Fixed Infinity on huge results, +/- and % after =, rounding & -0, repeated =, history restore
```
