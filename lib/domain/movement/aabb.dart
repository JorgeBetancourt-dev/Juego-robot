class Vec2d {
  const Vec2d(this.x, this.y);

  final double x;
  final double y;

  Vec2d copyWith({double? x, double? y}) => Vec2d(x ?? this.x, y ?? this.y);
}

class Aabb {
  const Aabb(this.left, this.top, this.width, this.height);

  final double left;
  final double top;
  final double width;
  final double height;

  double get right => left + width;
  double get bottom => top + height;

  bool overlaps(Aabb other) =>
      left < other.right &&
      right > other.left &&
      top < other.bottom &&
      bottom > other.top;
}
