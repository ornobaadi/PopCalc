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

  /// Sunny (exact radiant golden marigold & neon vermilion from Not Boring)
  static const sunnyTheme = ThemeColors(
    bg: Color(0xFFFFAE00), // Vibrant golden marigold
    bgShade: Color(0xFFFFB818), // Subtle radiant highlight
    ink: Color(0xFF140F0B), // Deep espresso black
    inkSoft: Color(0xFF8A5310), // Warm amber brown for utility keys
    accent: Color(0xFFFF331F), // Vivid neon vermilion red for operators and equals
    extrudeTop: Color(0xFF140F0B), // Bold espresso black front face
    extrudeSide: Color(0xFF2B2017), // Rich dark bronze/chocolate side walls
    extrudeShadow: Color(0x77000000), // Deep directional contact shadow
    extrudeChamfer: Color(0xFF3D2E22), // Bevel highlight rim
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
