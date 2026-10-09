import 'package:popcalc/core/haptics/app_haptics.dart';

import 'theme_tokens.dart';

/// Master switch for the paid store. When false every skin counts as owned
/// and nothing needs buying ("free during launch"); when true, premium skins
/// and materials need a purchase from Google Play.
const bool kPremiumLocked = true;

/// Product id of the bundle that unlocks every premium skin and material.
const String kAllThemesProductId = 'themes_all';

/// The sound and haptics that come with a material. Most materials have one;
/// Mechanical has one per switch type.
class MaterialFeel {
  final String id; // persisted for the switch choice
  final String label;
  final String description;
  final String soundFolder; // under assets/sounds
  final HapticFeel haptics;

  const MaterialFeel({
    required this.id,
    required this.label,
    required this.description,
    required this.soundFolder,
    required this.haptics,
  });
}

/// A skin as it is presented and sold in the skin store.
class SkinInfo {
  final AppThemeMode mode;
  final String label;
  final String tagline;
  final String description;
  final String modelCode; // short catalogue tag shown beside the price
  final String? productId; // null for free skins

  /// Non-empty for a material: its look, sound and haptics are one set,
  /// applied together and never mixed with other skins or sound packs.
  final List<MaterialFeel> feels;

  const SkinInfo({
    required this.mode,
    required this.label,
    required this.tagline,
    required this.description,
    required this.modelCode,
    this.productId,
    this.feels = const [],
  });

  bool get premium => productId != null;
  bool get isMaterial => feels.isNotEmpty;

  /// The feel to use, given the saved switch id (only Mechanical has a
  /// choice; anything unknown falls back to the first).
  MaterialFeel? feelFor(String? id) => feels.isEmpty
      ? null
      : feels.firstWhere((f) => f.id == id, orElse: () => feels.first);
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

/// Materials: exclusive sets of look, sound and haptics. Each is sold on its
/// own, and the everything bundle includes them all.
const kMaterials = <SkinInfo>[
  SkinInfo(
    mode: AppThemeMode.clay,
    label: 'CLAY',
    tagline: 'Soft, warm, hand-pressed.',
    description:
        'Matte terracotta numerals on putty. Keys land with a damp thump '
        'and a soft press under your thumb.',
    modelCode: 'M-CLY',
    productId: 'material_clay',
    feels: [
      MaterialFeel(
        id: 'clay',
        label: 'CLAY',
        description: 'Damp thumps, soft presses',
        soundFolder: 'clay',
        haptics: HapticFeel.clay,
      ),
    ],
  ),
  SkinInfo(
    mode: AppThemeMode.chrome,
    label: 'CHROME',
    tagline: 'Cold, hard, mirror-bright.',
    description:
        'Polished steel numerals that catch a horizon. Bright metal pings '
        'and a precise double tick on every key.',
    modelCode: 'M-CRM',
    productId: 'material_chrome',
    feels: [
      MaterialFeel(
        id: 'chrome',
        label: 'CHROME',
        description: 'Metal pings, precise ticks',
        soundFolder: 'chrome',
        haptics: HapticFeel.chrome,
      ),
    ],
  ),
  SkinInfo(
    mode: AppThemeMode.glass,
    label: 'GLASS',
    tagline: 'Light as a fingertip on crystal.',
    description:
        'Frosted aqua numerals, bright along the top edge. Ringing glass '
        'taps and the lightest touch of the set.',
    modelCode: 'M-GLS',
    productId: 'material_glass',
    feels: [
      MaterialFeel(
        id: 'glass',
        label: 'GLASS',
        description: 'Ringing taps, feather-light touch',
        soundFolder: 'glass',
        haptics: HapticFeel.glass,
      ),
    ],
  ),
  SkinInfo(
    mode: AppThemeMode.wood,
    label: 'WOOD',
    tagline: 'Oak on walnut, dry and solid.',
    description:
        'Grained oak numerals on dark walnut. Hollow woodblock knocks and '
        'a firm rap for every press.',
    modelCode: 'M-WUD',
    productId: 'material_wood',
    feels: [
      MaterialFeel(
        id: 'wood',
        label: 'WOOD',
        description: 'Woodblock knocks, firm raps',
        soundFolder: 'wood',
        haptics: HapticFeel.wood,
      ),
    ],
  ),
  SkinInfo(
    mode: AppThemeMode.candy,
    label: 'CANDY',
    tagline: 'Glossy, sweet, a little bouncy.',
    description:
        'Hot-pink hard-candy numerals with a wet shine. Bouncy blips and '
        'a springy press that pops back.',
    modelCode: 'M-CDY',
    productId: 'material_candy',
    feels: [
      MaterialFeel(
        id: 'candy',
        label: 'CANDY',
        description: 'Bouncy blips, springy presses',
        soundFolder: 'candy',
        haptics: HapticFeel.candy,
      ),
    ],
  ),
  SkinInfo(
    mode: AppThemeMode.neon,
    label: 'NEON',
    tagline: 'A tube sign after dark.',
    description:
        'Glowing green tubes on a night wall. Buzzing synth zaps and a '
        'short electric tingle on each key.',
    modelCode: 'M-NEO',
    productId: 'material_neon',
    feels: [
      MaterialFeel(
        id: 'neon',
        label: 'NEON',
        description: 'Synth zaps, electric tingle',
        soundFolder: 'neon',
        haptics: HapticFeel.neon,
      ),
    ],
  ),
  SkinInfo(
    mode: AppThemeMode.mechanical,
    label: 'MECHANICAL',
    tagline: 'Three switches. Pick your sound.',
    description:
        'Cream keycaps on a dark board, with clicky, tactile and linear '
        'switches you can swap in settings.',
    modelCode: 'M-MEC',
    productId: 'material_mechanical',
    feels: [
      MaterialFeel(
        id: 'clicky',
        label: 'CLICKY',
        description: 'Sharp click, then the bottom-out',
        soundFolder: 'mech_clicky',
        haptics: HapticFeel.mechClicky,
      ),
      MaterialFeel(
        id: 'tactile',
        label: 'TACTILE',
        description: 'Soft bump into a deep thock',
        soundFolder: 'mech_tactile',
        haptics: HapticFeel.mechTactile,
      ),
      MaterialFeel(
        id: 'linear',
        label: 'LINEAR',
        description: 'Smooth and quiet, one clean landing',
        soundFolder: 'mech_linear',
        haptics: HapticFeel.mechLinear,
      ),
    ],
  ),
];

/// Everything the bundle unlocks, premium skins and materials alternating so
/// the store carousel mixes the two.
final List<SkinInfo> kBundleItems = () {
  final skins = kSkins.where((s) => s.premium).toList();
  return [
    for (var i = 0; i < skins.length || i < kMaterials.length; i++) ...[
      if (i < skins.length) skins[i],
      if (i < kMaterials.length) kMaterials[i],
    ],
  ];
}();

/// Every product id the store sells. Each needs a one-time product with the
/// same id in Play Console; one that is missing there simply shows as not
/// available.
final Set<String> kProductIds = {
  kAllThemesProductId,
  for (final skin in kBundleItems) skin.productId!,
};

SkinInfo skinOf(AppThemeMode mode) =>
    [...kSkins, ...kMaterials].firstWhere((s) => s.mode == mode);
