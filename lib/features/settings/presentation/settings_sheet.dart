import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';

/// A skin (theme) descriptor used in the settings skin picker.
class SkinOption {
  final String id;
  final String label;
  final String badge; // e.g. "FREE" / "PRO"
  final AppThemeMode mode;
  final Color swatch; // hex blob colour for the tile
  final bool locked;

  const SkinOption({
    required this.id,
    required this.label,
    required this.badge,
    required this.mode,
    required this.swatch,
    this.locked = false,
  });
}

const _skins = <SkinOption>[
  SkinOption(
    id: 'sunny',
    label: 'MARIGOLD',
    badge: 'FREE',
    mode: AppThemeMode.sunny,
    swatch: Color(0xFFFFAE00),
  ),
  SkinOption(
    id: 'ink',
    label: 'CHARCOAL',
    badge: 'FREE',
    mode: AppThemeMode.ink,
    swatch: Color(0xFF1A1A1A),
  ),
  SkinOption(
    id: 'peony',
    label: 'PEONY',
    badge: 'NEW',
    mode: AppThemeMode.peony,
    swatch: Color(0xFFF7E6E4),
  ),
  // Pro skins: free during launch — set `locked: true` to gate them.
  SkinOption(
    id: 'obsidian',
    label: 'OBSIDIAN',
    badge: 'PRO',
    mode: AppThemeMode.obsidian,
    swatch: Color(0xFF0B0B0C),
  ),
  SkinOption(
    id: 'synthwave',
    label: 'SYNTHWAVE',
    badge: 'PRO',
    mode: AppThemeMode.synthwave,
    swatch: Color(0xFF120A2A),
  ),
  SkinOption(
    id: 'matcha',
    label: 'MATCHA',
    badge: 'PRO',
    mode: AppThemeMode.matcha,
    swatch: Color(0xFFDDE4D0),
  ),
  SkinOption(
    id: 'frost',
    label: 'FROST',
    badge: 'PRO',
    mode: AppThemeMode.frost,
    swatch: Color(0xFFE8EFF5),
  ),
  SkinOption(
    id: 'velvet',
    label: 'VELVET',
    badge: 'PRO',
    mode: AppThemeMode.velvet,
    swatch: Color(0xFF3A0A1B),
  ),
];

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
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 12.0,
                            mainAxisSpacing: 16.0,
                            childAspectRatio: 0.75,
                          ),
                      itemCount: _skins.length,
                      itemBuilder: (context, index) {
                        final skin = _skins[index];
                        final isSelected =
                            !skin.locked && skin.mode == currentMode;

                        return GestureDetector(
                          onTap: () {
                            if (skin.locked) {
                              AppHaptics.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Unlock Pro to access this skin',
                                  ),
                                  backgroundColor: colors.accent,
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            AppHaptics.selectionClick();
                            ref
                                .read(themeProvider.notifier)
                                .setTheme(skin.mode);
                          },
                          child: Column(
                            children: [
                              // Hex tile
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 62.0,
                                height: 62.0,
                                decoration: BoxDecoration(
                                  color: skin.swatch,
                                  borderRadius: BorderRadius.circular(18.0),
                                  border: isSelected
                                      ? Border.all(
                                          color: colors.accent,
                                          width: 3.0,
                                        )
                                      : Border.all(
                                          color: colors.ink.withValues(
                                            alpha: 0.15,
                                          ),
                                          width: 1.5,
                                        ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: colors.accent.withValues(
                                              alpha: 0.4,
                                            ),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: skin.locked
                                    ? Icon(
                                        Icons.lock_outline_rounded,
                                        color: Colors.white.withValues(
                                          alpha: 0.8,
                                        ),
                                        size: 22.0,
                                      )
                                    : _SkinPreview(
                                        colors: ThemeColors.of(skin.mode),
                                        selected: isSelected,
                                      ),
                              ),
                              const SizedBox(height: 6.0),
                              // Name
                              Text(
                                skin.label,
                                style: TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 13.0,
                                  letterSpacing: 0.5,
                                  color: skin.locked
                                      ? colors.inkSoft.withValues(alpha: 0.5)
                                      : colors.ink,
                                ),
                              ),
                              // Badge
                              Container(
                                margin: const EdgeInsets.only(top: 2.0),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6.0,
                                  vertical: 1.0,
                                ),
                                decoration: BoxDecoration(
                                  color: skin.locked
                                      ? colors.inkSoft.withValues(alpha: 0.15)
                                      : colors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4.0),
                                ),
                                child: Text(
                                  skin.badge,
                                  style: TextStyle(
                                    fontFamily: 'BebasNeue',
                                    fontSize: 10.0,
                                    letterSpacing: 0.8,
                                    color: skin.locked
                                        ? colors.inkSoft
                                        : colors.accent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
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
                            description:
                                'Adds f(x) and unit converter buttons to the top bar',
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
                      fontFamily: 'Antonio',
                      fontSize: 12.0,
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

        // Sound pack picker
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
                        pack: pack,
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
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Text(
            settings.soundPack.description,
            style: TextStyle(
              fontFamily: 'Antonio',
              fontSize: 12.0,
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
  final SoundPack pack;
  final bool selected;
  final ThemeColors colors;
  final VoidCallback onTap;

  const _PackChip({
    required this.pack,
    required this.selected,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${pack.label} sound pack',
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
            pack.label.toUpperCase(),
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
class _SkinPreview extends StatelessWidget {
  final ThemeColors colors;
  final bool selected;

  const _SkinPreview({required this.colors, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          '7',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 34.0,
            height: 1.0,
            color: colors.extrudeTop,
            shadows: [
              Shadow(color: colors.extrudeSide, offset: const Offset(2, 2)),
            ],
          ),
        ),
        Positioned(
          right: 8.0,
          top: 8.0,
          child: Container(
            width: 9.0,
            height: 9.0,
            decoration: BoxDecoration(
              color: colors.accent,
              shape: BoxShape.circle,
            ),
          ),
        ),
        if (selected)
          Positioned(
            right: 4.0,
            bottom: 4.0,
            child: Icon(Icons.check_circle_rounded,
                color: colors.accent, size: 16.0),
          ),
      ],
    );
  }
}
