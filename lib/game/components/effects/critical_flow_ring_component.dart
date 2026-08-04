import 'dart:ui';

import 'package:flame/components.dart';

final class CriticalFlowRingComponent extends PositionComponent {
  CriticalFlowRingComponent({required super.position}) : super(priority: 32);

  static const double duration = 0.62;
  double _age = 0;

  double get age => _age;
  bool get isExpired => _age >= duration;

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
    final gold = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 - progress * 3
      ..color = Color.fromRGBO(255, 200, 87, opacity);
    final cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 - progress * 1.5
      ..color = Color.fromRGBO(54, 225, 255, opacity * 0.88);
    canvas.drawCircle(Offset.zero, 20 + progress * 104, gold);
    canvas.drawCircle(Offset.zero, 10 + progress * 76, cyan);
    canvas.drawCircle(Offset.zero, 4 + progress * 46, gold);
    super.render(canvas);
  }
}
