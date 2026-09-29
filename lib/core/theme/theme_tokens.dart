import 'package:flutter/material.dart';

enum AppThemeMode {
  // Order matters: the index is persisted in SharedPreferences.
  ink,
  sunny,
  bubblegum,
  obsidian,
  synthwave,
  matcha,
  frost,
  velvet,
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
  });

  static ThemeColors of(AppThemeMode mode) => switch (mode) {
        AppThemeMode.ink => inkTheme,
        AppThemeMode.sunny => sunnyTheme,
        AppThemeMode.bubblegum => bubblegumTheme,
        AppThemeMode.obsidian => obsidianTheme,
        AppThemeMode.synthwave => synthwaveTheme,
        AppThemeMode.matcha => matchaTheme,
        AppThemeMode.frost => frostTheme,
        AppThemeMode.velvet => velvetTheme,
      };

  /// Marigold (radiant golden marigold & punchy vermilion with high contrast legibility)
  static const sunnyTheme = ThemeColors(
    bg: Color(0xFFFFAE00), // Vibrant golden marigold
    bgShade: Color(0xFFFFB818), // Subtle radiant highlight
    ink: Color(0xFF140F0B), // Deep espresso black for crisp, high-contrast numerals
    inkSoft: Color(0xFF2E1C0A), // Rich dark bronze-espresso (crisp readability on gold)
    accent: Color(0xFFD61800), // Vivid punchy vermilion red for operators and equals
    extrudeTop: Color(0xFF221A12), // Deep warm graphite front face
    extrudeSide: Color(0xFF483220), // Solid warm dimensional caramel-bronze block
    extrudeShadow: Color(0x35000000), // Soft ambient contact shadow
    extrudeChamfer: Color(0xFFFFDF88), // Barely-visible cool white rim — not a border, just a catch light
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

  /// Bubblegum (neo-pop / Memphis-inspired: bubblegum pink canvas, clay-like
  /// violet extrusion, electric cobalt operators). Contrast: ink on bg ~9:1,
  /// accent on bg ~4.5:1.
  static const bubblegumTheme = ThemeColors(
    bg: Color(0xFFFF8FC7), // Sweet bubblegum pink
    bgShade: Color(0xFFFF9FD0), // Soft sugar highlight
    ink: Color(0xFF1E0F3D), // Midnight grape numerals
    inkSoft: Color(0xFF4A1F5E), // Plum utility keys
    accent: Color(0xFF2D1FD6), // Electric cobalt operators and equals
    extrudeTop: Color(0xFF24124A), // Deep grape front face
    extrudeSide: Color(0xFF7B3FB8), // Juicy violet clay block
    extrudeShadow: Color(0x40470A3A), // Berry-tinted contact shadow
    extrudeChamfer: Color(0xFFFFD6EC), // Sugar-glaze catch light
    burst: Color(0xFFFFF36B), // Lemon pop celebration lines
    isDark: false,
  );

  /// Obsidian (black lacquer and brushed gold, luxury-watch feel)
  static const obsidianTheme = ThemeColors(
    bg: Color(0xFF0B0B0C), // Black lacquer
    bgShade: Color(0xFF161512),
    ink: Color(0xFFF1D48A), // Brushed gold numerals
    inkSoft: Color(0xFF8C7A52), // Aged brass utility keys
    accent: Color(0xFFE8C877), // Champagne operators and equals
    extrudeTop: Color(0xFFF1D48A), // Gold front face
    extrudeSide: Color(0xFF6B4E17), // Deep bronze block
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0x80FFF3D0), // Polished gold catch light
    burst: Color(0xFFF1D48A),
    isDark: true,
  );

  /// Synthwave (retro-80s neon night drive)
  static const synthwaveTheme = ThemeColors(
    bg: Color(0xFF120A2A), // Midnight violet
    bgShade: Color(0xFF1C1238),
    ink: Color(0xFFF5F2FF), // Neon-white numerals
    inkSoft: Color(0xFF9A8CC8), // Dusk lavender utility keys
    accent: Color(0xFF00E5FF), // Electric cyan operators and equals
    extrudeTop: Color(0xFFF5F2FF),
    extrudeSide: Color(0xFFFF2E88), // Hot-magenta glowing block
    extrudeShadow: Color(0x99000000),
    extrudeChamfer: Color(0x80FFB3D9), // Pink neon rim
    burst: Color(0xFF00E5FF),
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
