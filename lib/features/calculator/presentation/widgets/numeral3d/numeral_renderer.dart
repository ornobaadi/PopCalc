import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'numeral_glyphs.dart';
import 'vec_math.dart';

/// Surface look of the 3D numerals.
class NumeralMaterial {
  final Color face;
  final Color side;

  /// Tint of the studio environment seen in reflections.
  final Color env;

  /// Edge rounding radius, em.
  final double bevel;

  /// Half the extrusion thickness, em.
  final double halfDepth;

  /// 0-1 thin-film rainbow on the bevels.
  final double iridescence;

  /// 0-1 tightness and strength of the specular highlight.
  final double gloss;

  /// 0-1 extra clear-coat reflection, for dark glossy materials.
  final double lacquer;

  const NumeralMaterial({
    required this.face,
    required this.side,
    required this.env,
    this.bevel = 0.06,
    this.halfDepth = 0.12,
    this.iridescence = 0.8,
    this.gloss = 0.7,
    this.lacquer = 0.0,
  });

  /// Pearl-white plastic with rainbow bevels.
  static const pearl = NumeralMaterial(
    face: Color(0xFFF2F2F2),
    side: Color(0xFFD8D8DE),
    env: Color(0xFFFFFFFF),
  );

  /// Glossy espresso lacquer with warm reflections.
  static const lacquered = NumeralMaterial(
    face: Color(0xFF1C140D),
    side: Color(0xFF2B1E14),
    env: Color(0xFFFFD9A0),
    iridescence: 0.45,
    gloss: 0.92,
    lacquer: 1.0,
  );
}

/// One glyph to draw, already placed in world space.
class GlyphInstance {
  final NumeralGlyph glyph;

  /// Pivot position in world units (logical px, origin at the canvas centre,
  /// y up, z towards the viewer).
  final Vec3 position;
  final Quat rotation;

  /// Logical pixels per em.
  final double scale;
  final double opacity;

  const GlyphInstance({
    required this.glyph,
    required this.position,
    required this.rotation,
    required this.scale,
    this.opacity = 1.0,
  });
}

/// Draws [GlyphInstance]s with the raymarching numeral shader: one rect per
/// glyph, covering only its projected bounds, back to front.
class NumeralRenderer {
  NumeralRenderer(this._program);

  final ui.FragmentProgram _program;

  /// One shader per glyph: some backends read uniforms at raster time, so a
  /// shared shader would draw every glyph with the last glyph's uniforms.
  final List<_GlyphShader> _pool = [];

  /// Distance from the camera to the canvas plane, in logical px. Smaller
  /// means stronger perspective.
  static const double cameraDistance = 900;

  void paint(
    Canvas canvas,
    Size size,
    List<GlyphInstance> glyphs,
    NumeralMaterial material, {
    required double devicePixelRatio,
  }) {
    if (glyphs.isEmpty) return;

    // Far glyphs first so nearer ones blend over them.
    final order = [...glyphs]
      ..sort((a, b) => a.position.z.compareTo(b.position.z));

    var used = 0;
    for (final g in order) {
      if (g.opacity <= 0.002 || g.scale <= 0.5) continue;
      final bounds = _projectedBounds(g, size, material.halfDepth);
      if (bounds == null || bounds.isEmpty) continue;

      if (used == _pool.length) _pool.add(_GlyphShader(_program));
      final sh = _pool[used++];
      sh.size.set(size.width, size.height);
      sh.cam.set(cameraDistance, devicePixelRatio, 0, 0);
      sh.mat.set(
        material.bevel,
        material.iridescence,
        material.gloss,
        material.lacquer,
      );
      _setLinear(sh.face, material.face);
      _setLinear(sh.side, material.side);
      _setLinear(sh.env, material.env);
      final gl = g.glyph;
      sh.glyph.set(gl.id.toDouble(), g.scale, g.opacity, material.halfDepth);
      sh.box.set(gl.pivotX, gl.pivotY, gl.halfWidth, gl.halfHeight);
      sh.pos.set(g.position.x, g.position.y, g.position.z);
      final m = g.rotation.toMat3();
      sh.rot.set(m[0], m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8]);
      canvas.drawRect(bounds, sh.paint);
    }
  }

  /// The shader lights in linear space.
  static void _setLinear(ui.UniformVec3Slot slot, Color c) {
    double lin(double v) => math.pow(v, 2.2).toDouble();
    slot.set(lin(c.r), lin(c.g), lin(c.b));
  }

  /// Screen rect covering the glyph's rotated ink box, or null when it is
  /// off screen.
  Rect? _projectedBounds(GlyphInstance g, Size size, double halfDepth) {
    const d = cameraDistance;
    final hx = (g.glyph.halfWidth + 0.03) * g.scale;
    final hy = (g.glyph.halfHeight + 0.03) * g.scale;
    final hz = (halfDepth + 0.03) * g.scale;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (var i = 0; i < 8; i++) {
      final corner = Vec3(
        (i & 1) == 0 ? -hx : hx,
        (i & 2) == 0 ? -hy : hy,
        (i & 4) == 0 ? -hz : hz,
      );
      final p = g.position + g.rotation.rotate(corner);
      final depth = d - p.z;
      // Too close to (or behind) the camera to project: fill the canvas.
      if (depth < d * 0.1) return Offset.zero & size;
      final s = d / depth;
      final sx = size.width / 2 + p.x * s;
      final sy = size.height / 2 - p.y * s;
      minX = math.min(minX, sx);
      maxX = math.max(maxX, sx);
      minY = math.min(minY, sy);
      maxY = math.max(maxY, sy);
    }
    final rect = Rect.fromLTRB(minX - 2, minY - 2, maxX + 2, maxY + 2);
    // Glyphs may pop a little past the canvas, but never far.
    final limit = (Offset.zero & size).inflate(size.shortestSide * 0.5);
    final clipped = rect.intersect(limit);
    return clipped.width <= 0 || clipped.height <= 0 ? null : clipped;
  }
}

class _GlyphShader {
  _GlyphShader(ui.FragmentProgram program) : shader = program.fragmentShader() {
    size = shader.getUniformVec2('uSize');
    cam = shader.getUniformVec4('uCam');
    glyph = shader.getUniformVec4('uGlyph');
    box = shader.getUniformVec4('uBox');
    pos = shader.getUniformVec3('uPos');
    rot = shader.getUniformMat3('uRot');
    mat = shader.getUniformVec4('uMat');
    face = shader.getUniformVec3('uFace');
    side = shader.getUniformVec3('uSide');
    env = shader.getUniformVec3('uEnv');
    paint = Paint()..shader = shader;
  }

  final ui.FragmentShader shader;
  late final ui.UniformVec2Slot size;
  late final ui.UniformVec4Slot cam, glyph, box, mat;
  late final ui.UniformVec3Slot pos, face, side, env;
  late final ui.UniformMat3Slot rot;
  late final Paint paint;
}
