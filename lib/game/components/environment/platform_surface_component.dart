import 'dart:ui';

import 'package:flame/components.dart';

final class PlatformSurfaceComponent extends RectangleComponent {
  PlatformSurfaceComponent({
    required super.position,
    required super.size,
    this.isBoundary = false,
  }) : super(paint: Paint()..color = const Color(0xFF25304A), priority: 2);

  final bool isBoundary;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isBoundary) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 4),
      Paint()..color = const Color(0xFF36E1FF),
    );
    for (double x = 10; x < size.x; x += 24) {
      canvas.drawRect(
        Rect.fromLTWH(x, 9, 10, mathMin(3, size.y - 9)),
        Paint()..color = const Color(0x5536E1FF),
      );
    }
  }

  double mathMin(double a, double b) => a < b ? a : b;
}

final class DamagePitComponent extends RectangleComponent {
  DamagePitComponent({required super.position, required super.size})
    : super(paint: Paint()..color = const Color(0xFF260B2E), priority: 1);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final stripe = Paint()..color = const Color(0xFFEB4BD8);
    for (double x = -20; x < size.x + 20; x += 20) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x + 14, 18),
        stripe..strokeWidth = 3,
      );
    }
  }
}
