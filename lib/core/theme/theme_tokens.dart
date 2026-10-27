import 'package:flutter/material.dart';

enum AppThemeMode {
  // Order matters: the index is persisted in SharedPreferences.
  ink,
  sunny,
  // Third free skin. Took over from Peony (and Bubblegum before it) and
  // keeps the index, so anyone who had those saved lands here.
  blueprint,
  obsidian, // retired, slot kept
  synthwave, // retired, slot kept
  matcha,
  frost,
  velvet,
  // Materials: look, sound and haptics sold as one set (see skin_catalog).
  clay, // retired, slot kept
  chrome,
  glass,
  wood,
  candy, // retired, slot kept
  neon,
  mechanical,
  // Secret: found, not bought (see kSecretSkins in skin_catalog).
  newsprint,
  // Limited drops: materials sold only for a while (see kDrops).
  mirage,
  reckoning,
}

/// Skins that were sold once and are gone. Their [AppThemeMode] slots stay
/// (the index is saved); anyone who had one saved is moved to Marigold.
const kRetiredThemes = {
  AppThemeMode.obsidian,
  AppThemeMode.synthwave,
  AppThemeMode.clay,
  AppThemeMode.candy,
};

/// Surface treatment of the 3D numerals (and, for keycaps, the keys).
/// Only materials use anything but [standard].
enum SkinFinish {
  standard,
  mirror, // chrome: sky-and-horizon reflection
  glass, // frosted, brightest at the top edge
  grain, // wood grain bands
  glow, // neon tube with a halo
  keycap, // plain numerals, keys drawn as keycaps
  wireframe, // hollow line-drawn blocks over a drafting grid
  halftone, // printed dots across the face
  dune, // wind ripples in sunlit sand (Mirage)
  doom, // cold iron cracked with green light (Reckoning)
}

class ThemeColors {
  final Color bg;
  final Color bgShade;
  final Color ink;
  final Color inkSoft;
  final Color accent;
  final Color extrudeTop;
  final Color extrudeSide;
  final Color extrudeShadow;
  final Color extrudeChamfer;
  final Color burst; // answer celebration speed-lines
  final bool isDark;
  final SkinFinish finish;

  const ThemeColors({
    required this.bg,
    required this.bgShade,
    required this.ink,
    required this.inkSoft,
    required this.accent,
    required this.extrudeTop,
    required this.extrudeSide,
    required this.extrudeShadow,
    required this.extrudeChamfer,
    required this.burst,
    required this.isDark,
    this.finish = SkinFinish.standard,
  });

  static ThemeColors of(AppThemeMode mode) => switch (mode) {
    // Retired skins keep their enum slot (the index is saved) but look like
    // Marigold, in case a saved choice survives somewhere.
    AppThemeMode.ink => inkTheme,
    AppThemeMode.sunny ||
    AppThemeMode.obsidian ||
    AppThemeMode.synthwave ||
    AppThemeMode.clay ||
    AppThemeMode.candy => sunnyTheme,
    AppThemeMode.blueprint => blueprintTheme,
    AppThemeMode.matcha => matchaTheme,
    AppThemeMode.frost => frostTheme,
    AppThemeMode.velvet => velvetTheme,
    AppThemeMode.chrome => chromeTheme,
    AppThemeMode.glass => glassTheme,
    AppThemeMode.wood => woodTheme,
    AppThemeMode.neon => neonTheme,
    AppThemeMode.mechanical => mechanicalTheme,
    AppThemeMode.newsprint => newsprintTheme,
    AppThemeMode.mirage => mirageTheme,
    AppThemeMode.reckoning => reckoningTheme,
  };

