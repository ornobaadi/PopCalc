import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

/// Renders a thick, solid 3D extruded numeral block.
/// The extrusion direction follows device tilt + touch drag for a natural
/// "physical object" feel. Sub-pixel stamping with a gradient-shaded side wall
/// gives the illusion of a real engraved block with zero visible staircase.
class ExtrudedNumber extends StatefulWidget {
  final String text;
  final double depth; // 0.0 (flat) to 1.0 (full depth)
  final ThemeColors colors;
  final Offset tilt;
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

  _LayoutCache({required this.frontPainter, required this.shadowPainter});
}

// ─── Painter ──────────────────────────────────────────────────────────────────
class _ExtrudedNumberPainter extends CustomPainter {
  final String text;
  final double fontSize;
  final double depth;
  final ThemeColors colors;
  final Offset tilt;
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
    required this.isLite,
    required this.textAlign,
    required this.stableLength,
    required this.enterProgress,
  });

  TextStyle get _style => _baseStyle.copyWith(fontSize: fontSize);

  String get _cacheKey =>
      '${text}_${fontSize.toStringAsFixed(1)}_${colors.extrudeTop.toARGB32()}_${colors.extrudeShadow.toARGB32()}';

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

    // Base direction: lower-right (classic block-letter look).
    // tilt.dx / tilt.dy are in [-12, 12] range from touch+sensor combined.
    // Tilt shifts the direction so as you tilt the device, the "light source"
    // appears to shift naturally — left/right and up/down.
    final double maxOffset = 18.0 * depth;

    // Natural base direction at rest: lower-right shadow
    final double baseDirX = maxOffset * 0.55;
    final double baseDirY = maxOffset * 0.82;

    // Tilt shifts the direction — normalised so tilt of ±12 ≈ ±half offset
    const double tiltInfluence = 0.55;
    final double dirX = baseDirX + (tilt.dx * tiltInfluence);
    final double dirY = baseDirY + (tilt.dy * tiltInfluence);
    final dir = Offset(dirX, dirY);

    // Center the text so the block appears centered in the widget
    final double startX = (textAlign == TextAlign.center)
        ? (size.width - textWidth) / 2 - (dirX * 0.5)
        : size.width - textWidth - maxOffset.abs() - 20.0;
    final double startY = (size.height - textHeight) / 2 - (dirY * 0.5);

    final frontOffset = Offset(startX, startY);
    final face = frontOffset & Size(textWidth, textHeight);

    // Digits being typed in turn into place on their own; the ones already
    // there do not move at all.
    final stable = stableLength;
    final entering =
        stable != null &&
        stable >= 0 &&
        stable < text.length &&
        enterProgress < 1.0;

    if (!entering) {
      _paintUnder(canvas, text, frontOffset, dir, cache.shadowPainter);
      _paintBody(canvas, text, frontOffset, dir, face, cache.frontPainter);
      return;
    }

    final settled = text.substring(0, stable);
    final arriving = text.substring(stable);
    final arrivingOffset =
        frontOffset + Offset(settled.isEmpty ? 0.0 : _front(settled).width, 0);
    final arrivingFront = _front(arriving);

    final t = Curves.easeOutCubic.transform(enterProgress.clamp(0.0, 1.0));
    // Seen edge-on first, then turning to face the front as it thickens.
    final turn = 0.35 + 0.65 * t;
    final arrivingDir = dir * (0.3 + 0.7 * t);
    final pivotX = arrivingOffset.dx + arrivingFront.width / 2;

    void turned(void Function() draw) {
      canvas.save();
      canvas.translate(pivotX, 0);
      canvas.scale(turn, 1.0);
      canvas.translate(-pivotX, 0);
      draw();
      canvas.restore();
    }

    // Everything that sits underneath first, so no digit's shadow falls
    // across its neighbour's face.
    if (settled.isNotEmpty) _paintUnder(canvas, settled, frontOffset, dir, null);
    turned(() => _paintUnder(canvas, arriving, arrivingOffset, arrivingDir, null));
    if (settled.isNotEmpty) {
      _paintBody(canvas, settled, frontOffset, dir, face, null);
    }
    turned(
      () => _paintBody(
        canvas,
        arriving,
        arrivingOffset,
        arrivingDir,
        face,
        arrivingFront,
      ),
    );
  }

  /// What lies under a run of digits: the neon halo and the contact shadow.
  void _paintUnder(
    Canvas canvas,
    String run,
    Offset offset,
    Offset dir,
    TextPainter? shadow,
  ) {
    // ─── 0. Neon halo behind everything ───────────────────────────────────────
    if (colors.finish == SkinFinish.glow) {
      _paintGlyphs(
        canvas,
        run,
        offset,
        Paint()
          ..color = colors.extrudeTop.withValues(alpha: 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, fontSize * 0.14),
      );
    }

    // ─── 1. Soft ambient contact drop shadow ──────────────────────────────────
    if (depth > 0.05) {
      (shadow ?? _shadow(run)).paint(canvas, offset + dir * 1.5);
    }
  }

  /// The block itself: side wall, front face, material finish and bevel.
  /// [face] is the whole numeral's face, so a finish runs unbroken across
  /// digits painted in separate runs.
  void _paintBody(
    Canvas canvas,
    String run,
    Offset offset,
    Offset dir,
    Rect face,
    TextPainter? front,
  ) {
    // ─── 2. Gradient-shaded 3D block wall ─────────────────────────────────────
    // Sub-pixel stamping with gradient colour lerp creates smooth bevel.
    // t=0 (far layers): deep shadow colour
    // t=1 (near face):  slightly lighter rim, mimicking a real thick block edge
    final int steps = (dir.distance / 0.28).clamp(36, 64).toInt();

    final Color deepColor = colors.extrudeSide;
    final Color rimColor = Color.lerp(
      colors.extrudeSide,
      colors.extrudeTop,
      0.28,
    )!;

    for (int i = 0; i < steps; i++) {
      final t = i / (steps - 1.0);
      final lerpT = Curves.easeInCubic.transform(t);
      _layout(
        run,
        _style.copyWith(color: Color.lerp(deepColor, rimColor, lerpT)!),
      ).paint(canvas, offset + dir * (1.0 - t));
    }

    // ─── 3. Crisp front face numeral ──────────────────────────────────────────
    (front ?? _front(run)).paint(canvas, offset);

    // ─── 3b. Material finish over the face ────────────────────────────────────
    final finish = _finishShader(face);
    if (finish != null) {
      _paintGlyphs(canvas, run, offset, Paint()..shader = finish);
    }

    // ─── 4. Subtle bevel highlight at face rim ────────────────────────────────
    if (colors.extrudeChamfer != Colors.transparent) {
      _paintGlyphs(
        canvas,
        run,
        offset,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = colors.extrudeChamfer,
      );
    }
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
        oldDelegate.isLite != isLite ||
        oldDelegate.textAlign != textAlign ||
        oldDelegate.stableLength != stableLength ||
        oldDelegate.enterProgress != enterProgress;
  }
}
