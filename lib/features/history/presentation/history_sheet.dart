import 'package:flutter/material.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/storage/history_store.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

class HistorySheet extends ConsumerWidget {
  final void Function(String expression, String result) onSelectEntry;

  const HistorySheet({
    super.key,
    ThemeColors? colors,
    required this.onSelectEntry,
  });

  static Future<void> show(
    BuildContext context, {
    ThemeColors? colors,
    required void Function(String expression, String result) onSelectEntry,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HistorySheet(
        onSelectEntry: onSelectEntry,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.colorsOf(ref.watch(themeProvider));
    final history = ref.watch(historyProvider);
    final historyNotifier = ref.read(historyProvider.notifier);
    // The hunt's last note: today's edition waits at the top.
    final edition = ref.watch(settingsProvider.select(
      (s) => !s.huntDone && s.huntStep == kHuntLength - 1,
    ));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      height: MediaQuery.of(context).size.height * 0.65,
      decoration: BoxDecoration(
        color: colors.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28.0)),
        border: Border(
          top: BorderSide(
            color: colors.ink.withValues(alpha: 0.1),
            width: 1.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12.0, bottom: 8.0),
              width: 36.0,
              height: 4.0,
              decoration: BoxDecoration(
                color: colors.inkSoft.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HISTORY',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 28.0,
                    letterSpacing: 1.5,
                    color: colors.ink,
                  ),
                ),
                if (history.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      AppHaptics.mediumImpact();
                      historyNotifier.clearHistory();
                    },
                    child: Text(
                      'CLEAR ALL',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 18.0,
                        letterSpacing: 1.0,
                        color: colors.accent,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1.0, color: Colors.black12),

          // History items list
          Expanded(
            child: history.isEmpty && !edition
                ? Center(
                    child: Text(
                      'No calculations yet',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 22.0,
                        letterSpacing: 1.0,
                        color: colors.inkSoft.withValues(alpha: 0.6),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: history.length + (edition ? 1 : 0),
                    // The sheet runs under the system navigation bar
                    // (edge-to-edge), so the last entry needs to clear it.
                    padding: EdgeInsets.fromLTRB(
                      16.0,
                      8.0,
                      16.0,
                      8.0 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                    itemBuilder: (context, index) {
                      if (edition) {
                        if (index == 0) {
                          return _EditionEntry(
                            colors: colors,
                            onTap: () {
                              Navigator.of(context).pop();
                              ref
                                  .read(settingsProvider.notifier)
                                  .advanceHunt(kHuntLength - 1);
                            },
                          );
                        }
                        index--;
                      }
                      final item = history[index];
                      return Dismissible(
                        key: Key(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24.0),
                          color: colors.accent.withValues(alpha: 0.2),
                          child: Icon(Icons.delete_outline_rounded,
                              color: colors.accent),
                        ),
                        onDismissed: (_) {
                          historyNotifier.removeEntry(item.id);
                        },
                        child: InkWell(
                          onTap: () {
                            AppHaptics.selectionClick();
                            onSelectEntry(item.expression, item.result);
                            Navigator.of(context).pop();
                          },
                          borderRadius: BorderRadius.circular(16.0),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16.0, vertical: 12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item.expression,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'BebasNeue',
                                          fontSize: 18.0,
                                          letterSpacing: 0.5,
                                          color: colors.inkSoft,
                                        ),
                                      ),
                                      const SizedBox(height: 2.0),
                                      Text(
                                        '= ${item.result}',
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontFamily: 'BebasNeue',
                                          fontSize: 30.0,
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w400,
                                          color: colors.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Not a calculation: the newsroom hunt's last clue, a folded paper at the
/// top of History. Tapping it closes the sheet and the ink spills.
class _EditionEntry extends StatelessWidget {
  final ThemeColors colors;
  final VoidCallback onTap;
  const _EditionEntry({required this.colors, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Material(
        color: colors.ink,
        borderRadius: BorderRadius.circular(16.0),
        child: InkWell(
          key: const ValueKey('hunt-edition'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.0),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
            child: Row(
              children: [
                Icon(Icons.newspaper_rounded, color: colors.bg, size: 30.0),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        kHuntEditionTitle,
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 26.0,
                          letterSpacing: 1.2,
                          color: colors.bg,
                        ),
                      ),
                      Text(
                        kHuntEditionLine,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.0,
                          color: colors.bg.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
