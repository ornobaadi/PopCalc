#version 460 core
#include <flutter/runtime_effect.glsl>

precision highp float;

// PopCalc 3D numerals.
//
// Each glyph is drawn with its own rect and its own uniforms. The glyph's
// outline is a 2D signed distance function (the custom PopCalc display
// face below), extruded into a solid with rounded edges and raymarched with a
// real perspective camera, so it can be viewed from any angle.
//
// World space: logical pixels, origin at the canvas centre, y up, z towards
// the camera. Glyph space: em units (cap height = 1), origin at the glyph's
// pivot, front face on +z.

uniform vec2 uSize;   // canvas size (logical px)
uniform vec4 uCam;    // x: camera distance (px), y: device pixel ratio
uniform vec4 uGlyph;  // x: glyph id, y: px per em, z: opacity, w: half thickness (em)
uniform vec4 uBox;    // xy: pivot in design space (em), zw: ink half extents (em)
uniform vec3 uPos;    // pivot position (world px)
uniform mat3 uRot;    // glyph space -> world rotation
uniform vec4 uMat;    // x: bevel radius (em), y: iridescence, z: gloss, w: lacquer (dark gloss) amount
uniform vec3 uFace;   // front/back face albedo
uniform vec3 uSide;   // side wall albedo
uniform vec3 uEnv;    // reflection environment tint

out vec4 fragColor;

// ─── Design constants ────────────────────────────────────────────────────────

const float S = 0.205; // vertical stroke weight
const float T = 0.175; // horizontal stroke weight
const float RO = 0.21; // outer corner radius of bowls

// ─── 2D distance primitives (design space: baseline y = 0, cap height 1) ───

float box(vec2 p, vec2 lo, vec2 hi) {
  vec2 d = abs(p - 0.5 * (lo + hi)) - 0.5 * (hi - lo);
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float rbox(vec2 p, vec2 lo, vec2 hi, float r) {
  vec2 d = abs(p - 0.5 * (lo + hi)) - 0.5 * (hi - lo) + r;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - r;
}

// Per-corner radii: x top-right, y bottom-right, z top-left, w bottom-left.
float rbox4(vec2 p, vec2 lo, vec2 hi, vec4 r) {
  vec2 q = p - 0.5 * (lo + hi);
  vec2 rr = q.x > 0.0 ? r.xy : r.zw;
  float rad = q.y > 0.0 ? rr.x : rr.y;
  vec2 d = abs(q) - 0.5 * (hi - lo) + rad;
  return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0) - rad;
}

// Stadium: a box with fully rounded short ends.
float pill(vec2 p, vec2 lo, vec2 hi) {
  vec2 h = 0.5 * (hi - lo);
  return rbox(p, lo, hi, min(h.x, h.y));
}

// Signed distance to the line a->b; positive on its left.
float lineSide(vec2 p, vec2 a, vec2 b) {
  vec2 e = normalize(b - a);
  vec2 w = p - a;
  return e.x * w.y - e.y * w.x;
}

void polyEdge(vec2 p, vec2 vi, vec2 vj, inout float d, inout float s) {
  vec2 e = vj - vi;
  vec2 w = p - vi;
  vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
  d = min(d, dot(b, b));
  bool c1 = p.y >= vi.y;
  bool c2 = p.y < vj.y;
  bool c3 = e.x * w.y > e.y * w.x;
  if ((c1 && c2 && c3) || (!c1 && !c2 && !c3)) {
    s = -s;
  }
}

// Exact distance to a quadrilateral.
float poly4(vec2 p, vec2 a, vec2 b, vec2 c, vec2 d) {
  float dd = dot(p - a, p - a);
  float s = 1.0;
  polyEdge(p, a, d, dd, s);
  polyEdge(p, b, a, dd, s);
  polyEdge(p, c, b, dd, s);
  polyEdge(p, d, c, dd, s);
  return s * sqrt(dd);
}

// ─── The PopCalc display face ────────────────────────────────────────────────
// Condensed and heavy: squircle bowls, pill-shaped counters, angled
// terminals. Ink boxes must match NumeralGlyph in numeral_glyphs.dart.

float g0(vec2 p) {
  float o = rbox(p, vec2(0.0), vec2(0.56, 1.0), RO);
  float c = pill(p, vec2(S, T), vec2(0.56 - S, 1.0 - T));
  return max(o, -c);
}

