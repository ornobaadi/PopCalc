// Renders preview sheets of the 3D numerals to build/numeral_preview/.
// Not an assertion test: run it to eyeball glyph and material changes.
//
//   flutter test test/tools/numeral_sheet_test.dart

import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popcalc/features/calculator/presentation/widgets/numeral3d/numeral_glyphs.dart';
import 'package:popcalc/features/calculator/presentation/widgets/numeral3d/numeral_renderer.dart';
import 'package:popcalc/features/calculator/presentation/widgets/numeral3d/vec_math.dart';

const _dpr = 2.0;

Future<void> _render(
  String name,
  Size size,
  Color bg,
  void Function(Canvas canvas, Size size) draw,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.scale(_dpr);
  canvas.drawRect(Offset.zero & size, Paint()..color = bg);
  draw(canvas, size);
  final image = await recorder
      .endRecording()
      .toImage((size.width * _dpr).round(), (size.height * _dpr).round());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  Directory('build/numeral_preview').createSync(recursive: true);
  File('build/numeral_preview/$name.png')
      .writeAsBytesSync(bytes!.buffer.asUint8List());
}

List<GlyphInstance> _line(
  String text, {
  required double scale,
  double y = 0,
  Quat Function(int i)? rotation,
}) {
  final layout = NumeralLayout.of(text)!;
  return [
    for (var i = 0; i < layout.glyphs.length; i++)
      GlyphInstance(
        glyph: layout.glyphs[i].glyph,
        position: Vec3(
          layout.glyphs[i].x * scale,
          y + (layout.glyphs[i].y - 0.5) * scale,
          0,
        ),
        rotation: rotation?.call(i) ?? Quat.identity,
        scale: scale,
      ),
  ];
}

void main() {
  testWidgets('render numeral preview sheets', (tester) async {
    await tester.runAsync(() async {
      final program =
          await ui.FragmentProgram.fromAsset('shaders/numeral3d.frag');
      final renderer = NumeralRenderer(program);

      const sheet = Size(900, 520);
      for (final (name, bg, material) in [
        ('sheet_pearl', const Color(0xFF141414), NumeralMaterial.pearl),
        ('sheet_lacquer', const Color(0xFFFFAE00), NumeralMaterial.lacquered),
      ]) {
        await _render(name, sheet, bg, (canvas, size) {
          renderer.paint(
            canvas,
            size,
            [
              ..._line('0123456789', scale: 150, y: 140),
              ..._line('12,345.6-+×÷%e', scale: 95, y: -30),
              ..._line(
                '25%',
                scale: 120,
                y: -175,
                rotation: (i) => Quat.axisAngle(
                  const Vec3(0.2, 1, 0),
                  (i - 1) * 0.55,
                ),
              ),
            ],
            material,
            devicePixelRatio: _dpr,
          );
        });
      }

      // Close-ups to judge the material.
      for (final (name, bg, material) in [
        ('hero_pearl', const Color(0xFF050505), NumeralMaterial.pearl),
        ('hero_lacquer', const Color(0xFFFFAE00), NumeralMaterial.lacquered),
      ]) {
        await _render(name, const Size(560, 440), bg, (canvas, size) {
          renderer.paint(
            canvas,
            size,
            [
              GlyphInstance(
                glyph: NumeralGlyph.of('6')!,
                position: const Vec3(-120, 0, 0),
                rotation: Quat.axisAngle(const Vec3(0.25, 1, 0), 0.62),
                scale: 330,
              ),
              GlyphInstance(
                glyph: NumeralGlyph.of('2')!,
                position: const Vec3(125, 0, 0),
                rotation: Quat.axisAngle(const Vec3(-0.3, 1, 0.05), -0.45),
                scale: 330,
              ),
            ],
            material,
            devicePixelRatio: _dpr,
          );
        });
      }

      // A spin sequence: one glyph at several yaw angles.
      await _render('spin', const Size(900, 240), const Color(0xFF141414),
          (canvas, size) {
        final glyph = NumeralGlyph.of('6')!;
        renderer.paint(
          canvas,
          size,
          [
            for (var i = 0; i < 7; i++)
              GlyphInstance(
                glyph: glyph,
                position: Vec3((i - 3) * 125.0, 0, 0),
                rotation: Quat.axisAngle(const Vec3(0, 1, 0), i * math.pi / 6),
                scale: 170,
              ),
          ],
          NumeralMaterial.pearl,
          devicePixelRatio: _dpr,
        );
      });
    });
  });
}
