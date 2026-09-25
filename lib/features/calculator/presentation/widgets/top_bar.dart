import 'package:flutter/material.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/settings/presentation/settings_sheet.dart';

class TopBar extends ConsumerWidget {
  final ThemeColors colors;
  final VoidCallback? onHistoryTap;

  const TopBar({
    super.key,
    required this.colors,
    this.onHistoryTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: 44.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // History button
            IconButton(
              icon: Icon(
                Icons.access_time_rounded,
                color: colors.inkSoft.withValues(alpha: 0.65),
                size: 20.0,
              ),
              splashRadius: 20.0,
              tooltip: 'History',
              onPressed: onHistoryTap,
            ),

            // Settings / Skins button
            IconButton(
              icon: Icon(
                Icons.tune_rounded,
                color: colors.inkSoft.withValues(alpha: 0.65),
                size: 20.0,
              ),
              splashRadius: 20.0,
              tooltip: 'Settings',
              onPressed: () {
                AppHaptics.selectionClick();
                SettingsSheet.show(context, colors: colors);
              },
            ),
          ],
        ),
      ),
    );
  }
}