float g1(vec2 p) {
  float stem = box(p, vec2(0.42 - S, 0.0), vec2(0.42, 1.0));
  float flag = poly4(p, vec2(0.0, 0.63), vec2(0.23, 0.76), vec2(0.23, 1.0), vec2(0.0, 0.85));
  return min(stem, flag);
}

float g2(vec2 p) {
  const float W = 0.55;
  float arch = max(rbox(p, vec2(0.0, 0.36), vec2(W, 1.0), RO),
                   -pill(p, vec2(S, 0.36 + T), vec2(W - S, 1.0 - T)));
  // Left terminal.
  arch = max(arch, -max(p.x - W * 0.5, lineSide(p, vec2(0.0, 0.62), vec2(W * 0.5, 0.73))));
  // Right side hands over to the spine.
  vec2 b = vec2(0.285, 0.09);
  vec2 c = vec2(W, 0.70);
  arch = max(arch, -max(W * 0.5 - p.x, lineSide(p, b, c)));
  float spine = poly4(p, vec2(0.0, 0.09), b, c, vec2(W - S, 0.80));
  float base = box(p, vec2(0.0), vec2(W, T));
  return min(min(arch, spine), base);
}

float g3(vec2 p) {
  const float W = 0.55;
  float up = max(rbox(p, vec2(0.015, 0.46), vec2(W - 0.01, 1.0), RO * 0.92),
                 -pill(p, vec2(S + 0.015, 0.46 + T), vec2(W - 0.01 - S, 1.0 - T)));
  float lo = max(rbox(p, vec2(0.0), vec2(W, 0.64), RO),
                 -pill(p, vec2(S, T), vec2(W - S, 0.64 - T)));
  float gap = poly4(p, vec2(-0.1, 0.31), vec2(S + 0.02, 0.25), vec2(S + 0.02, 0.76), vec2(-0.1, 0.68));
  return max(min(up, lo), -gap);
}

float g4(vec2 p) {
  const float W = 0.60;
  float stem = box(p, vec2(W - 0.05 - S, 0.0), vec2(W - 0.05, 1.0));
  float bar = box(p, vec2(0.0, 0.2), vec2(W, 0.2 + T));
  float diag = poly4(p, vec2(0.0, 0.29), vec2(0.175, 0.29), vec2(W - 0.05, 1.0), vec2(W - 0.05 - S, 1.0));
  return min(min(stem, bar), diag);
}

float g5(vec2 p) {
  const float W = 0.55;
  float top = box(p, vec2(0.03, 1.0 - T), vec2(W - 0.01, 1.0));
  float stem = poly4(p, vec2(0.0, 0.465), vec2(S, 0.465), vec2(S + 0.03, 1.0), vec2(0.03, 1.0));
  float bowl = max(rbox4(p, vec2(0.0), vec2(W, 0.64), vec4(RO, RO, 0.0, RO)),
                   -pill(p, vec2(S, T), vec2(W - S, 0.64 - T)));
  float gap = poly4(p, vec2(-0.1, 0.31), vec2(S + 0.02, 0.25), vec2(S + 0.02, 0.465), vec2(-0.1, 0.465));
  return min(min(top, stem), max(bowl, -gap));
}

float g6(vec2 p) {
  const float W = 0.56;
  float bowl = max(rbox(p, vec2(0.0), vec2(W, 0.64), RO),
                   -pill(p, vec2(S, T), vec2(W - S, 0.64 - T)));
  float hook = max(rbox(p, vec2(0.0), vec2(W, 1.0), RO),
                   -rbox(p, vec2(S, T), vec2(W - S, 1.0 - T), 0.05));
  hook = max(hook, -max(W * 0.45 - p.x, lineSide(p, vec2(0.0, 0.83), vec2(1.0, 0.634))));
  return min(bowl, hook);
}

float g7(vec2 p) {
  const float W = 0.52;
  float top = box(p, vec2(0.0, 1.0 - T), vec2(W, 1.0));
  float stem = poly4(p, vec2(0.07, 0.0), vec2(0.285, 0.0), vec2(W, 1.0 - T * 0.5), vec2(W - 0.215, 1.0 - T * 0.5));
  return min(top, stem);
}

