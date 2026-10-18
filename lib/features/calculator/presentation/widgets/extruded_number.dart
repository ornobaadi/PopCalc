import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// Renders a thick, solid 3D extruded numeral block.
///
/// Every digit is its own little block: it turns on its own pivot by its
/// entry in [glyphTilts], its side wall swings round to the side it turned
/// away from, the walls brighten as they come to face the light, and a glint
/// slides across the face. With no tilt the number looks exactly as it
/// always has. The side wall is stamped from a cached texture of the glyphs
/// (one `drawAtlas` call per digit), so depth costs almost nothing per frame.
class ExtrudedNumber extends StatefulWidget {
  final String text;
  final double depth; // 0.0 (flat) to 1.0 (full depth)
  final ThemeColors colors;

  /// A fixed shift of the extrusion, in pixels, for the whole number.
  final Offset tilt;

  /// How far each digit (one entry per character) is turned, about −1.2..1.2
  /// on each axis: x leans it left/right, y forwards/back. Null or a missing
  /// entry: that digit faces straight on.
  final List<Offset>? glyphTilts;
  final bool isLite;
  final TextAlign textAlign;
  final bool isZero;

  /// How many leading characters are already in place. The rest are being
  /// typed in and turn into place as [enterProgress] goes from 0 to 1, while
  /// the settled digits stay perfectly still. Null: nothing is entering.
  final int? stableLength;
  final double enterProgress;

  /// Upper limit on the numeral's size. Words (an error's line) are set
  /// well below the size of a number, so they never pass for a result.
  final double maxFontSize;

  const ExtrudedNumber({
    super.key,
    required this.text,
    this.depth = 1.0,
    required this.colors,
    this.tilt = Offset.zero,
    this.glyphTilts,
    this.isLite = false,
    this.textAlign = TextAlign.center,
    this.isZero = false,
    this.stableLength,
    this.enterProgress = 1.0,
    this.maxFontSize = 200.0,
  });

  @override
  State<ExtrudedNumber> createState() => _ExtrudedNumberState();
}

class _ExtrudedNumberState extends State<ExtrudedNumber> {
  /// The size the numeral was last fitted to, to tell a small refit (one
  /// more digit: ease into it) from a new number altogether (snap).
  double? _lastFit;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final fit = _fitFontSize(widget.text, size, widget.maxFontSize);
          final last = _lastFit;
          _lastFit = fit;
          // A long number shrinks to fit. One digit's worth of shrinking is
          // eased so the block never snaps to a new size under the eye.
          final ease =
              !widget.isLite &&
              last != null &&
              fit / last > 0.7 &&
              fit / last < 1.4;

