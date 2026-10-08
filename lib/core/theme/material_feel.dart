import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:popcalc/core/audio/app_sounds.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/storage/settings_store.dart';

import 'app_theme.dart';
import 'skin_catalog.dart';

/// The sound and haptics that go with the active skin: a material's own
/// feel, or null for an ordinary skin (the user's sound pack and the
/// standard haptics then apply).
final materialFeelProvider = Provider<MaterialFeel?>((ref) {
  final skin = skinOf(ref.watch(themeProvider));
  final mechSwitch = ref.watch(settingsProvider.select((s) => s.mechSwitch));
  return skin.feelFor(mechSwitch);
});

/// Points the sound and haptic engines at [feel]. Safe to call repeatedly.
void applyMaterialFeel(MaterialFeel? feel) {
  AppSounds.setMaterial(feel?.soundFolder);
  AppHaptics.feel = feel?.haptics ?? HapticFeel.standard;
}
