import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

final class PerfectDodgeBurstComponent extends TextComponent {
  PerfectDodgeBurstComponent({
    required super.position,
    required this.score,
    this.label = 'PERFECT DODGE',
  }) : super(
         text: '$label  +$score',
         anchor: Anchor.center,
         priority: 72,
         textRenderer: TextPaint(
           style: const TextStyle(
             color: Color(0xFF45F3A6),
             fontSize: 18,
             fontWeight: FontWeight.w900,
             letterSpacing: 1.1,
           ),
         ),
       );

  static const double lifetimeSeconds = 0.85;

  final int score;
  final String label;
  double _age = 0;

  double get age => _age;
  bool get isExpired => _age >= lifetimeSeconds;

  @override
  void update(double dt) {
    if (dt > 0) {
      _age += dt;
      position.y -= 24 * dt;
      final entrance = (_age / 0.1).clamp(0.0, 1.0);
      scale.setAll(0.8 + entrance * 0.25);
      if (isExpired) removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / lifetimeSeconds).clamp(0.0, 1.0);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(width / 2, height / 2);
    canvas.drawCircle(
      center,
      24 + progress * 46,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3 - progress * 1.5
        ..color = Color.fromRGBO(69, 243, 166, opacity * 0.85),
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: 15 + progress * 30),
      -2.6,
      2.0,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromRGBO(54, 225, 255, opacity),
    );
    super.render(canvas);
  }
}
