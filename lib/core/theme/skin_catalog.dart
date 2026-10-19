import 'package:popcalc/core/haptics/app_haptics.dart';

import 'theme_tokens.dart';

/// Master switch for the paid store. When false every skin counts as owned
/// and nothing needs buying ("free during launch"); when true, premium skins
/// and materials need a purchase from Google Play.
const bool kPremiumLocked = true;

/// Product id of the bundle that unlocks every premium skin and material.
const String kAllThemesProductId = 'themes_all';

/// The newsroom hunt that leads to the secret skin: notes from "the editor",
/// one at a time on the ??? tile in Settings, each pointing at a feature.
/// Solved in order (`SettingsNotifier.advanceHunt`):
///   0 divide by zero, 1 Typewriter sound pack,
///   2 tan 90 in degrees, an error like 0 (turns people on to Scientific),
///   3 any overflow ("too big to print"; xʸ or ! from the lead before),
///   4 tap "today's edition" waiting at the top of History.
/// The last tap closes History and the skin arrives with an ink spill.
const kHuntNotes = <String>[
  'Split something into nothing.',
  'Make your keys go clack-clack-ding.',
  'A guy named Tan took a 90-degree turn. Sources say he went off the charts.',
  'Some numbers are too big to print. Find one.',
  "Today's edition is already in the archive.",
];

/// The back of each lead card (press and hold to flip): the plain way in.
const kHuntHints = <String>[
  'Your maths teacher said never. Do it anyway: any number ÷ 0.',
  'Settings → Sound → the Typewriter pack.',
  'Turn on Scientific & Converter in Settings, then type tan 90 =.',
  "Try 9 ^ 9999 =. The paper won't have room.",
  "Tap the clock (History) and open Today's Edition.",
];

/// The pill on the calculator as each lead is cracked (index = leads
/// solved − 1), followed by the count. Builds like a case coming together.
const kHuntSolvedLines = <String>[
  'FIRST LEAD CRACKED',
  'THE PLOT THICKENS',
  'HOT ON THE TRAIL',
  'ONE LEAD LEFT',
  'CASE CRACKED',
];

/// Shown under a note whose setting may already be on.
const kHuntAgainHint = 'Already done? Do it again.';

/// What dividing by zero says while it is the first note (CAPITALS, ≤ 19).
const kHuntErrorLine = "NOW THAT'S A STORY";
const kHuntErrorNote =
    'A tip just came in. The case file is under the ??? skin.';

/// What tan 90 says while it is the third note (CAPITALS, ≤ 19).
// Not "OFF THE CHARTS": that is one of tan 90's everyday jokes.
const kHuntTanLine = 'SOURCE CONFIRMED';
const kHuntTanNote = 'Lead cracked. Now go big. Really big.';

/// Under the overflow punchline while it is the fourth note.
const kHuntBigNote = "Lead cracked. The archive has today's paper.";

/// The planted entry at the top of History for the last note.
const kHuntEditionTitle = "TODAY'S EDITION";
const kHuntEditionLine = 'Hot off the press. Tap to read.';

/// What the big number says once the ink dries.
const kHuntHeadline = 'EXTRA! EXTRA!';
const kHuntHeadlineNote = 'Newsprint is yours. Welcome to the paper.';

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

  /// Not sold and not shown until it has been found (see [kSecretSkins]).
  final bool secret;

  const SkinInfo({
    required this.mode,
    required this.label,
    required this.tagline,
    required this.description,
    required this.modelCode,
    this.productId,
    this.feels = const [],
    this.secret = false,
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
    mode: AppThemeMode.blueprint,
    label: 'BLUEPRINT',
    tagline: 'Drawn, not built.',
    description: 'Cyanotype paper and hollow line-drawn numerals.',
    modelCode: 'BP-03',
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

/// Skins that are found, not bought: hidden from the picker until the
/// newsroom hunt ([kHuntNotes]) is solved. Not in the store or the bundle.
const kSecretSkins = <SkinInfo>[
  SkinInfo(
    mode: AppThemeMode.newsprint,
    label: 'NEWSPRINT',
    tagline: 'Hot off the press.',
    description: 'Ink on paper in halftone dots, with a red stamp.',
    modelCode: 'X-NWS',
    secret: true,
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

SkinInfo skinOf(AppThemeMode mode) => [
  ...kSkins,
  ...kMaterials,
  ...kSecretSkins,
].firstWhere((s) => s.mode == mode);
