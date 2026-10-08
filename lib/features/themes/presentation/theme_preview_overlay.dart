import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/theme/app_theme.dart';
import 'package:popcalc/core/theme/skin_catalog.dart';
import 'package:popcalc/features/calculator/presentation/calculator_screen.dart';

/// Full-screen "hold to preview": the real calculator, with whatever the
/// user has typed, drawn in another skin for as long as [show] is in effect.
/// The saved skin is never touched.
class ThemePreview {
  OverlayEntry? _entry;
  final _shown = ValueNotifier<bool>(false);

  void show(BuildContext context, SkinInfo skin) {
    if (_entry != null) return;
    _shown.value = false;
    final entry = OverlayEntry(
      builder: (_) =>
          _PreviewLayer(skin: skin, shown: _shown, onHidden: _remove),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_entry == entry) _shown.value = true;
    });
    AppHaptics.selectionClick();
  }

  void hide() {
    if (_entry == null) return;
    if (_shown.value) {
      _shown.value = false; // fades out, then removes itself
    } else {
      _remove();
    }
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void dispose() => _remove();
}

class _PreviewLayer extends StatelessWidget {
  final SkinInfo skin;
  final ValueNotifier<bool> shown;
  final VoidCallback onHidden;

  const _PreviewLayer({
    required this.skin,
    required this.shown,
    required this.onHidden,
  });

  @override
  Widget build(BuildContext context) {
    final colors = skin.colors;
    return IgnorePointer(
      child: ValueListenableBuilder<bool>(
        valueListenable: shown,
        builder: (context, visible, child) => AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          onEnd: () {
            if (!shown.value) onHidden();
          },
          child: AnimatedScale(
            scale: visible ? 1.0 : 1.04,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: child,
          ),
        ),
        child: ProviderScope(
          overrides: [
            themeProvider.overrideWith(
              (ref) => ThemeNotifier.preview(skin.mode),
            ),
          ],
          child: Stack(
            children: [
              const Positioned.fill(child: CalculatorScreen()),
              Align(
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10.0),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14.0,
                      vertical: 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent,
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Text(
                      'PREVIEWING ${skin.label}',
                      style: TextStyle(
                        fontFamily: 'BebasNeue',
                        fontSize: 15.0,
                        letterSpacing: 1.6,
                        color: colors.bg,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
