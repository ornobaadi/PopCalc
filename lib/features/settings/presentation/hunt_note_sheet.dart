import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// The ??? tile's case file from "the editor": a manila folder with the
/// current lead typed on a clipped index card, cracked leads stamped below
/// and the leads still to come redacted. It is a prop, so it looks the same
/// in every skin.
class HuntNoteSheet extends ConsumerWidget {
  /// Kept for the call sites; the folder has its own colours.
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

  // Manila folder, typewriter ribbon, rubber-stamp red.
  static const manila = Color(0xFFE9D5A6);
  static const manilaEdge = Color(0xFFC9AE72);
  static const card = Color(0xFFFBF8F1);
  static const ink = Color(0xFF2B2116);
  static const inkSoft = Color(0xFF7A6A52);
  static const stamp = Color(0xFFC0281E);

  static String leadNo(int i) => 'LEAD #${(i + 1).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final step = settings.huntDone ? kHuntLength : settings.huntStep;
    final done = step >= kHuntLength;
    final bottom = MediaQuery.viewPaddingOf(context).bottom;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10.0, 0, 10.0, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The folder's tab.
            Container(
              margin: const EdgeInsets.only(left: 18.0),
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 6.0),
              decoration: const BoxDecoration(
                color: manila,
                borderRadius: BorderRadius.vertical(top: Radius.circular(12.0)),
                border: Border(
                  top: BorderSide(color: manilaEdge),
                  left: BorderSide(color: manilaEdge),
                  right: BorderSide(color: manilaEdge),
                ),
              ),
              child: const Text(
                'CASE PC-1337',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.0,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: inkSoft,
                ),
              ),
            ),
            Flexible(
              child: Container(
                decoration: const BoxDecoration(
                  color: manila,
                  borderRadius: BorderRadius.only(
                    topRight: Radius.circular(22.0),
                    topLeft: Radius.circular(6.0),
                  ),
                  border: Border(
                    top: BorderSide(color: manilaEdge),
                    left: BorderSide(color: manilaEdge),
                    right: BorderSide(color: manilaEdge),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(
                          22.0,
                          18.0,
                          22.0,
                          8.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Header(step: step, done: done),
                            const SizedBox(height: 18.0),
                            if (!done)
                              _LeadCard(
                                key: const ValueKey('hunt-current'),
                                index: step,
                                text: kHuntNotes[step],
                                backText: kHuntHints[step],
                                again: step == 1 || step == 2
                                    ? kHuntAgainHint
                                    : null,
                              ),
                            // Cracked leads, newest first.
                            for (var i = step - 1; i >= 0; i--)
                              _CrackedLead(index: i, text: kHuntNotes[i]),
                            // Leads still to come, blacked out.
                            for (var i = step + 1; i < kHuntLength; i++)
                              _RedactedLead(index: i),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        22.0,
                        6.0,
                        22.0,
                        16.0 + bottom,
                      ),
                      child: _CaseButton(
                        label: done ? 'CLOSE THE FILE' : 'ON THE CASE',
                        onTap: () {
                          AppHaptics.selectionClick();
                          Navigator.of(context).pop();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;
  final bool done;
  const _Header({required this.step, required this.done});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            done ? 'CASE CLOSED' : "THE EDITOR'S CASE FILE",
            style: const TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 30.0,
              letterSpacing: 1.4,
              color: HuntNoteSheet.ink,
            ),
          ),
        ),
        const SizedBox(height: 4.0),
        Row(
          children: [
            Expanded(
              child: Text(
                done
                    ? 'LEADS $kHuntLength/$kHuntLength  ·  CLOSED'
                    : 'LEADS $step/$kHuntLength  ·  OPEN',
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.0,
                  letterSpacing: 1.0,
                  color: HuntNoteSheet.inkSoft,
                ),
              ),
            ),
            _Stamp(done ? 'SOLVED' : 'CONFIDENTIAL', angle: -0.12, size: 15.0),
          ],
        ),
      ],
    );
  }
}

/// The lead being worked: typed on an index card, clipped to the folder.
/// Press and hold to flip it (unannounced): the back has the plain hint.
class _LeadCard extends StatefulWidget {
  final int index;
  final String text;
  final String backText;
  final String? again;
  const _LeadCard({
    super.key,
    required this.index,
    required this.text,
    required this.backText,
    this.again,
  });

  @override
  State<_LeadCard> createState() => _LeadCardState();
}

