import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/core/quick_tile/quick_tile.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('popcalc/qs_tile');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  Future<QuickTileResult> answer(int? code) {
    messenger.setMockMethodCallHandler(channel, (_) async => code);
    return QuickTile.request();
  }

  test("Android's answers map to what Settings says", () async {
    expect(await answer(2), QuickTileResult.added);
    expect(await answer(1), QuickTileResult.alreadyAdded);
    expect(await answer(0), QuickTileResult.declined);
    expect(await answer(-100), QuickTileResult.manual); // before Android 13
    expect(await answer(-3), QuickTileResult.manual); // a failure
  });

  test('no native side: the manual steps', () async {
    expect(await QuickTile.request(), QuickTileResult.manual);
    expect(QuickTile.noteFor(QuickTileResult.manual), contains('pencil'));
  });

  test('the tile service is declared with its permission and icon', () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('.PopCalcTileService'));
    expect(manifest, contains('android.permission.BIND_QUICK_SETTINGS_TILE'));
    expect(manifest,
        contains('android.service.quicksettings.action.QS_TILE'));
    expect(File('android/app/src/main/res/drawable/ic_qs_popcalc.xml')
        .existsSync(), isTrue);
    expect(
        File('android/app/src/main/kotlin/com/ornobaadi/popcalc/'
                'PopCalcActivity.kt')
            .readAsStringSync(),
        contains('popcalc/qs_tile'));
  });
}
