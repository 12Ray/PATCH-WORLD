import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

/// A short containment-collapse cue between two Crawlers and the Composite.
final class CollisionMergeEffectComponent extends PositionComponent {
  CollisionMergeEffectComponent({required super.position})
    : super(size: Vector2.all(1), anchor: Anchor.center, priority: 30);

  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= 0.42) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / 0.42).clamp(0, 1).toDouble();
    for (var index = 0; index < 3; index += 1) {
      canvas.drawCircle(
        Offset.zero,
        18 + progress * (46 + index * 18),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4 - progress * 2.5
          ..color = Color.fromRGBO(
            index.isEven ? 54 : 255,
            index.isEven ? 225 : 79,
            index.isEven ? 255 : 216,
            (1 - progress) * 0.9,
          ),
      );
    }
    for (var index = 0; index < 10; index += 1) {
      final angle = index * math.pi / 5 + progress * 0.5;
      final distance = 12 + progress * 68;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(math.cos(angle), math.sin(angle)) * distance,
          width: 5,
          height: 5,
        ),
        Paint()
          ..color = index.isEven
              ? const Color(0xFF36E1FF)
              : const Color(0xFFFF4FD8),
      );
    }
  }
}
