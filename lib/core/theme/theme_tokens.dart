import 'package:flutter/material.dart';

enum AppThemeMode {
  ink,
  sunny,
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
  });

  /// Sunny (radiant golden marigold & punchy vermilion with high contrast legibility)
  static const sunnyTheme = ThemeColors(
    bg: Color(0xFFFFAE00), // Vibrant golden marigold
    bgShade: Color(0xFFFFB818), // Subtle radiant highlight
    ink: Color(0xFF140F0B), // Deep espresso black for crisp, high-contrast numerals
    inkSoft: Color(0xFF38220A), // Rich dark bronze-espresso (crisp readability on gold)
    accent: Color(0xFFDE2600), // Vivid neon vermilion red for operators and equals
    extrudeTop: Color(0xFF221A12), // Deep warm graphite front face
    extrudeSide: Color(0xFF483220), // Warm dimensional caramel-bronze side walls
    extrudeShadow: Color(0x22361600), // Soft lighter ambient shadow (not a dark muddy blob)
    extrudeChamfer: Color(0xFFFFD685), // Warm radiant golden bevel highlight rim
  );

  /// Ink (tactile dark theme inspired by (NOT BORING) Calculator)
  static const inkTheme = ThemeColors(
    bg: Color(0xFF141414), // Deep slate black
    bgShade: Color(0xFF1F1F1F),
    ink: Color(0xFFEEEEEE), // Crisp white numerals
    inkSoft: Color(0xFF7A7A7A), // Muted grey utility keys
    accent: Color(0xFFFFA000), // Punchy amber orange operators
    extrudeTop: Color(0xFFEDEDED), // Crisp white front face
    extrudeSide: Color(0xFF454545), // Shaded extrusion side walls
    extrudeShadow: Color(0x99000000), // Soft contact shadow
    extrudeChamfer: Color(0xFFFFFFFF), // Crisp chamfer highlight
  );
}
