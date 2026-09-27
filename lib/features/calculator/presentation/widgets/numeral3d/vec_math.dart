import 'dart:math' as math;

/// Minimal 3-vector for the numeral scene.
///
/// World units are logical pixels with the origin at the canvas centre,
/// y up and z pointing at the viewer.
class Vec3 {
  final double x, y, z;

  const Vec3(this.x, this.y, this.z);

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(x * x + y * y + z * z);

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// Unit quaternion describing a glyph's orientation.
class Quat {
  final double x, y, z, w;

  const Quat(this.x, this.y, this.z, this.w);

  static const identity = Quat(0, 0, 0, 1);

  /// Rotation of `|v|` radians about `v`'s direction.
  factory Quat.fromRotationVector(Vec3 v) {
    final angle = v.length;
    if (angle < 1e-9) return identity;
    final s = math.sin(angle / 2) / angle;
    return Quat(v.x * s, v.y * s, v.z * s, math.cos(angle / 2));
  }

  factory Quat.axisAngle(Vec3 axis, double angle) {
    final len = axis.length;
    if (len < 1e-12) return identity;
    return Quat.fromRotationVector(axis * (angle / len));
  }

  /// Hamilton product: applies [o] first, then this.
  Quat operator *(Quat o) => Quat(
        w * o.x + x * o.w + y * o.z - z * o.y,
        w * o.y - x * o.z + y * o.w + z * o.x,
        w * o.z + x * o.y - y * o.x + z * o.w,
        w * o.w - x * o.x - y * o.y - z * o.z,
      );

  Quat get conjugate => Quat(-x, -y, -z, w);

  Quat normalized() {
    final l = math.sqrt(x * x + y * y + z * z + w * w);
    if (l < 1e-12) return identity;
    return Quat(x / l, y / l, z / l, w / l);
  }

  /// The shortest rotation this quaternion represents, as axis * angle.
  Vec3 toRotationVector() {
    final sign = w < 0 ? -1.0 : 1.0;
    final qx = x * sign, qy = y * sign, qz = z * sign, qw = w * sign;
    final s = math.sqrt(qx * qx + qy * qy + qz * qz);
    if (s < 1e-9) return Vec3(qx * 2, qy * 2, qz * 2);
    final k = 2 * math.atan2(s, qw) / s;
    return Vec3(qx * k, qy * k, qz * k);
  }

  /// Angle (0..pi) of the shortest rotation.
  double get angle => toRotationVector().length;

  Vec3 rotate(Vec3 v) {
    // v' = v + 2w(q x v) + 2 q x (q x v)
    final tx = 2 * (y * v.z - z * v.y);
    final ty = 2 * (z * v.x - x * v.z);
    final tz = 2 * (x * v.y - y * v.x);
    return Vec3(
      v.x + w * tx + (y * tz - z * ty),
      v.y + w * ty + (z * tx - x * tz),
      v.z + w * tz + (x * ty - y * tx),
    );
  }

  /// Rotation matrix in column-major order (GLSL `mat3` layout).
  List<double> toMat3() {
    final xx = x * x, yy = y * y, zz = z * z;
    final xy = x * y, xz = x * z, yz = y * z;
    final wx = w * x, wy = w * y, wz = w * z;
    return [
      1 - 2 * (yy + zz), 2 * (xy + wz), 2 * (xz - wy), // column 0
      2 * (xy - wz), 1 - 2 * (xx + zz), 2 * (yz + wx), // column 1
      2 * (xz + wy), 2 * (yz - wx), 1 - 2 * (xx + yy), // column 2
    ];
  }

  @override
  String toString() => 'Quat($x, $y, $z, $w)';
}
