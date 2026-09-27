/// Metrics for PopCalc's custom 3D display numerals.
///
/// The outlines themselves are signed-distance functions in
/// `shaders/numeral3d.frag`. [id] selects one there, and the ink box
/// ([width], [bottom], [top]) must match that geometry. Units are em: the
/// cap height is 1 and the baseline is 0.
class NumeralGlyph {
  final int id;

  /// Ink width.
  final double width;
  final double bottom;
  final double top;

  /// Space on each side of the ink when laying out a string.
  final double bearing;

  const NumeralGlyph(
    this.id,
    this.width, {
    this.bottom = 0,
    this.top = 1,
    this.bearing = 0.045,
  });

  double get advance => width + 2 * bearing;

  /// Rotation pivot: the centre of the ink box.
  double get pivotX => width / 2;
  double get pivotY => (bottom + top) / 2;
  double get halfWidth => width / 2;
  double get halfHeight => (top - bottom) / 2;

  static const _glyphs = <String, NumeralGlyph>{
    '0': NumeralGlyph(0, 0.56),
    '1': NumeralGlyph(1, 0.42),
    '2': NumeralGlyph(2, 0.55),
    '3': NumeralGlyph(3, 0.55),
    '4': NumeralGlyph(4, 0.60),
    '5': NumeralGlyph(5, 0.55),
    '6': NumeralGlyph(6, 0.56),
    '7': NumeralGlyph(7, 0.52),
    '8': NumeralGlyph(8, 0.56),
    '9': NumeralGlyph(9, 0.56),
    '.': NumeralGlyph(10, 0.21, top: 0.21, bearing: 0.035),
    ',': NumeralGlyph(11, 0.21, bottom: -0.17, top: 0.21, bearing: 0.035),
    '-': NumeralGlyph(12, 0.40, bottom: 0.37, top: 0.535),
    '−': NumeralGlyph(12, 0.40, bottom: 0.37, top: 0.535),
    '+': NumeralGlyph(13, 0.52, bottom: 0.195, top: 0.715),
    '×': NumeralGlyph(14, 0.54, bottom: 0.185, top: 0.725),
    '÷': NumeralGlyph(15, 0.52, bottom: 0.14, top: 0.77),
    '%': NumeralGlyph(16, 0.80),
    'e': NumeralGlyph(17, 0.50, top: 0.74),
  };

  static NumeralGlyph? of(String char) => _glyphs[char];

  /// Whether every character of [text] has a 3D glyph.
  static bool supports(String text) =>
      text.isNotEmpty && text.split('').every(_glyphs.containsKey);
}

/// A glyph placed on the baseline of a laid-out string.
class PlacedGlyph {
  final String char;
  final NumeralGlyph glyph;

  /// Pivot x relative to the string's centre, in em.
  final double x;

  /// Pivot y above the baseline, in em.
  final double y;

  const PlacedGlyph(this.char, this.glyph, this.x, this.y);
}

class NumeralLayout {
  final List<PlacedGlyph> glyphs;

  /// Total advance width in em.
  final double width;

  const NumeralLayout(this.glyphs, this.width);

  /// Lays out [text] centred on x = 0. Returns null if any character has no
  /// 3D glyph.
  static NumeralLayout? of(String text) {
    if (!NumeralGlyph.supports(text)) return null;
    final chars = text.split('');
    var pen = 0.0;
    final placed = <(String, NumeralGlyph, double)>[];
    for (final c in chars) {
      final g = NumeralGlyph.of(c)!;
      placed.add((c, g, pen + g.bearing + g.pivotX));
      pen += g.advance;
    }
    final half = pen / 2;
    return NumeralLayout(
      [for (final (c, g, x) in placed) PlacedGlyph(c, g, x - half, g.pivotY)],
      pen,
    );
  }
}
