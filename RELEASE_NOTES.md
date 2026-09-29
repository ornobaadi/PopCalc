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