          return Opacity(
            opacity: widget.isZero ? 0.28 : 1.0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fit),
              duration: Duration(milliseconds: ease ? 140 : 0),
              curve: Curves.easeOutCubic,
              builder: (context, fontSize, _) => CustomPaint(
                size: size,
                painter: _ExtrudedNumberPainter(
                  text: widget.text,
                  fontSize: fontSize,
                  depth: widget.isZero ? 0.35 : widget.depth,
                  colors: widget.colors,
                  tilt: widget.tilt,
                  glyphTilts: widget.glyphTilts,
                  devicePixelRatio: dpr,
                  isLite: widget.isLite,
                  textAlign: widget.textAlign,
                  stableLength: widget.stableLength,
                  enterProgress: widget.enterProgress,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

const _baseStyle = TextStyle(
  fontFamily: 'BebasNeue',
  fontFamilyFallback: ['Antonio', 'sans-serif'],
  fontWeight: FontWeight.w400,
  letterSpacing: 1.0,
  height: 1.0,
);

TextPainter _layout(String text, TextStyle style) => TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
)..layout();

/// One cell of the halftone screen: a grey dot on nothing, tiled over the
/// numeral face. Drawn once.
final ui.Image _halftoneTile = () {
  const cell = 16.0;
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawCircle(
    const Offset(cell / 2, cell / 2),
    cell * 0.3,
    Paint()
      ..color = const Color(0xFF8C877C)
      ..isAntiAlias = true,
  );
  return recorder.endRecording().toImageSync(cell.toInt(), cell.toInt());
}();

// ─── Fit cache ────────────────────────────────────────────────────────────────
final _fitCache = <String, double>{};

/// The largest font size at which [text] fits [size].
double _fitFontSize(String text, Size size, double maxFontSize) {
  final key =
      '${text}_${size.width.toInt()}_${size.height.toInt()}_${maxFontSize.toInt()}';
  final cached = _fitCache[key];
  if (cached != null) return cached;

  var fontSize = (size.height * 0.88).clamp(64.0, 200.0);
  if (fontSize > maxFontSize) fontSize = maxFontSize;
  final width = _layout(text, _baseStyle.copyWith(fontSize: fontSize)).width;
  final maxAllowedWidth = size.width - 40.0;
  if (width > maxAllowedWidth && width > 0) {
    fontSize = (fontSize * maxAllowedWidth / width).clamp(40.0, 200.0);
  }

  if (_fitCache.length > 32) _fitCache.remove(_fitCache.keys.first);
  return _fitCache[key] = fontSize;
}

// ─── Layout Cache ─────────────────────────────────────────────────────────────
final _painterCache = <String, _LayoutCache>{};

class _LayoutCache {
  final TextPainter frontPainter;
  final TextPainter shadowPainter;
  final List<_Glyph> glyphs;

  _LayoutCache({required this.frontPainter, required this.shadowPainter})
    : glyphs = _glyphsOf(frontPainter);
}

/// One character of the numeral and the cell it occupies in the laid-out
/// line (x from the line's left edge, width up to the next character).
class _Glyph {
  final String char;
  final int index; // position among the characters
  final int start; // UTF-16 offset in the text
  final double x;
  final double width;

  const _Glyph(this.char, this.index, this.start, this.x, this.width);

  bool get isBlank => char.trim().isEmpty;
}

List<_Glyph> _glyphsOf(TextPainter painter) {
  final text = painter.text!.toPlainText();
  final glyphs = <_Glyph>[];
  var offset = 0;
  var index = 0;
  for (final char in text.characters) {
    final next = offset + char.length;
    final x = painter.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dx;
    final end = next >= text.length
        ? painter.width
        : painter.getOffsetForCaret(TextPosition(offset: next), Rect.zero).dx;
    glyphs.add(_Glyph(char, index, offset, x, (end - x).clamp(0.0, 9999.0)));
    offset = next;
    index++;
  }
  return glyphs;
}

/// Single-character painters (fronts and contact shadows), kept between
/// frames so a turning digit costs no text layout.
final _charCache = <String, TextPainter>{};

TextPainter _cachedChar(String key, TextPainter Function() build) {
  final hit = _charCache[key];
  if (hit != null) return hit;
  if (_charCache.length > 160) _charCache.remove(_charCache.keys.first);
  return _charCache[key] = build();
}

// ─── Side-wall atlas ──────────────────────────────────────────────────────────
/// White silhouettes of the glyphs, drawn once at about screen resolution.
/// The side wall is this texture stamped dozens of times, each stamp tinted
/// a step further from shadow to rim, in a single `drawAtlas` call.
class _SideAtlas {
  final ui.Image image;
  final Map<String, Rect> cells; // per character, in image pixels
  final double fontSize; // the size the silhouettes were drawn at
  final double pad; // margin round each glyph inside its cell

  _SideAtlas(this.image, this.cells, this.fontSize, this.pad);
}

final _atlasCache = <String, _SideAtlas>{};

_SideAtlas _atlasFor(String text, double rasterSize) {
  final chars = <String>{
    for (final c in text.characters)
      if (c.trim().isNotEmpty) c,
  };
  // A number keeps one atlas while it is typed: all ten digits go in.
  if (chars.any((c) => '0123456789'.contains(c))) {
    chars.addAll('0123456789'.split(''));
  }
  final sorted = chars.toList()..sort();
  final key = '${sorted.join()}@${rasterSize.toInt()}';
  final hit = _atlasCache[key];
  if (hit != null) return hit;

  final style = _baseStyle.copyWith(
    fontSize: rasterSize,
    letterSpacing: 0.0,
    color: const Color(0xFFFFFFFF),
  );
  final pad = (rasterSize * 0.08).ceilToDouble();
  final painters = [for (final c in sorted) _layout(c, style)];
  var cellW = 1.0;
  var cellH = 1.0;
  for (final p in painters) {
    if (p.width > cellW) cellW = p.width;
    if (p.height > cellH) cellH = p.height;
  }
  cellW = (cellW + pad * 2).ceilToDouble();
  cellH = (cellH + pad * 2).ceilToDouble();

  const cols = 6;
  final columns = sorted.length < cols ? sorted.length : cols;
  final rows = (sorted.length / cols).ceil();
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final cells = <String, Rect>{};
  for (var i = 0; i < sorted.length; i++) {
    final cell = Rect.fromLTWH((i % cols) * cellW, (i ~/ cols) * cellH, cellW, cellH);
    painters[i].paint(canvas, cell.topLeft + Offset(pad, pad));
    cells[sorted[i]] = cell;
  }
  final picture = recorder.endRecording();
  final image = picture.toImageSync(
    (columns * cellW).clamp(1.0, 8192.0).toInt(),
    (rows * cellH).clamp(1.0, 8192.0).toInt(),
  );
  picture.dispose();

  if (_atlasCache.length >= 3) {
    _atlasCache.remove(_atlasCache.keys.first)?.image.dispose();
  }
  return _atlasCache[key] = _SideAtlas(image, cells, rasterSize, pad);
}

final _atlasPaint = Paint()
  ..isAntiAlias = true
  ..filterQuality = FilterQuality.medium;

/// Where one digit sits this frame and how it is turned.
class _Pose {
  final _Glyph glyph;
  final Offset origin; // top left of the digit's face
  final Offset dir; // the extrusion, face to back
  final Offset pivot;
  final Offset tilt;
  final Matrix4? turn; // null: faces straight on, nothing to transform

  const _Pose(this.glyph, this.origin, this.dir, this.pivot, this.tilt, this.turn);
}

/// How far a fully tilted digit turns, in radians.
const double _maxGlyphTurn = 0.4;

/// Camera strength for a single digit. Stronger than a whole-screen
/// perspective because a digit is small: the near edge must visibly grow.
const double _glyphPerspective = 0.0018;

// ─── Painter ──────────────────────────────────────────────────────────────────
class _ExtrudedNumberPainter extends CustomPainter {
  final String text;
  final double fontSize;
  final double depth;
  final ThemeColors colors;
  final Offset tilt;
  final List<Offset>? glyphTilts;
  final double devicePixelRatio;
  final bool isLite;
  final TextAlign textAlign;
  final int? stableLength;
  final double enterProgress;

  _ExtrudedNumberPainter({
    required this.text,
    required this.fontSize,
    required this.depth,
    required this.colors,
    required this.tilt,
    required this.glyphTilts,
    required this.devicePixelRatio,
    required this.isLite,
    required this.textAlign,
    required this.stableLength,
    required this.enterProgress,
  });

  TextStyle get _style => _baseStyle.copyWith(fontSize: fontSize);

  String get _cacheKey =>
      '${text}_${fontSize.toStringAsFixed(1)}_${colors.extrudeTop.toARGB32()}_${colors.extrudeShadow.toARGB32()}';

  String get _sizeKey => fontSize.toStringAsFixed(2);

  /// Silhouettes are drawn at the numeral's size on screen, in steps of
  /// 32 px so an easing refit does not redraw them every frame.
  double get _rasterSize {
    final want = (fontSize * devicePixelRatio).clamp(48.0, 512.0);
    return (want / 32.0).ceil() * 32.0;
  }

  TextPainter _front(String run) =>
      _layout(run, _style.copyWith(color: colors.extrudeTop));

  // Soft ambient contact shadow
  TextPainter _shadow(String run) => _layout(
    run,
    _style.copyWith(
      foreground: Paint()
        ..color = colors.extrudeShadow
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18.0),
    ),
  );

  Offset _tiltOf(int index) {
    final tilts = glyphTilts;
    if (tilts == null || tilts.isEmpty) return Offset.zero;
    return index < tilts.length ? tilts[index] : tilts.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (text.isEmpty) return;

    final key = _cacheKey;
    final cache = _painterCache[key] ??= _LayoutCache(
      frontPainter: _front(text),
      shadowPainter: _shadow(text),
    );
    if (_painterCache.length > 16) {
      _painterCache.remove(_painterCache.keys.first);
    }

    final textWidth = cache.frontPainter.width;
    final textHeight = cache.frontPainter.height;

    // ── Extrusion direction ──
    // In lite mode, render completely flat with no 3D offset or extrusion.
    if (isLite) {
      final double startX = (textAlign == TextAlign.center)
          ? (size.width - textWidth) / 2
          : size.width - textWidth - 20.0;
      final double startY = (size.height - textHeight) / 2;
      final frontOffset = Offset(startX, startY);

      cache.frontPainter.paint(canvas, frontOffset);

      final finish = _finishShader(frontOffset & Size(textWidth, textHeight));
      if (finish != null) {
        _paintGlyphs(canvas, text, frontOffset, Paint()..shader = finish);
      }
      return;
    }

    // Base direction: lower-right (classic block-letter look), shifted by
    // the fixed [tilt]. Each digit then swings it further by its own turn.
    final double maxOffset = 18.0 * depth;
    final base = Offset(
      maxOffset * 0.55 + tilt.dx * 0.55,
      maxOffset * 0.82 + tilt.dy * 0.55,
    );

    // Centre the block on its resting extrusion, so a turning digit never
    // drags the whole number sideways.
    final double startX = (textAlign == TextAlign.center)
        ? (size.width - textWidth) / 2 - (base.dx * 0.5)
        : size.width - textWidth - maxOffset.abs() - 20.0;
    final double startY = (size.height - textHeight) / 2 - (base.dy * 0.5);

    final frontOffset = Offset(startX, startY);
    final face = frontOffset & Size(textWidth, textHeight);

    // Digits being typed in turn into place on their own; the ones already
    // there do not move for it.
    final stable = stableLength ?? -1;
    final entering =
        stable >= 0 && stable < text.length && enterProgress < 1.0;
    final enterT = Curves.easeOutCubic.transform(enterProgress.clamp(0.0, 1.0));

    final poses = <_Pose>[];
    for (final glyph in cache.glyphs) {
      if (glyph.isBlank) continue;
      final arriving = entering && glyph.start >= stable;
      final t = _tiltOf(glyph.index);

      // The wall swings with the turn: lean a digit left and its left side
      // comes into view.
      var dir = base + Offset(t.dx * maxOffset * 0.95, t.dy * maxOffset * 0.8);
      // Seen edge-on first, then turning to face the front as it thickens.
      final squeeze = arriving ? 0.35 + 0.65 * enterT : 1.0;
      if (arriving) dir = dir * (0.3 + 0.7 * enterT);

      final origin = frontOffset + Offset(glyph.x, 0.0);
      final pivot = origin + Offset(glyph.width / 2, textHeight / 2);
      final rotY = t.dx * _maxGlyphTurn;
      final rotX = -t.dy * _maxGlyphTurn;
      final turned = rotX.abs() > 1e-4 || rotY.abs() > 1e-4 || squeeze != 1.0;
      final matrix = turned
          ? (Matrix4.identity()
              ..setEntry(3, 2, _glyphPerspective)
              ..rotateX(rotX)
              ..rotateY(rotY)
              ..scaleByDouble(squeeze, 1.0, 1.0, 1.0))
          : null;
      poses.add(_Pose(glyph, origin, dir, pivot, t, matrix));
    }

    // Everything underneath first, then every wall, then every face: no
    // digit's shadow or wall ever falls across its neighbour's face.
    for (final pose in poses) {
      _posed(canvas, pose, () => _paintUnder(canvas, pose));
    }
    final atlas = _atlasFor(text, _rasterSize);
    for (final pose in poses) {
      _posed(canvas, pose, () => _paintWall(canvas, atlas, pose));
    }
    final finish = _finishShader(face);
    for (final pose in poses) {
      _posed(canvas, pose, () => _paintFace(canvas, pose, finish));
    }
  }

  /// Runs [draw] with the canvas turned to [pose] about the digit's centre.
  void _posed(Canvas canvas, _Pose pose, void Function() draw) {
    final m = pose.turn;
    if (m == null) {
      draw();
      return;
    }
    canvas.save();
    canvas.translate(pose.pivot.dx, pose.pivot.dy);
    canvas.transform(m.storage);
    canvas.translate(-pose.pivot.dx, -pose.pivot.dy);
    draw();
    canvas.restore();
  }

  /// What lies under a digit: the neon halo and the contact shadow.
  void _paintUnder(Canvas canvas, _Pose pose) {
    final char = pose.glyph.char;
    // ─── 0. Neon halo behind everything ───────────────────────────────────────
    if (colors.finish == SkinFinish.glow) {
      _paintGlyphs(
        canvas,
        char,
        pose.origin,
        Paint()
          ..color = colors.extrudeTop.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fontSize * 0.14),
      );
    }

    // ─── 1. Soft ambient contact drop shadow ──────────────────────────────────
    if (depth > 0.05) {
      _cachedChar(
        's|$char|$_sizeKey|${colors.extrudeShadow.toARGB32()}',
        () => _shadow(char),
      ).paint(canvas, pose.origin + pose.dir * 1.5);
    }
  }

