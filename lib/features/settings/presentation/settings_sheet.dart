import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/material_feel.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/features/themes/presentation/store_widgets.dart';
import 'package:popcalc/features/themes/presentation/theme_card.dart';
import 'package:popcalc/features/themes/presentation/theme_detail_sheet.dart';
import 'package:popcalc/features/themes/presentation/theme_store_screen.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({super.key, ThemeColors? colors});

  static Future<void> show(BuildContext context, {ThemeColors? colors}) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const SettingsSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(themeProvider);
    final colors = AppTheme.colorsOf(currentMode);
    final owned = ref.watch(entitlementProvider);
    // Free and premium skins always show; a material only once it's owned.
    final skins = [...kSkins, ...kMaterials.where((m) => ownsSkin(owned, m))];
    final ownsAll = kBundleItems.every((s) => ownsSkin(owned, s));
    final saving = ref.watch(purchasesProvider.select((s) => s.bundleSaving));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        border: Border(
          top: BorderSide(color: colors.ink.withValues(alpha: 0.1), width: 1.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12.0, bottom: 12.0),
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: colors.inkSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Text(
                      'SKINS',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 32.0,
                        letterSpacing: 2.0,
                        color: colors.ink,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12.0),

                  // Skin grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: GridView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 8.0,
                            mainAxisSpacing: 12.0,
                            mainAxisExtent: _SkinTile.height,
                          ),
                      itemCount: skins.length,
                      itemBuilder: (context, index) {
                        final skin = skins[index];
                        final locked = !ownsSkin(owned, skin);
                        return _SkinTile(
                          skin: skin,
                          colors: colors,
                          locked: locked,
                          selected: !locked && skin.mode == currentMode,
                          onTap: () {
                            if (locked) {
                              AppHaptics.lightImpact();
                              SkinDetailSheet.show(context, skin);
                              return;
                            }
                            AppHaptics.selectionClick();
                            ref
                                .read(themeProvider.notifier)
                                .setTheme(skin.mode);
                          },
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16.0),
                  // Skin store entry
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _StoreBanner(
                      colors: colors,
                      ownsAll: ownsAll,
                      saving: ownsAll ? null : saving,
                      onTap: () {
                        AppHaptics.selectionClick();
                        ThemeStoreScreen.open(context);
                      },
                    ),
                  ),

                  const SizedBox(height: 20.0),
                  Divider(color: colors.ink.withValues(alpha: 0.08), height: 1),
                  const SizedBox(height: 6.0),

                  // Settings options
                  Consumer(
                    builder: (context, ref, _) {
                      final settings = ref.watch(settingsProvider);
                      final settingsNotifier = ref.read(
                        settingsProvider.notifier,
                      );

                      return Column(
                        children: [
                          // Scientific keys + unit converter, both
                          // reached from the top bar
                          _SettingsRow(
                            icon: Icons.functions_rounded,
                            label: 'Scientific & Converter',
                            description: 'Adds f(x) and unit converter buttons to the top bar',
                            colors: colors,
                            trailing: Switch(
                              value: settings.advancedTools,
                              onChanged: (val) {
                                AppHaptics.mode(val);
                                settingsNotifier.setAdvancedTools(val);
                              },
                              activeThumbColor: colors.accent,
                              activeTrackColor: colors.accent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),

                          // Live Result Preview toggle
                          _SettingsRow(
                            icon: Icons.visibility_outlined,
                            label: 'Live Preview on Top',
                            description: 'Show "= preview" on top while typing (off by default)',
                            colors: colors,
                            trailing: Switch(
                              value: settings.showLivePreview,
                              onChanged: (val) {
                                AppHaptics.selectionClick();
                                settingsNotifier.setShowLivePreview(val);
                              },
                              activeThumbColor: colors.accent,
                              activeTrackColor: colors.accent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),

                          // Haptics toggle
                          _SettingsRow(
                            icon: Icons.vibration_rounded,
                            label: 'Haptic Feedback',
                            colors: colors,
                            trailing: Switch(
                              value: settings.hapticsEnabled,
                              onChanged: (val) {
                                settingsNotifier.setHapticsEnabled(val);
                                // Let them feel it come back on.
                                if (val) AppHaptics.operatorKey();
                              },
                              activeThumbColor: colors.accent,
                              activeTrackColor: colors.accent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                          // Strength: detents tick at the new strength as
                          // you drag, and releasing plays a key press.
                          _VolumeSlider(
                            value: settings.hapticStrength,
                            enabled: settings.hapticsEnabled,
                            colors: colors,
                            lowIcon: Icons.vibration_rounded,
                            onChanged: settingsNotifier.setHapticStrength,
                            onChangeEnd: (_) {
                              settingsNotifier.saveHapticStrength();
                              AppHaptics.operatorKey();
                            },
                          ),

                          // Lite Effects Mode
                          _SettingsRow(
                            icon: Icons.speed_rounded,
                            label: 'Lite Effects Mode',
                            description:
                                'Optimized rendering for lower latency',
                            colors: colors,
                            trailing: Switch(
                              value: settings.liteMode,
                              onChanged: (val) {
                                settingsNotifier.setLiteMode(val);
                              },
                              activeThumbColor: colors.accent,
                              activeTrackColor: colors.accent.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 6.0),
                  Divider(color: colors.ink.withValues(alpha: 0.08), height: 1),
                  _SoundSection(colors: colors),
                  const SizedBox(height: 8.0),
                  Divider(color: colors.ink.withValues(alpha: 0.08), height: 1),
                  _SignatureFooter(colors: colors),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? description;
  final ThemeColors colors;
  final Widget? trailing;

  const _SettingsRow({
    required this.icon,
    required this.label,
    this.description,
    required this.colors,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
      child: Row(
        children: [
          Icon(icon, color: colors.inkSoft, size: 22.0),
          const SizedBox(width: 14.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 20.0,
                    letterSpacing: 0.5,
                    color: colors.ink,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 1.0),
                  Text(
                    description!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      color: colors.inkSoft.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Sound effect controls. Every change is previewed immediately
/// so users hear exactly what they picked.
class _SoundSection extends ConsumerWidget {
  final ThemeColors colors;

  const _SoundSection({required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    Switch toggle(bool value, ValueChanged<bool> onChanged) => Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: colors.accent,
      activeTrackColor: colors.accent.withValues(alpha: 0.35),
    );

    final skin = skinOf(ref.watch(themeProvider));
    final material = ref.watch(materialFeelProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24.0, 18.0, 24.0, 4.0),
          child: Text(
            'SOUND',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 26.0,
              letterSpacing: 2.0,
              color: colors.ink,
            ),
          ),
        ),

        // Sound effects
        _SettingsRow(
          icon: Icons.volume_up_rounded,
          label: 'Sound Effects',
          description: 'Follows your media volume',
          colors: colors,
          trailing: toggle(settings.soundEnabled, (val) {
            AppHaptics.selectionClick();
            notifier.setSoundEnabled(val);
            if (val) AppSounds.playWhenReady(Sfx.success);
          }),
        ),
        _VolumeSlider(
          value: settings.soundVolume,
          enabled: settings.soundEnabled,
          colors: colors,
          onChanged: notifier.setSoundVolume,
          onChangeEnd: (_) {
            notifier.saveSoundVolume();
            AppSounds.playWhenReady(Sfx.digit7);
          },
        ),

        // Sound pack picker. A material brings its own sound and haptics
        // as one set, so the packs step aside; Mechanical offers its
        // switches here instead.
        if (material == null)
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: settings.soundEnabled ? 1.0 : 0.4,
            child: IgnorePointer(
              ignoring: !settings.soundEnabled,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 6.0),
                child: Row(
                  children: [
                    for (final pack in SoundPack.values) ...[
                      if (pack != SoundPack.values.first)
                        const SizedBox(width: 10.0),
                      Expanded(
                        child: _PackChip(
                          label: pack.label,
                          semantics: '${pack.label} sound pack',
                          selected: settings.soundPack == pack,
                          colors: colors,
                          onTap: () {
                            AppHaptics.selectionClick();
                            // Instant preview from the preloaded sample.
                            AppSounds.previewPack(pack);
                            notifier.setSoundPack(pack);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else if (skin.feels.length > 1)
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 4.0, 24.0, 6.0),
            child: Row(
              children: [
                for (final feel in skin.feels) ...[
                  if (feel != skin.feels.first) const SizedBox(width: 10.0),
                  Expanded(
                    child: _PackChip(
                      label: feel.label,
                      semantics: '${feel.label} switch',
                      selected: material.id == feel.id,
                      colors: colors,
                      onTap: () {
                        // Hear and feel the switch you just picked.
                        AppSounds.previewMaterial(feel.soundFolder, Sfx.digit5);
                        AppHaptics.demo(feel.haptics);
                        notifier.setMechSwitch(feel.id);
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            material == null
                ? settings.soundPack.description
                : skin.feels.length > 1
                ? material.description
                : 'Sound and haptics come with ${skin.label}: '
                      '${material.description.toLowerCase()}.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: colors.inkSoft.withValues(alpha: 0.8),
            ),
          ),
        ),
      ],
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  final double value;
  final bool enabled;
  final ThemeColors colors;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final IconData lowIcon;

  const _VolumeSlider({
    this.lowIcon = Icons.volume_mute_rounded,
    required this.value,
    required this.enabled,
    required this.colors,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = colors.inkSoft.withValues(alpha: enabled ? 0.8 : 0.3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56.0, 0.0, 16.0, 0.0),
      child: Row(
        children: [
          Icon(lowIcon, size: 18.0, color: iconColor),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4.0,
                activeTrackColor: colors.accent,
                inactiveTrackColor: colors.ink.withValues(alpha: 0.12),
                thumbColor: colors.accent,
                overlayColor: colors.accent.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: value,
                divisions: 20,
                onChanged: enabled
                    ? (v) {
                        // Detent tick at each 5% step.
                        if (v != value) AppHaptics.selectionClick();
                        onChanged(v);
                      }
                    : null,
                onChangeEnd: enabled ? onChangeEnd : null,
              ),
            ),
          ),
          SizedBox(
            width: 40.0,
            child: Text(
              '${(value * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 16.0,
                color: iconColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PackChip extends StatelessWidget {
  final String label;
  final String semantics;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _PackChip({
    required this.label,
    required this.semantics,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? colors.accent.withValues(alpha: 0.15)
                : colors.ink.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14.0),
            border: Border.all(
              color: selected
                  ? colors.accent
                  : colors.ink.withValues(alpha: 0.12),
              width: selected ? 2.0 : 1.5,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 17.0,
              letterSpacing: 1.0,
              color: selected ? colors.accent : colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Tiny numeral + accent dot rendered in a skin's own colours so dark
/// skins are distinguishable at a glance.
/// One skin in the picker: a hexagon in the skin's own colours with its
/// name underneath. A lock marks one that has to be bought first.
class _SkinTile extends StatelessWidget {
  static const _hexWidth = 62.0;
  static const _hexHeight = 68.0;

  /// The hexagon, the gap and one line of name.
  static const height = _hexHeight + 6.0 + 18.0;

  final SkinInfo skin;
  final ThemeColors colors;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  const _SkinTile({
    required this.skin,
    required this.colors,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final own = skin.colors;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: _hexWidth,
            height: _hexHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: own.bg,
                      shape: StarBorder.polygon(
                        sides: 6,
                        pointRounding: 0.4,
                        side: selected
                            ? BorderSide(color: colors.accent, width: 3.0)
                            : BorderSide(
                                color: colors.ink.withValues(alpha: 0.15),
                                width: 1.5,
                              ),
                      ),
                      shadows: selected
                          ? [
                              BoxShadow(
                                color: colors.accent.withValues(alpha: 0.4),
                                blurRadius: 12.0,
                                offset: const Offset(0.0, 4.0),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      '7',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 32.0,
                        height: 1.0,
                        color: own.extrudeTop,
                        shadows: [
                          Shadow(
                            color: own.extrudeSide,
                            offset: const Offset(2.0, 2.0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 14.0,
                  top: 16.0,
                  child: Container(
                    width: 8.0,
                    height: 8.0,
                    decoration: BoxDecoration(
                      color: own.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                if (locked)
                  Positioned(
                    left: 0.0,
                    right: 0.0,
                    bottom: 6.0,
                    child: Icon(
                      Icons.lock_rounded,
                      color: own.inkSoft,
                      size: 12.0,
                    ),
                  ),
                if (selected)
                  Positioned(
                    right: -2.0,
                    bottom: 4.0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: colors.bg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: colors.accent,
                        size: 18.0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6.0),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              skin.label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 13.0,
                letterSpacing: 0.6,
                height: 1.2,
                color: locked ? colors.inkSoft : colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The way into the skin store: a few of its skins fanned out, how much
/// there is, and what the everything bundle saves.
class _StoreBanner extends StatelessWidget {
  final ThemeColors colors;
  final bool ownsAll;
  final int? saving;
  final VoidCallback onTap;

  const _StoreBanner({
    required this.colors,
    required this.ownsAll,
    required this.saving,
    required this.onTap,
  });

  static const _fan = [
    (AppThemeMode.synthwave, -24.0, 6.0, -0.2),
    (AppThemeMode.frost, 24.0, 6.0, 0.2),
    (AppThemeMode.clay, 0.0, 0.0, 0.0),
  ];

  @override
  Widget build(BuildContext context) {
    final skinCount = kSkins.where((s) => s.premium).length;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 84.0,
        padding: const EdgeInsets.only(left: 10.0, right: 10.0),
        decoration: BoxDecoration(
          color: colors.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(24.0),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 98.0,
              height: 60.0,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  for (final (mode, dx, dy, angle) in _fan)
                    Transform.translate(
                      offset: Offset(dx, dy),
                      child: Transform.rotate(
                        angle: angle,
                        child: SizedBox(
                          width: 46.0,
                          child: SkinMockup(
                            skin: skinOf(mode),
                            borderColor: Colors.white,
                            borderWidth: 2.0,
                            radius: 11.0,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10.0),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Text(
                          'SKIN STORE',
                          style: TextStyle(
                            fontFamily: 'BebasNeue',
                            fontSize: 22.0,
                            letterSpacing: 1.6,
                            height: 1.15,
                            color: colors.ink,
                          ),
                        ),
                        if (saving != null) ...[
                          const SizedBox(width: 8.0),
                          SavingChip(
                            percent: saving!,
                            color: colors.accent,
                            onColor: colors.bg,
                            fontSize: 12.0,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 2.0),
                  Text(
                    ownsAll
                        ? 'Everything unlocked'
                        : '$skinCount skins and ${kMaterials.length} materials',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.3,
                      color: colors.inkSoft,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.inkSoft),
          ],
        ),
      ),
    );
  }
}

/// Maker's mark: handwritten signature, version and a short note.
/// Keep [_appVersion] in step with `version:` in pubspec.yaml.
/// Tapping the signature five times quickly opens the portfolio (hidden).
class _SignatureFooter extends StatefulWidget {
  final ThemeColors colors;
  const _SignatureFooter({required this.colors});

  static const _appVersion = '1.3.0 (8)';

  @override
  State<_SignatureFooter> createState() => _SignatureFooterState();
}

class _SignatureFooterState extends State<_SignatureFooter> {
  int _taps = 0;
  Timer? _reset;

  @override
  void dispose() {
    _reset?.cancel();
    super.dispose();
  }

  void _onTap() {
    _reset?.cancel();
    _reset = Timer(const Duration(milliseconds: 1500), () => _taps = 0);
    if (++_taps >= 5) {
      _taps = 0;
      AppHaptics.operatorKey();
      launchUrl(
        Uri.parse('https://ornobaadi.vercel.app'),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final soft = colors.inkSoft.withValues(alpha: 0.75);
    final label = TextStyle(
      fontFamily: 'Inter',
      fontSize: 11.0,
      letterSpacing: 2.0,
      color: soft,
    );
    final dot = Container(
      width: 4.0,
      height: 4.0,
      margin: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(color: soft, shape: BoxShape.circle),
    );
    Widget line(List<String> parts) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < parts.length; i++) ...[
          if (i > 0) dot,
          Text(parts[i], style: label),
        ],
      ],
    );
    final variant = colors.isDark ? 'light' : 'dark';
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 32.0, 0, 32.0),
      child: Center(
        child: Column(
          children: [
            Text('HANDCRAFTED BY', style: label),
            const SizedBox(height: 8.0),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _onTap,
              child: Semantics(
                label: 'Ornob Aadi',
                child: Opacity(
                  opacity: 0.95,
                  child: Image.asset(
                    'assets/ornob-aadi-signature/ornob-aadi-signature-bold-$variant.png',
                    height: 104.0,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            line(['POPCALC', 'VERSION ${_SignatureFooter._appVersion}']),
            const SizedBox(height: 8.0),
            line(['OFFLINE', 'NO ADS', 'NO TRACKING']),
          ],
        ),
      ),
    );
  }
}
