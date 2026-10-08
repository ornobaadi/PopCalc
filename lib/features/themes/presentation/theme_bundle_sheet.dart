import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/entitlement_store.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';

import 'theme_card.dart';
import 'theme_detail_sheet.dart';

/// Product sheet for the all-skins bundle, drawn in the colours of the skin
/// that was at the front of the carousel. Tapping a skin opens its own sheet.
class BundleDetailSheet extends ConsumerStatefulWidget {
  final SkinInfo tone;
  const BundleDetailSheet({super.key, required this.tone});

  static Future<void> show(BuildContext context, SkinInfo tone) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => BundleDetailSheet(tone: tone),
    );
  }

  @override
  ConsumerState<BundleDetailSheet> createState() => _BundleDetailSheetState();
}

class _BundleDetailSheetState extends ConsumerState<BundleDetailSheet> {
  bool _buying = false;

  Future<void> _buy() async {
    setState(() => _buying = true);
    final ok = await ref
        .read(entitlementProvider.notifier)
        .buy(kAllThemesProductId);
    if (!mounted) return;
    setState(() => _buying = false);
    ok ? AppHaptics.success() : AppHaptics.error();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.tone.colors;
    final skins = kSkins.where((s) => s.premium).toList();
    final owned = ref.watch(entitlementProvider);
    final ownsAll = skins.every((s) => ownsSkin(owned, s));

    final primaryLabel = ownsAll
        ? 'OWNED'
        : ref.read(entitlementProvider.notifier).priceFor(kAllThemesProductId);
    final onPrimary = ownsAll || _buying ? null : _buy;

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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18.0, 18.0, 18.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < skins.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8.0),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          AppHaptics.selectionClick();
                          SkinDetailSheet.show(context, skins[i]);
                        },
                        child: SkinMockup(
                          skin: skins[i],
                          borderColor: c.ink.withValues(alpha: 0.2),
                          radius: 12.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14.0),
              Text(
                '${skins.length} PREMIUM SKINS',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  letterSpacing: 1.6,
                  color: c.inkSoft,
                ),
              ),
              Text(
                'ALL SKINS BUNDLE',
                style: TextStyle(
                  fontFamily: 'BebasNeue',
                  fontSize: 34.0,
                  letterSpacing: 2.0,
                  height: 1.1,
                  color: c.accent,
                ),
              ),
              Text(
                'Every premium skin, one price.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15.0,
                  height: 1.2,
                  color: c.ink,
                ),
              ),
              const SizedBox(height: 8.0),
              Text(
                '${skins.map((s) => _title(s.label)).join(', ')}. '
                'Tap any of them above for a closer look and a full-screen '
                'preview.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  height: 1.35,
                  color: c.inkSoft,
                ),
              ),
              const SizedBox(height: 16.0),
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
      ),
    );
  }

  static String _title(String label) =>
      label[0] + label.substring(1).toLowerCase();
}
