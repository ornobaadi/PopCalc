import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

import 'theme_card.dart';
import 'theme_preview_overlay.dart';

/// Product sheet for one skin, drawn in that skin's own colours:
/// preview, pitch, hold-to-preview and buy / apply.
class SkinDetailSheet extends ConsumerStatefulWidget {
  final SkinInfo skin;
  const SkinDetailSheet({super.key, required this.skin});

  static Future<void> show(BuildContext context, SkinInfo skin) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => SkinDetailSheet(skin: skin),
    );
  }

  @override
  ConsumerState<SkinDetailSheet> createState() => _SkinDetailSheetState();
}

class _SkinDetailSheetState extends ConsumerState<SkinDetailSheet> {
  final _preview = ThemePreview();
  bool _buying = false;

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _buy() async {
    setState(() => _buying = true);
    final ok = await ref
        .read(entitlementProvider.notifier)
        .buy(widget.skin.productId!);
    if (!mounted) return;
    setState(() => _buying = false);
    ok ? AppHaptics.success() : AppHaptics.error();
  }

  void _apply() {
    AppHaptics.selectionClick();
    ref.read(themeProvider.notifier).setTheme(widget.skin.mode);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final skin = widget.skin;
    final c = skin.colors;
    final owned = ownsSkin(ref.watch(entitlementProvider), skin);
    final active = ref.watch(themeProvider) == skin.mode;

    final String primaryLabel;
    final VoidCallback? onPrimary;
    if (active) {
      primaryLabel = 'ACTIVE';
      onPrimary = null;
    } else if (owned) {
      primaryLabel = 'APPLY';
      onPrimary = _apply;
    } else {
      primaryLabel = ref
          .read(entitlementProvider.notifier)
          .priceFor(skin.productId!);
      onPrimary = _buying ? null : _buy;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 12.0),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(28.0),
        border: Border.all(color: c.ink.withValues(alpha: 0.15), width: 1.5),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 128.0,
                        child: SkinMockup(
                          skin: skin,
                          borderColor: c.accent,
                          borderWidth: 2.0,
                          radius: 18.0,
                        ),
                      ),
                      const SizedBox(width: 16.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MODEL  ${skin.modelCode}',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 10.5,
                                letterSpacing: 1.6,
                                color: c.inkSoft,
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                skin.label,
                                style: TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 34.0,
                                  letterSpacing: 2.0,
                                  height: 1.1,
                                  color: c.accent,
                                ),
                              ),
                            ),
                            Text(
                              skin.tagline,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 15.0,
                                height: 1.2,
                                color: c.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12.0),
                  Text(
                    skin.description,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      height: 1.35,
                      color: c.inkSoft,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  // Hold to preview: finger down shows the calculator in
                  // this skin, lifting brings the sheet back.
                  Listener(
                    onPointerDown: (_) => _preview.show(context, skin),
                    onPointerUp: (_) => _preview.hide(),
                    onPointerCancel: (_) => _preview.hide(),
                    child: Container(
                      height: 46.0,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: c.ink.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(26.0),
                        border: Border.all(
                          color: c.ink.withValues(alpha: 0.18),
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        'HOLD TO PREVIEW',
                        style: TextStyle(
                          fontFamily: 'BebasNeue',
                          fontSize: 17.0,
                          letterSpacing: 1.6,
                          color: c.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10.0),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            height: 46.0,
                            child: Center(
                              child: Text(
                                'CLOSE',
                                style: TextStyle(
                                  fontFamily: 'BebasNeue',
                                  fontSize: 17.0,
                                  letterSpacing: 1.6,
                                  color: c.inkSoft,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: onPrimary,
                          child: Container(
                            height: 46.0,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: c.accent.withValues(
                                alpha: onPrimary == null ? 0.35 : 1.0,
                              ),
                              borderRadius: BorderRadius.circular(26.0),
                            ),
                            child: Text(
                              primaryLabel,
                              style: TextStyle(
                                fontFamily: 'BebasNeue',
                                fontSize: 18.0,
                                letterSpacing: 1.6,
                                color: c.bg,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
