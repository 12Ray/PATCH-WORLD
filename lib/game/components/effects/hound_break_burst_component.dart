import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

final class HoundBreakBurstComponent extends TextComponent {
  HoundBreakBurstComponent({required super.position, required this.score})
    : super(
        text: 'BREAK CONFIRMED  +$score',
        anchor: Anchor.center,
        priority: 74,
        textRenderer: TextPaint(
          style: const TextStyle(
            color: Color(0xFF45F3A6),
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      );

  static const double lifetimeSeconds = 0.9;

  final int score;
  double _age = 0;

  double get age => _age;
  bool get isExpired => _age >= lifetimeSeconds;

  @override
  void update(double dt) {
    if (dt > 0) {
      _age += dt;
      position.y -= 28 * dt;
      final entrance = (_age / 0.1).clamp(0.0, 1.0);
      scale.setAll(0.78 + entrance * 0.30);
      if (isExpired) removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / lifetimeSeconds).clamp(0.0, 1.0);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(width / 2, height / 2);
    for (var index = 0; index < 2; index += 1) {
      canvas.drawCircle(
        center,
        20 + index * 9 + progress * (42 + index * 10),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 - progress * 1.4
          ..color = Color.fromRGBO(
            index == 0 ? 255 : 69,
            index == 0 ? 79 : 243,
            index == 0 ? 216 : 166,
            opacity * (index == 0 ? 0.8 : 1),
          ),
      );
    }
    super.render(canvas);
  }
}