class _LeadCardState extends State<_LeadCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  );

  void _turn(bool toBack) {
    AppHaptics.selectionClick();
    toBack ? _flip.forward() : _flip.reverse();
  }

  @override
  void dispose() {
    _flip.dispose();
    super.dispose();
  }

  static const _label = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12.0,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.5,
    color: HuntNoteSheet.stamp,
  );
  static const _typed = TextStyle(
    // Typed on the newsroom's typewriter.
    fontFamily: 'monospace',
    fontSize: 16.0,
    height: 1.45,
    color: HuntNoteSheet.ink,
  );

  // No "hold for a hint" label: the flip is there for whoever finds it.
  Widget _front() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(HuntNoteSheet.leadNo(widget.index), style: _label),
      const SizedBox(height: 8.0),
      Text(widget.text, style: _typed),
    ],
  );

  Widget _back() => Column(
    key: const ValueKey('hunt-hint'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('HINT · ${HuntNoteSheet.leadNo(widget.index)}', style: _label),
      const SizedBox(height: 8.0),
      Text(widget.backText, style: _typed.copyWith(fontSize: 15.0)),
      if (widget.again != null) ...[
        const SizedBox(height: 8.0),
        Text(
          widget.again!,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.0,
            fontStyle: FontStyle.italic,
            color: HuntNoteSheet.inkSoft,
          ),
        ),
      ],
    ],
  );

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _turn(true),
      onLongPressEnd: (_) => _turn(false),
      onLongPressCancel: () => _turn(false),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0, top: 6.0),
        child: AnimatedBuilder(
          animation: _flip,
          builder: (context, _) {
            final angle = Curves.easeInOut.transform(_flip.value) * math.pi;
            final showBack = angle > math.pi / 2;
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(angle)
                ..rotateZ(-0.012),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(26.0, 16.0, 18.0, 18.0),
                    decoration: BoxDecoration(
                      color: HuntNoteSheet.card,
                      borderRadius: BorderRadius.circular(4.0),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 8.0,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    foregroundDecoration: const BoxDecoration(
                      // The card's red margin rule.
                      border: Border(
                        left: BorderSide(color: Color(0x66C0281E), width: 1.5),
                      ),
                    ),
                    // Both sides are laid out, so flipping never changes
                    // the card's height; only the facing one is seen.
                    child: Stack(
                      children: [
                        Opacity(opacity: showBack ? 0 : 1, child: _front()),
                        Opacity(
                          opacity: showBack ? 1 : 0,
                          child: Transform(
                            alignment: Alignment.center,
                            transform: Matrix4.rotationY(math.pi),
                            child: SizedBox(
                              width: double.infinity,
                              child: _back(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!showBack)
                    const Positioned(
                      right: 22.0,
                      top: -14.0,
                      child: CustomPaint(
                        size: Size(16, 44),
                        painter: _PaperclipPainter(),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CrackedLead extends StatelessWidget {
  final int index;
  final String text;
  const _CrackedLead({required this.index, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      padding: const EdgeInsets.fromLTRB(14.0, 10.0, 12.0, 10.0),
      decoration: BoxDecoration(
        color: HuntNoteSheet.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  HuntNoteSheet.leadNo(index),
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11.0,
                    letterSpacing: 1.2,
                    color: HuntNoteSheet.inkSoft,
                  ),
                ),
                const SizedBox(height: 3.0),
                Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    height: 1.35,
                    color: HuntNoteSheet.inkSoft,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: HuntNoteSheet.inkSoft,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          const _Stamp('CRACKED', angle: -0.2, size: 14.0),
        ],
      ),
    );
  }
}

/// A lead not reached yet: its number, and the rest blacked out.
class _RedactedLead extends StatelessWidget {
  final int index;
  const _RedactedLead({required this.index});

  @override
  Widget build(BuildContext context) {
    // Bar widths vary per lead so the redactions look typed, not drawn.
    final widths = [
      [0.62, 0.38],
      [0.48, 0.7],
      [0.74, 0.3],
      [0.4, 0.56],
      [0.66, 0.44],
    ][index % 5];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14.0, 4.0, 12.0, 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            HuntNoteSheet.leadNo(index),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.0,
              letterSpacing: 1.2,
              color: HuntNoteSheet.inkSoft.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 5.0),
          LayoutBuilder(
            builder: (context, c) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final w in widths)
                  Container(
                    width: c.maxWidth * w,
                    height: 11.0,
                    margin: const EdgeInsets.only(bottom: 4.0),
                    decoration: BoxDecoration(
                      color: HuntNoteSheet.ink.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(1.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  final String text;
  final double angle;
  final double size;
  const _Stamp(this.text, {required this.angle, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        padding: const EdgeInsets.fromLTRB(7.0, 2.0, 7.0, 0.0),
        decoration: BoxDecoration(
          border: Border.all(
            color: HuntNoteSheet.stamp.withValues(alpha: 0.85),
            width: 2.0,
          ),
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: 'BebasNeue',
            fontSize: size,
            letterSpacing: 1.6,
            color: HuntNoteSheet.stamp.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }
}

class _CaseButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _CaseButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HuntNoteSheet.ink,
      borderRadius: BorderRadius.circular(28.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(28.0),
        onTap: onTap,
        child: SizedBox(
          height: 54.0,
          width: double.infinity,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 22.0,
                letterSpacing: 2.0,
                color: HuntNoteSheet.manila,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A steel paperclip: two nested rounded loops.
class _PaperclipPainter extends CustomPainter {
  const _PaperclipPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0xFF8C8C8C)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.3, h * 0.75)
      ..lineTo(w * 0.3, h * 0.2)
      ..arcTo(
        Rect.fromLTWH(w * 0.3, 0, w * 0.6, w * 0.6),
        math.pi,
        math.pi,
        false,
      )
      ..lineTo(w * 0.9, h * 0.85)
      ..arcTo(Rect.fromLTWH(0, h - w, w * 0.9, w), 0, math.pi, false)
      ..lineTo(0, h * 0.3);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// The hunt's progress as ink dots, one per lead.
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