  /// The digit's side wall: its silhouette stamped from the back to the
  /// face, shading from deep shadow to a lighter rim.
  void _paintWall(Canvas canvas, _SideAtlas atlas, _Pose pose) {
    final cell = atlas.cells[pose.glyph.char];
    if (cell == null) return;
    final dir = pose.dir;
    final steps = (dir.distance / 0.3).clamp(24, 72).toInt();

    // At rest the wall faces down-right, away from the light, and keeps
    // the skin's own colours. Turned towards the light it brightens.
    final len = dir.distance;
    final facing = len < 1e-3 ? 1.0 : (dir.dx * 0.55 + dir.dy * 0.83) / len;
    final lit = ((1.0 - facing) * 0.5).clamp(0.0, 1.0);
    final deepColor = Color.lerp(
      colors.extrudeSide,
      colors.extrudeTop,
      0.22 * lit,
    )!;
    final rimColor = Color.lerp(
      colors.extrudeSide,
      colors.extrudeTop,
      0.28 + 0.3 * lit,
    )!;

    final scale = fontSize / atlas.fontSize;
    final transforms = <ui.RSTransform>[];
    final rects = <Rect>[];
    final tints = <Color>[];
    for (int i = 0; i < steps; i++) {
      final t = i / (steps - 1.0);
      final at = pose.origin + dir * (1.0 - t);
      transforms.add(
        ui.RSTransform.fromComponents(
          rotation: 0.0,
          scale: scale,
          anchorX: atlas.pad,
          anchorY: atlas.pad,
          translateX: at.dx,
          translateY: at.dy,
        ),
      );
      rects.add(cell);
      tints.add(
        Color.lerp(deepColor, rimColor, Curves.easeInCubic.transform(t))!,
      );
    }
    canvas.drawAtlas(
      atlas.image,
      transforms,
      rects,
      tints,
      // White glyph times the tint: the tint, with the glyph's edges.
      BlendMode.modulate,
      null,
      _atlasPaint,
    );
  }

