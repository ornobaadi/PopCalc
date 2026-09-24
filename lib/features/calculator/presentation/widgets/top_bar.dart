import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

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
    final themeMode = ref.watch(themeProvider);

    return SizedBox(
      height: 44.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
            IconButton(
              icon: Icon(
                themeMode == AppThemeMode.ink
                    ? Icons.wb_sunny_outlined
                    : Icons.nightlight_round_outlined,
                color: colors.inkSoft.withValues(alpha: 0.65),
                size: 18.0,
              ),
              splashRadius: 20.0,
              tooltip: 'Toggle Theme',
              onPressed: () {
                ref.read(themeProvider.notifier).toggleTheme();
              },
            ),
          ],
        ),
      ),
    );
  }
}