  /// Mirage (a low sun over dark dunes, pale sand lit orange, spice blue)
  static const mirageTheme = ThemeColors(
    bg: Color(0xFF1F0D04), // Shadow side of the dunes
    bgShade: Color(0xFFC2511A), // The sky the sun left behind
    ink: Color(0xFFFFE8C2),
    inkSoft: Color(0xFFD29A62),
    accent: Color(0xFF4A9BFF), // Spice-blue operators and equals
    extrudeTop: Color(0xFFF7E4B8), // Sunlit sand
    extrudeSide: Color(0xFF9A3D14),
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0xCCFFF1D0),
    burst: Color(0xFFFFB35C),
    isDark: true,
    finish: SkinFinish.dune,
  );

  /// Reckoning (grey iron, cracked with green light, on a stopped clock)
  static const reckoningTheme = ThemeColors(
    bg: Color(0xFF030705), // The dark before it
    bgShade: Color(0xFF123324),
    ink: Color(0xFFDCE8E0),
    inkSoft: Color(0xFF6A8173),
    accent: Color(0xFF2FE274), // Doom-green energy
    extrudeTop: Color(0xFF8C9993), // Cold iron
    extrudeSide: Color(0xFF16301F),
    extrudeShadow: Color(0xCC000000),
    extrudeChamfer: Color(0xB32FE274),
    burst: Color(0xFF2FE274),
    isDark: true,
    finish: SkinFinish.doom,
  );

  /// Blueprint (cyanotype paper, the numerals as hollow line drawings)
  static const blueprintTheme = ThemeColors(
    bg: Color(0xFF0B3C8C),
    bgShade: Color(0xFF124CA6),
    ink: Color(0xFFEAF2FF),
    inkSoft: Color(0xFF8FB0E0),
    accent: Color(0xFFFFD23F), // Marker yellow operators and equals
    extrudeTop: Color(0xFF0B3C8C), // Hollow: the paper shows through
    extrudeSide: Color(0xFF0A2F6E),
    extrudeShadow: Color(0x66001A40),
    extrudeChamfer: Color(0xFFFFFFFF), // The drawn line
    burst: Color(0xFFFFFFFF),
    isDark: true,
    finish: SkinFinish.wireframe,
  );

  /// Newsprint, the secret skin (ink on paper, halftone dots, a red stamp for operators)
  static const newsprintTheme = ThemeColors(
    bg: Color(0xFFEFE9DC),
    bgShade: Color(0xFFF6F1E7),
    ink: Color(0xFF141414),
    inkSoft: Color(0xFF6B665C),
    accent: Color(0xFFC1121F),
    extrudeTop: Color(0xFF141414),
    extrudeSide: Color(0xFF8C877C),
    extrudeShadow: Color(0x33000000),
    extrudeChamfer: Color(0xFFF6F1E7),
    burst: Color(0xFFC1121F),
    isDark: false,
    finish: SkinFinish.halftone,
  );

  // ─── Materials ─────────────────────────────────────────────────────────────


  /// Chrome (polished steel on a dark bench, mirror finish)
  static const chromeTheme = ThemeColors(
    bg: Color(0xFF16181C), // Dark steel
    bgShade: Color(0xFF22262C),
    ink: Color(0xFFE6EAF0),
    inkSoft: Color(0xFF8A93A0),
    accent: Color(0xFF7FD4FF), // Ice-blue operators and equals
    extrudeTop: Color(0xFFDDE3EA),
    extrudeSide: Color(0xFF5B6470),
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0xCCFFFFFF),
    burst: Color(0xFFFFFFFF),
    isDark: true,
    finish: SkinFinish.mirror,
  );

  /// Glass (frosted aqua, bright along the top edge)
  static const glassTheme = ThemeColors(
    bg: Color(0xFFCFE6EA), // Aqua mist
    bgShade: Color(0xFFDDF0F3),
    ink: Color(0xFF14384A),
    inkSoft: Color(0xFF4F7C8C),
    accent: Color(0xFF0B7F96), // Deep teal operators and equals
    extrudeTop: Color(0xFFA9DDE8), // Pale aqua pane
    extrudeSide: Color(0xFF5FA9BB),
    extrudeShadow: Color(0x3314384A),
    extrudeChamfer: Color(0xFFFFFFFF),
    burst: Color(0xFFFFFFFF),
    isDark: false,
    finish: SkinFinish.glass,
  );

  /// Wood (oak numerals on dark walnut, with grain)
  static const woodTheme = ThemeColors(
    bg: Color(0xFF2B1D14), // Walnut
    bgShade: Color(0xFF362519),
    ink: Color(0xFFF0DFC4),
    inkSoft: Color(0xFFA98F6F),
    accent: Color(0xFFE2A04A), // Honey operators and equals
    extrudeTop: Color(0xFFC98F52), // Oak face
    extrudeSide: Color(0xFF6E4424),
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0x66FFE2B8),
    burst: Color(0xFFE2A04A),
    isDark: true,
    finish: SkinFinish.grain,
  );


  /// Neon (a green tube sign on a night wall, glowing)
  static const neonTheme = ThemeColors(
    bg: Color(0xFF07070C), // Night wall
    bgShade: Color(0xFF10101A),
    ink: Color(0xFFE9FFF4),
    inkSoft: Color(0xFF5E7A70),
    accent: Color(0xFFFF2BD1), // Magenta operators and equals
    extrudeTop: Color(0xFF39FF9E), // Lit tube
    extrudeSide: Color(0xFF0B5F3A),
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0xCCFFFFFF),
    burst: Color(0xFF39FF9E),
    isDark: true,
    finish: SkinFinish.glow,
  );

  /// Mechanical (cream keycaps on a dark board, orange accents)
  static const mechanicalTheme = ThemeColors(
    bg: Color(0xFF2C2F36), // Keyboard case
    bgShade: Color(0xFF383C45),
    ink: Color(0xFFE8E4DA), // Cream legends
    inkSoft: Color(0xFF9AA0AA),
    accent: Color(0xFFFF7A1A), // Orange accent keys
    extrudeTop: Color(0xFFEDE8DC), // Cream keycap
    extrudeSide: Color(0xFF8E8A80),
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0x66FFFFFF),
    burst: Color(0xFFFF7A1A),
    isDark: true,
    finish: SkinFinish.keycap,
  );

  /// Marigold (radiant golden marigold & punchy vermilion with high contrast legibility)
  static const sunnyTheme = ThemeColors(
    bg: Color(0xFFFFAE00), // Vibrant golden marigold
    bgShade: Color(0xFFFFB818), // Subtle radiant highlight
    ink: Color(
      0xFF140F0B,
    ), // Deep espresso black for crisp, high-contrast numerals
    inkSoft: Color(
      0xFF2E1C0A,
    ), // Rich dark bronze-espresso (crisp readability on gold)
    accent: Color(
      0xFFD61800,
    ), // Vivid punchy vermilion red for operators and equals
    extrudeTop: Color(0xFF221A12), // Deep warm charcoal front face
    extrudeSide: Color(
      0xFF483220,
    ), // Solid warm dimensional caramel-bronze block
    extrudeShadow: Color(0x35000000), // Soft ambient contact shadow
    extrudeChamfer: Color(
      0xFFFFDF88,
    ), // Barely-visible cool white rim — not a border, just a catch light
    burst: Color(0xFFFFFFFF),
    isDark: false,
  );

  /// Ink (tactile dark theme inspired by (NOT BORING) Calculator)
  static const inkTheme = ThemeColors(
    bg: Color(0xFF141414), // Deep slate black
    bgShade: Color(0xFF1F1F1F),
    ink: Color(0xFFEEEEEE), // Crisp white numerals
    inkSoft: Color(0xFF7A7A7A), // Muted grey utility keys
    accent: Color(0xFFFFA000), // Punchy amber orange operators
    extrudeTop: Color(0xFFFFFFFF), // Crisp pure white front face
    extrudeSide: Color(0xFF3C3C3C), // Solid slate grey block
    extrudeShadow: Color(0x99000000), // Soft contact shadow
    extrudeChamfer: Color(0x50FFFFFF), // Subtle crisp bevel highlight rim
    burst: Color(0xFFFFA000),
    isDark: true,
  );



  /// Matcha (calm Japanese paper: sage, sumi ink, terracotta seal)
  static const matchaTheme = ThemeColors(
    bg: Color(0xFFDDE4D0), // Sage paper
    bgShade: Color(0xFFE5EBDA),
    ink: Color(0xFF1F2A1C), // Sumi ink numerals
    inkSoft: Color(0xFF55664C), // Moss grey utility keys
    accent: Color(0xFFA8431F), // Terracotta seal operators and equals
    extrudeTop: Color(0xFF1F2A1C),
    extrudeSide: Color(0xFF7C9468), // Moss block
    extrudeShadow: Color(0x40000000),
    extrudeChamfer: Color(0xFFF3F6EC), // Rice-paper catch light
    burst: Color(0xFFFFFFFF),
    isDark: false,
  );

  /// Frost (Nordic ice: glacier blue, navy numerals, signal orange)
  static const frostTheme = ThemeColors(
    bg: Color(0xFFE8EFF5), // Icy morning
    bgShade: Color(0xFFF0F5F9),
    ink: Color(0xFF0F2A44), // Deep navy numerals
    inkSoft: Color(0xFF4F6A84), // Slate utility keys
    accent: Color(0xFFBF360C), // Signal orange operators and equals
    extrudeTop: Color(0xFF0F2A44),
    extrudeSide: Color(0xFF8DB3D3), // Glacier block
    extrudeShadow: Color(0x400F2A44), // Cool navy-tinted shadow
    extrudeChamfer: Color(0xFFFFFFFF), // Frost glint
    burst: Color(0xFFFF5A36),
    isDark: false,
  );

  /// Velvet (deep wine velvet, cream numerals, rose-gold trim)
  static const velvetTheme = ThemeColors(
    bg: Color(0xFF3A0A1B), // Wine velvet
    bgShade: Color(0xFF461226),
    ink: Color(0xFFF7E7CE), // Cream numerals
    inkSoft: Color(0xFFB88A8F), // Dusty rose utility keys
    accent: Color(0xFFE8A87C), // Rose-gold operators and equals
    extrudeTop: Color(0xFFF7E7CE),
    extrudeSide: Color(0xFF8E1F3E), // Wine block
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0x80FFE0C8), // Rose-gold rim
    burst: Color(0xFFE8A87C),
    isDark: true,
  );
}