float g8(vec2 p) {
  const float W = 0.56;
  float up = max(rbox(p, vec2(0.025, 0.46), vec2(W - 0.025, 1.0), RO * 0.9),
                 -pill(p, vec2(S + 0.02, 0.46 + T), vec2(W - S - 0.02, 1.0 - T)));
  float lo = max(rbox(p, vec2(0.0), vec2(W, 0.64), RO),
                 -pill(p, vec2(S, T), vec2(W - S, 0.64 - T)));
  return min(up, lo);
}

float g9(vec2 p) {
  return g6(vec2(0.56, 1.0) - p);
}

float gDot(vec2 p) {
  return rbox(p, vec2(0.0), vec2(0.21, 0.21), 0.05);
}

float gComma(vec2 p) {
  float dot = rbox(p, vec2(0.0), vec2(0.21, 0.21), 0.05);
  float tail = poly4(p, vec2(0.09, 0.05), vec2(0.21, 0.05), vec2(0.11, -0.17), vec2(0.0, -0.17));
  return min(dot, tail);
}

float gMinus(vec2 p) {
  return rbox(p, vec2(0.0, 0.37), vec2(0.40, 0.535), 0.02);
}

float gPlus(vec2 p) {
  return min(box(p, vec2(0.0, 0.375), vec2(0.52, 0.535)),
             box(p, vec2(0.18, 0.195), vec2(0.34, 0.715)));
}

float gTimes(vec2 p) {
  vec2 q = p - vec2(0.27, 0.455);
  q = vec2(q.x + q.y, q.y - q.x) * 0.70710678;
  return min(box(q, vec2(-0.30, -0.08), vec2(0.30, 0.08)),
             box(q, vec2(-0.08, -0.30), vec2(0.08, 0.30)));
}

float gDivide(vec2 p) {
  float bar = box(p, vec2(0.0, 0.375), vec2(0.52, 0.535));
  float d1 = rbox(p, vec2(0.18, 0.61), vec2(0.34, 0.77), 0.04);
  float d2 = rbox(p, vec2(0.18, 0.14), vec2(0.34, 0.30), 0.04);
  return min(bar, min(d1, d2));
}

float gPercent(vec2 p) {
  const float W = 0.80;
  float r1 = max(rbox(p, vec2(0.0, 0.50), vec2(0.30, 1.0), 0.13),
                 -pill(p, vec2(0.10, 0.60), vec2(0.20, 0.90)));
  float r2 = max(rbox(p, vec2(W - 0.30, 0.0), vec2(W, 0.50), 0.13),
                 -pill(p, vec2(W - 0.20, 0.10), vec2(W - 0.10, 0.40)));
  float slash = poly4(p, vec2(0.10, 0.0), vec2(0.25, 0.0), vec2(W - 0.10, 1.0), vec2(W - 0.25, 1.0));
  return min(min(r1, r2), slash);
}

float gE(vec2 p) {
  const float W = 0.50;
  const float H = 0.74;
  float d = max(rbox(p, vec2(0.0), vec2(W, H), RO * 0.9),
                -pill(p, vec2(S * 0.95, 0.47), vec2(W - S * 0.95, H - T * 0.92)));
  float lower = poly4(p, vec2(S * 0.95, T * 0.92), vec2(W + 0.1, 0.26), vec2(W + 0.1, 0.33), vec2(S * 0.95, 0.33));
  return max(d, -lower);
}

float glyph2D(vec2 p) {
  float id = uGlyph.x;
  if (id < 0.5) return g0(p);
  if (id < 1.5) return g1(p);
  if (id < 2.5) return g2(p);
  if (id < 3.5) return g3(p);
  if (id < 4.5) return g4(p);
  if (id < 5.5) return g5(p);
  if (id < 6.5) return g6(p);
  if (id < 7.5) return g7(p);
  if (id < 8.5) return g8(p);
  if (id < 9.5) return g9(p);
  if (id < 10.5) return gDot(p);
  if (id < 11.5) return gComma(p);
  if (id < 12.5) return gMinus(p);
  if (id < 13.5) return gPlus(p);
  if (id < 14.5) return gTimes(p);
  if (id < 15.5) return gDivide(p);
  if (id < 16.5) return gPercent(p);
  return gE(p);
}

