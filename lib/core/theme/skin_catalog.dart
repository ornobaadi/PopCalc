import 'theme_tokens.dart';

/// When false every skin counts as owned ("free during launch").
///
/// Keep this false in any release until real billing exists: the only
/// purchase service today is [FakePurchaseService], which grants for free.
const bool kPremiumLocked = true;

/// Product id of the bundle that unlocks every premium skin.
const String kAllThemesProductId = 'themes_all';

/// A skin as it is presented and sold in the skin store.
class SkinInfo {
  final AppThemeMode mode;
  final String label;
  final String tagline;
  final String description;
  final String modelCode; // short catalogue tag shown beside the price
  final String? productId; // null for free skins

  const SkinInfo({
    required this.mode,
    required this.label,
    required this.tagline,
    required this.description,
    required this.modelCode,
    this.productId,
  });

  bool get premium => productId != null;
  ThemeColors get colors => ThemeColors.of(mode);
}

const kSkins = <SkinInfo>[
  SkinInfo(
    mode: AppThemeMode.sunny,
    label: 'MARIGOLD',
    tagline: 'Golden hour, all day.',
    description:
        'Radiant marigold with espresso numerals and a vermilion kick.',
    modelCode: 'MG-01',
  ),
  SkinInfo(
    mode: AppThemeMode.ink,
    label: 'CHARCOAL',
    tagline: 'Quiet, sharp, classic.',
    description: 'Slate black with crisp white numerals and amber operators.',
    modelCode: 'CH-02',
  ),
  SkinInfo(
    mode: AppThemeMode.peony,
    label: 'PEONY',
    tagline: 'Soft petals, bold sums.',
    description: 'Blush paper, mulberry numerals and a rose-quartz block.',
    modelCode: 'PN-03',
  ),
  SkinInfo(
    mode: AppThemeMode.obsidian,
    label: 'OBSIDIAN',
    tagline: 'Black lacquer, brushed gold.',
    description: 'A luxury-watch face for your numbers. Gold on deep black.',
    modelCode: 'OBS-04',
    productId: 'theme_obsidian',
  ),
  SkinInfo(
    mode: AppThemeMode.synthwave,
    label: 'SYNTHWAVE',
    tagline: 'Neon night drive.',
    description: 'Midnight violet, electric cyan and a hot-magenta glow.',
    modelCode: 'SYN-05',
    productId: 'theme_synthwave',
  ),
  SkinInfo(
    mode: AppThemeMode.matcha,
    label: 'MATCHA',
    tagline: 'Calm as a tea house.',
    description: 'Sage paper, sumi ink numerals and a terracotta seal.',
    modelCode: 'MAT-06',
    productId: 'theme_matcha',
  ),
  SkinInfo(
    mode: AppThemeMode.frost,
    label: 'FROST',
    tagline: 'Nordic ice, signal orange.',
    description: 'Glacier blue with deep navy numerals. Cold, clear, precise.',
    modelCode: 'FRS-07',
    productId: 'theme_frost',
  ),
  SkinInfo(
    mode: AppThemeMode.velvet,
    label: 'VELVET',
    tagline: 'Wine velvet, rose-gold trim.',
    description: 'Cream numerals on deep wine. Dressed up for the evening.',
    modelCode: 'VLV-08',
    productId: 'theme_velvet',
  ),
];

SkinInfo skinOf(AppThemeMode mode) => kSkins.firstWhere((s) => s.mode == mode);
