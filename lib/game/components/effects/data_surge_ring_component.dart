import 'dart:ui';

import 'package:flame/components.dart';

final class DataSurgeRingComponent extends PositionComponent {
  DataSurgeRingComponent({required super.position}) : super(priority: 31);

  static const double duration = 0.48;
  double _age = 0;

  @override
  void update(double dt) {
    _age += dt;
    if (_age >= duration) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / duration).clamp(0.0, 1.0);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 - progress * 2
      ..color = Color.fromRGBO(54, 225, 255, opacity);
    canvas.drawCircle(Offset.zero, 18 + progress * 74, paint);
    canvas.drawCircle(
      Offset.zero,
      8 + progress * 46,
      paint..color = Color.fromRGBO(69, 243, 166, opacity * 0.82),
    );
    super.render(canvas);
  }
}