// ─── 3D solid ────────────────────────────────────────────────────────────────

// The glyph outline extruded to +-uGlyph.w, with every edge rounded by the
// bevel radius.
float map(vec3 p) {
  float r = uMat.x;
  float d2 = glyph2D(p.xy + uBox.xy);
  vec2 w = vec2(d2 + r, abs(p.z) - uGlyph.w + r);
  return min(max(w.x, w.y), 0.0) + length(max(w, 0.0)) - r;
}

vec3 calcNormal(vec3 p, float h) {
  const vec2 k = vec2(1.0, -1.0);
  return normalize(k.xyy * map(p + k.xyy * h) +
                   k.yyx * map(p + k.yyx * h) +
                   k.yxy * map(p + k.yxy * h) +
                   k.xxx * map(p + k.xxx * h));
}

float calcAO(vec3 p, vec3 n) {
  float occ = 0.0;
  float sca = 1.0;
  for (int i = 0; i < 3; i++) {
    float h = 0.03 + 0.07 * float(i);
    occ += (h - map(p + n * h)) * sca;
    sca *= 0.75;
  }
  return clamp(1.0 - 2.2 * occ, 0.0, 1.0);
}

// Ray vs axis-aligned box centred on the origin: (tNear, tFar).
vec2 boxHit(vec3 ro, vec3 rd, vec3 h) {
  vec3 safe = vec3(abs(rd.x) < 1e-6 ? 1e-6 : rd.x,
                   abs(rd.y) < 1e-6 ? 1e-6 : rd.y,
                   abs(rd.z) < 1e-6 ? 1e-6 : rd.z);
  vec3 m = 1.0 / safe;
  vec3 n = m * ro;
  vec3 k = abs(m) * h;
  vec3 t1 = -n - k;
  vec3 t2 = -n + k;
  return vec2(max(max(t1.x, t1.y), t1.z), min(min(t2.x, t2.y), t2.z));
}

// ─── Lighting ────────────────────────────────────────────────────────────────

const vec3 KEY_DIR = vec3(-0.45, 0.70, 0.55);
const vec3 FILL_DIR = vec3(0.80, -0.10, 0.60);

// A photo studio, in linear light: a big soft box up-left, a strip light on
// the right, a ring of light around the horizon and a dark floor. [rough]
// widens every light, like a blurrier reflection would.
vec3 studio(vec3 r, float rough) {
  float soft = mix(0.015, 0.2, rough);
  float sky = smoothstep(-0.2, 1.0, r.y);
  float floorDark = smoothstep(-0.7, 0.0, r.y);
  float key = smoothstep(0.90 - soft, 0.94 + soft * 0.3, dot(r, normalize(KEY_DIR)));
  float strip = smoothstep(0.95 - soft, 0.975, dot(r, normalize(vec3(0.9, 0.12, 0.42))));
  float ring = 1.0 - smoothstep(0.03, 0.10 + soft, abs(r.y - 0.18));
  vec3 col = vec3(0.03 + 0.7 * sky * sky) * floorDark;
  col += 4.0 * key + 2.2 * strip + 0.7 * ring * floorDark;
  return col * uEnv;
}

// Thin-film interference: the hue cycles with the viewing angle, painting
// rainbow bands across rounded bevels.
vec3 thinFilm(float x) {
  return clamp(0.5 + 0.55 * cos(6.2831853 * (x + vec3(0.0, 0.33, 0.67))), 0.0, 1.0);
}

// Filmic tone curve (Narkowicz ACES fit), then sRGB gamma.
vec3 toDisplay(vec3 c) {
  c *= 1.15;
  c = clamp((c * (2.51 * c + 0.03)) / (c * (2.43 * c + 0.59) + 0.14), 0.0, 1.0);
  return pow(c, vec3(1.0 / 2.2));
}

