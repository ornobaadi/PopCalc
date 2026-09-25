import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';


/// A skin (theme) descriptor used in the settings skin picker.
class SkinOption {
  final String id;
  final String label;
  final String badge;   // e.g. "FREE" / "PRO"
  final AppThemeMode mode;
  final Color swatch;   // hex blob colour for the tile
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
    label: 'ANDY',
    badge: 'FREE',
    mode: AppThemeMode.sunny,
    swatch: Color(0xFFFFAE00),
  ),
  SkinOption(
    id: 'ink',
    label: 'GRAPHITE',
    badge: 'FREE',
    mode: AppThemeMode.ink,
    swatch: Color(0xFF1A1A1A),
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
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 12.0,
                mainAxisSpacing: 16.0,
                childAspectRatio: 0.75,
              ),
              itemCount: _skins.length,
              itemBuilder: (context, index) {
                final skin = _skins[index];
                final isSelected = !skin.locked && skin.mode == currentMode;

                return GestureDetector(
                  onTap: () {
                    if (skin.locked) {
                      AppHaptics.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Unlock Pro to access this skin'),
                          backgroundColor: colors.accent,
                          duration: const Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    AppHaptics.selectionClick();
                    ref.read(themeProvider.notifier).setTheme(skin.mode);
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
                              ? Border.all(color: colors.accent, width: 3.0)
                              : Border.all(
                                  color: colors.ink.withValues(alpha: 0.15),
                                  width: 1.5,
                                ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colors.accent.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: skin.locked
                            ? Icon(Icons.lock_outline_rounded,
                                color: Colors.white.withValues(alpha: 0.8),
                                size: 22.0)
                            : isSelected
                                ? Icon(Icons.check_rounded,
                                    color: colors.accent, size: 24.0)
                                : null,
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
                            horizontal: 6.0, vertical: 1.0),
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
                            color: skin.locked ? colors.inkSoft : colors.accent,
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
              final settingsNotifier = ref.read(settingsProvider.notifier);

              return Column(
                children: [
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
                      activeTrackColor: colors.accent.withValues(alpha: 0.35),
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
                      },
                      activeThumbColor: colors.accent,
                      activeTrackColor: colors.accent.withValues(alpha: 0.35),
                    ),
                  ),

                  // Lite Effects Mode
                  _SettingsRow(
                    icon: Icons.speed_rounded,
                    label: 'Lite Effects Mode',
                    description: 'Optimized rendering for lower latency',
                    colors: colors,
                    trailing: Switch(
                      value: settings.liteMode,
                      onChanged: (val) {
                        settingsNotifier.setLiteMode(val);
                      },
                      activeThumbColor: colors.accent,
                      activeTrackColor: colors.accent.withValues(alpha: 0.35),
                    ),
                  ),
                ],
              );
            },
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