  /// The digit's face: front, material finish, glint and bevel. [finish]
  /// spans the whole numeral, so it runs unbroken across the digits.
  void _paintFace(Canvas canvas, _Pose pose, Shader? finish) {
    final char = pose.glyph.char;
    // ─── 3. Crisp front face numeral ──────────────────────────────────────────
    _cachedChar(
      'f|$char|$_sizeKey|${colors.extrudeTop.toARGB32()}',
      () => _front(char),
    ).paint(canvas, pose.origin);

    // ─── 3b. Material finish over the face ────────────────────────────────────
    if (finish != null) {
      _paintGlyphs(canvas, char, pose.origin, Paint()..shader = finish);
    }

    // ─── 3c. Glint sliding across a turning face ──────────────────────────────
    final glint = _glintShader(
      pose.origin & Size(pose.glyph.width, fontSize),
      pose.tilt,
    );
    if (glint != null) {
      _paintGlyphs(canvas, char, pose.origin, Paint()..shader = glint);
    }

    // ─── 4. Subtle bevel highlight at face rim ────────────────────────────────
    if (colors.extrudeChamfer != Colors.transparent) {
      _paintGlyphs(
        canvas,
        char,
        pose.origin,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.extrudeChamfer,
      );
    }
  }

  /// A soft band of light across a turned face, travelling against the
  /// turn as if the light stayed put. None at rest, so a still number looks
  /// as it always has, and none on finishes that carry their own light or
  /// must stay flat (neon, drafting lines, print).
  Shader? _glintShader(Rect cell, Offset t) {
    switch (colors.finish) {
      case SkinFinish.glow:
      case SkinFinish.wireframe:
      case SkinFinish.halftone:
        return null;
      default:
        break;
    }
    final strength = t.distance.clamp(0.0, 1.0);
    if (strength < 0.04) return null;
    final at = 0.5 - t.dx * 0.55 - t.dy * 0.25;
    final s0 = (at - 0.2).clamp(0.0, 1.0);
    final s1 = at.clamp(s0, 1.0);
    final s2 = (at + 0.2).clamp(s1, 1.0);
    const clear = Color(0x00FFFFFF);
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [clear, Colors.white.withValues(alpha: 0.32 * strength), clear],
      stops: [s0, s1, s2],
    ).createShader(cell);
  }

  /// Paints [run]'s glyphs once more with [paint], exactly over the front
  /// face (for finishes, glows and the bevel).
  void _paintGlyphs(Canvas canvas, String run, Offset offset, Paint paint) {
    _layout(run, _style.copyWith(foreground: paint)).paint(canvas, offset);
  }

  /// What a material's surface does to the flat face colour, as a gradient
  /// laid over the glyphs. Null for skins without a face finish.
  Shader? _finishShader(Rect face) {
    const clear = Color(0x00FFFFFF);
    switch (colors.finish) {
      case SkinFinish.matte:
        // Soft light from the top left, falling into shade: no hard edge.
        return const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x40FFFFFF), clear, Color(0x30000000)],
          stops: [0.0, 0.45, 1.0],
        ).createShader(face);
      case SkinFinish.mirror:
        // Chrome: bright sky, a dark horizon line, then lit ground.
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFAFC0D4),
            Color(0xFF252C38),
            Color(0xFF8792A0),
            Color(0xFFF4F7FA),
          ],
          stops: [0.0, 0.47, 0.5, 0.64, 1.0],
        ).createShader(face);
      case SkinFinish.glass:
        // Frosted pane: brightest along the top edge, a faint lift below.
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xE6FFFFFF),
            Color(0x55FFFFFF),
            clear,
            Color(0x38FFFFFF),
          ],
          stops: [0.0, 0.2, 0.62, 1.0],
        ).createShader(face);
      case SkinFinish.grain:
        // Wood grain: thin dark bands, slightly off level, repeating.
        return const LinearGradient(
          begin: Alignment(-0.12, -1.0),
          end: Alignment(0.12, 1.0),
          colors: [
            Color(0x003B1F0A),
            Color(0x473B1F0A),
            Color(0x003B1F0A),
            Color(0x263B1F0A),
            Color(0x003B1F0A),
          ],
          stops: [0.0, 0.3, 0.55, 0.8, 1.0],
          tileMode: TileMode.repeated,
        ).createShader(
          Rect.fromLTWH(face.left, face.top, face.width, face.height * 0.085),
        );
      case SkinFinish.gloss:
        // Hard candy: a wet highlight across the top that stops dead.
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xA6FFFFFF), Color(0x40FFFFFF), clear, clear],
          stops: [0.0, 0.4, 0.41, 1.0],
        ).createShader(face);
      case SkinFinish.glow:
        // Lit tube: white-hot through the middle, coloured at the edges.
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [clear, Color(0x8CFFFFFF), clear],
          stops: [0.12, 0.5, 0.88],
        ).createShader(face);
      case SkinFinish.halftone:
        // Printed dots, sized to the numeral so they read at any scale.
        final scale = (fontSize / 34.0) / _halftoneTile.width;
        return ui.ImageShader(
          _halftoneTile,
          TileMode.repeated,
          TileMode.repeated,
          (Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0)).storage,
        );
      case SkinFinish.standard:
      case SkinFinish.keycap:
      case SkinFinish.wireframe:
        return null;
    }
  }

  @override
  bool shouldRepaint(covariant _ExtrudedNumberPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.fontSize != fontSize ||
        oldDelegate.depth != depth ||
        oldDelegate.colors != colors ||
        oldDelegate.tilt != tilt ||
        !_sameTilts(oldDelegate.glyphTilts, glyphTilts) ||
        oldDelegate.devicePixelRatio != devicePixelRatio ||
        oldDelegate.isLite != isLite ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.stableLength != stableLength ||
        oldDelegate.enterProgress != enterProgress;
  }
}

bool _sameTilts(List<Offset>? a, List<Offset>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
