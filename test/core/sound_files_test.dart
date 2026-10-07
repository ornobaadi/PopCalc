import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/audio/app_sounds.dart';

void main() {
  test('every sound effect has a file in every pack', () {
    for (final pack in SoundPack.values) {
      for (final sfx in Sfx.values) {
        final path = 'assets/sounds/${pack.name}/${sfx.file}.wav';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  test('the launch sound ships outside the packs', () {
    expect(File('assets/sounds/launch.wav').existsSync(), isTrue);
  });

  test('file names are snake_case', () {
    expect(Sfx.bracketOpen.file, 'bracket_open');
    expect(Sfx.unitPick.file, 'unit_pick');
    expect(Sfx.digit3.file, 'digit_3');
    expect(Sfx.function.file, 'function');
  });
}
