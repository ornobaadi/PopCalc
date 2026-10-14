import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';
import 'package:popcalc/features/themes/presentation/store_widgets.dart';

/// The ??? tile's note from "the editor": the newsroom hunt's current clue
/// on top, the ones already solved below it, stamped FILED.
class HuntNoteSheet extends ConsumerWidget {
  final ThemeColors colors;
  const HuntNoteSheet({super.key, required this.colors});

  static Future<void> show(BuildContext context, ThemeColors colors) {
    AppHaptics.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => HuntNoteSheet(colors: colors),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final step = settings.huntDone ? kHuntLength : settings.huntStep;
    final done = step >= kHuntLength;

    return StoreSheet(
      colors: colors,
      body: [
        const SizedBox(height: 14.0),
        Text(
          done ? 'ALL STORIES FILED' : 'FROM THE EDITOR',
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: 30.0,
            letterSpacing: 1.6,
            color: colors.ink,
          ),
        ),
        Text(
          done
              ? 'Welcome to the paper.'
              : 'Note ${step + 1} of $kHuntLength',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.0,
            color: colors.inkSoft,
          ),
        ),
        const SizedBox(height: 18.0),
        if (!done)
          _Note(
            key: const ValueKey('hunt-current'),
            colors: colors,
            text: kHuntNotes[step],
            hint: step == 1 || step == 2 ? kHuntAgainHint : null,
          ),
        // Solved notes, newest first.
        for (var i = step - 1; i >= 0; i--)
          _Note(colors: colors, text: kHuntNotes[i], filed: true),
      ],
      footer: [
        StoreButton(
          colors: colors,
          onTap: () => Navigator.of(context).pop(),
          child: Text(
            done ? 'CLOSE' : "I'M ON IT",
            style: StoreButton.textStyle(colors),
          ),
        ),
      ],
    );
  }
}

class _Note extends StatelessWidget {
  final ThemeColors colors;
  final String text;
  final String? hint;
  final bool filed;

  const _Note({
    super.key,
    required this.colors,
    required this.text,
    this.hint,
    this.filed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
      decoration: BoxDecoration(
        color: colors.ink.withValues(alpha: filed ? 0.03 : 0.07),
        borderRadius: BorderRadius.circular(16.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    // A typed note: the typewriter's monospace.
                    fontFamily: 'monospace',
                    fontSize: filed ? 13.0 : 15.0,
                    height: 1.4,
                    color: filed ? colors.inkSoft : colors.ink,
                    decoration: filed ? TextDecoration.lineThrough : null,
                    decorationColor: colors.inkSoft,
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 8.0),
                  Text(
                    hint!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.0,
                      color: colors.inkSoft,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (filed) ...[
            const SizedBox(width: 10.0),
            Transform.rotate(
              angle: -0.18,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6.0,
                  vertical: 2.0,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: colors.accent, width: 1.5),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Text(
                  'FILED',
                  style: TextStyle(
                    fontFamily: 'BebasNeue',
                    fontSize: 14.0,
                    letterSpacing: 1.2,
                    color: colors.accent,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The hunt's progress as ink dots, one per note.
class HuntPips extends StatelessWidget {
  final ThemeColors colors;
  final int solved;
  const HuntPips({super.key, required this.colors, required this.solved});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kHuntLength; i++)
          Container(
            width: 5.0,
            height: 5.0,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < solved
                  ? colors.ink
                  : colors.inkSoft.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
