class ClickPoint {
  final double x;
  final double y;
  final int index;

  const ClickPoint({
    required this.x,
    required this.y,
    required this.index,
  });

  Map<String, dynamic> toMap() => {'x': x, 'y': y};

  factory ClickPoint.fromMap(Map<String, dynamic> map, int index) {
    return ClickPoint(
      x: (map['x'] as num).toDouble(),
      y: (map['y'] as num).toDouble(),
      index: index,
    );
  }

  ClickPoint copyWith({double? x, double? y, int? index}) {
    return ClickPoint(
      x: x ?? this.x,
      y: y ?? this.y,
      index: index ?? this.index,
    );
  }

  @override
  String toString() =>
      'ClickPoint($index: ${x.toStringAsFixed(0)}, ${y.toStringAsFixed(0)})';
}
