import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

final class PhaseExecutionBurstComponent extends TextComponent {
  PhaseExecutionBurstComponent({
    required super.position,
    required this.score,
    this.label = 'PHASE EXECUTION',
    this.dataLabel = 'DATA',
  }) : super(
         text: '$label  +$score  // $dataLabel +1',
         anchor: Anchor.center,
         priority: 76,
         textRenderer: TextPaint(
           style: const TextStyle(
             color: Color(0xFFFFC857),
             fontSize: 19,
             fontWeight: FontWeight.w900,
             letterSpacing: 1.2,
           ),
         ),
       );

  static const double lifetimeSeconds = 1.05;

  final int score;
  final String label;
  final String dataLabel;
  double _age = 0;

  double get age => _age;
  bool get isExpired => _age >= lifetimeSeconds;

  @override
  void update(double dt) {
    if (dt > 0) {
      _age += dt;
      position.y -= 30 * dt;
      final entrance = (_age / 0.11).clamp(0.0, 1.0);
      scale.setAll(0.72 + entrance * 0.38);
      if (isExpired) removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (_age / lifetimeSeconds).clamp(0.0, 1.0);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final center = Offset(width / 2, height / 2);
    const colors = <Color>[
      Color(0xFFFFC857),
      Color(0xFF45F3A6),
      Color(0xFF36E1FF),
    ];
    for (var index = 0; index < colors.length; index += 1) {
      final radius = 20 + index * 9 + progress * (48 + index * 8);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2 + index * 0.7 + progress * 2,
        math.pi * (1.15 + index * 0.12),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.4 - progress * 1.6
          ..strokeCap = StrokeCap.square
          ..color = colors[index].withValues(
            alpha: opacity * (1 - index * 0.14),
          ),
      );
    }
    super.render(canvas);
  }
}