vec3 shade(vec3 pos, vec3 nL, vec3 rdW) {
  vec3 n = normalize(uRot * nL);
  vec3 v = -rdW;
  float ndv = clamp(dot(n, v), 0.0, 1.0);
  float ao = calcAO(pos, nL);

  // Glyph-space masks: flat faces, and the rounded bevel band between the
  // faces and the side walls.
  float az = abs(nL.z);
  float face = smoothstep(0.88, 0.995, az);
  float bevel = smoothstep(0.03, 0.3, az) * (1.0 - face);

  // Iridescence lives on the bevels only; its hue follows the view angle
  // and the bevel's orientation, so bands sweep as the glyph turns.
  float irid = uMat.y * bevel;
  vec3 film = thinFilm(1.2 * (1.0 - ndv) + 0.3 * n.x - 0.2 * n.y + 0.05);
  float lacquer = uMat.w;

  vec3 albedo = mix(uSide, uFace, face);
  // Pearlescent body: the film tints the bevels' diffuse colour too.
  albedo *= mix(vec3(1.0), 0.35 + film, irid * 0.6 * (1.0 - lacquer));
  // Side walls darken towards the back, like light falling into a slot.
  float sideT = smoothstep(-uGlyph.w, uGlyph.w, pos.z);
  albedo *= mix(1.0, mix(0.55, 1.0, sideT), 1.0 - face);

  // Diffuse: hemisphere ambient plus a wrapped key and a cool fill. The key
  // is a point light up-left of the screen, so faces get a soft gradient.
  vec3 world = uPos + uRot * (pos * uGlyph.y);
  vec3 keyPos = vec3(-0.8, 1.0, 1.4) * (0.35 * (uSize.x + uSize.y));
  float nl = dot(n, normalize(keyPos - world));
  vec3 irr = mix(vec3(0.05) * uEnv, vec3(0.38), 0.5 + 0.5 * n.y);
  irr += vec3(1.7, 1.66, 1.6) * max((nl + 0.1) / 1.1, 0.0);
  irr += vec3(0.33, 0.35, 0.40) * max(dot(n, normalize(FILL_DIR)), 0.0);
  vec3 col = albedo * irr * ao;

  // Clear coat reflecting the studio, tinted by the film on the bevels.
  float f0 = mix(mix(0.04, 0.05, lacquer), 0.16, irid);
  float fres = f0 + (1.0 - f0) * pow(1.0 - ndv, 5.0);
  vec3 tint = mix(vec3(1.0), film * 1.7, irid);
  float rough = 1.0 - uMat.z;
  col += studio(reflect(-v, n), rough) * tint * fres * mix(1.0, ao, 0.8);

  return toDisplay(col);
}

void main() {
  vec2 frag = FlutterFragCoord().xy;
  float D = uCam.x;
  float scale = uGlyph.y;

  // Camera on +z looking at the canvas plane z = 0.
  vec3 roW = vec3(0.0, 0.0, D);
  vec3 rdW = normalize(vec3(frag.x - 0.5 * uSize.x, 0.5 * uSize.y - frag.y, -D));

  // Into glyph space (row-vector product = inverse rotation).
  vec3 ro = ((roW - uPos) * uRot) / scale;
  vec3 rd = rdW * uRot;

  vec3 halfBox = vec3(uBox.zw, uGlyph.w) + 0.02;
  vec2 span = boxHit(ro, rd, halfBox);
  if (span.x > span.y || span.y < 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  // Physical pixel footprint in glyph space per unit of ray distance.
  float pixelK = 1.0 / (D * uCam.y);

  float t = max(span.x, 0.0);
  float hitT = -1.0;
  float minRatio = 1e9;
  float tMin = t;
  for (int i = 0; i < 96; i++) {
    float d = map(ro + rd * t);
    float px = t * pixelK;
    float ratio = d / px;
    if (ratio < minRatio) {
      minRatio = ratio;
      tMin = t;
    }
    if (d < 0.25 * px) {
      hitT = t;
      break;
    }
    t += d;
    if (t > span.y) {
      break;
    }
  }

  float coverage = hitT > 0.0 ? 1.0 : clamp((1.0 - minRatio) / 0.75, 0.0, 1.0);
  if (coverage <= 0.0) {
    fragColor = vec4(0.0);
    return;
  }

  float tShade = hitT > 0.0 ? hitT : tMin;
  vec3 pos = ro + rd * tShade;
  vec3 nL = calcNormal(pos, max(tShade * pixelK * 0.5, 0.0004));
  vec3 col = shade(pos, nL, rdW);

  float a = coverage * uGlyph.z;
  fragColor = vec4(col * a, a);
}
