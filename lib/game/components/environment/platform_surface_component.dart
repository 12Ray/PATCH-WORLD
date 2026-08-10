import 'dart:ui';

import 'package:flame/components.dart';

enum PlatformSurfaceStyle { damage, temporal, collision }

final class PlatformSurfaceComponent extends RectangleComponent {
  PlatformSurfaceComponent({
    required super.position,
    required super.size,
    this.isBoundary = false,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(
         paint: Paint()
           ..color = switch (style) {
             PlatformSurfaceStyle.damage => const Color(0xFF25304A),
             PlatformSurfaceStyle.temporal => const Color(0xFF29284C),
             PlatformSurfaceStyle.collision => const Color(0xFF183E47),
           },
         priority: 2,
       );

  final bool isBoundary;
  final PlatformSurfaceStyle style;

  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (isBoundary) return;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.x, 4),
      Paint()..color = _accentColor,
    );
    for (double x = 10; x < size.x; x += 24) {
      canvas.drawRect(
        Rect.fromLTWH(x, 9, 10, mathMin(3, size.y - 9)),
        Paint()..color = _accentColor.withAlpha(85),
      );
    }
    if (style == PlatformSurfaceStyle.temporal) {
      for (double x = 20; x < size.x; x += 42) {
        canvas.drawCircle(
          Offset(x, mathMin(14, size.y - 3)),
          4,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x889D8CFF),
        );
      }
    } else if (style == PlatformSurfaceStyle.collision) {
      for (double x = 16; x < size.x; x += 38) {
        canvas.drawLine(
          Offset(x, 8),
          Offset(mathMin(x + 12, size.x), mathMin(18, size.y - 2)),
          Paint()
            ..strokeWidth = 2
            ..color = const Color(0x88FF4FD8),
        );
      }
    }
  }

  Color get _accentColor => switch (style) {
    PlatformSurfaceStyle.damage => const Color(0xFF36E1FF),
    PlatformSurfaceStyle.temporal => const Color(0xFF9D8CFF),
    PlatformSurfaceStyle.collision => const Color(0xFF2CF2C8),
  };

  double mathMin(double a, double b) => a < b ? a : b;
}

final class DamagePitComponent extends RectangleComponent {
  DamagePitComponent({
    required super.position,
    required super.size,
    this.style = PlatformSurfaceStyle.damage,
  }) : super(
         paint: Paint()
           ..color = switch (style) {
             PlatformSurfaceStyle.damage => const Color(0xFF260B2E),
             PlatformSurfaceStyle.temporal => const Color(0xFF15143A),
             PlatformSurfaceStyle.collision => const Color(0xFF092F37),
           },
         priority: 1,
       );

  final PlatformSurfaceStyle style;

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final stripe = Paint()
      ..color = switch (style) {
        PlatformSurfaceStyle.damage => const Color(0xFFEB4BD8),
        PlatformSurfaceStyle.temporal => const Color(0xFF9D8CFF),
        PlatformSurfaceStyle.collision => const Color(0xFF2CF2C8),
      };
    for (double x = -20; x < size.x + 20; x += 20) {
      canvas.drawLine(
        Offset(x, 4),
        Offset(x + 14, 18),
        stripe..strokeWidth = 3,
      );
    }
  }
}
