import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';

enum SurvivalScorePopupKind { normal, elite, miniBoss }

/// A compact kill confirmation that teaches the value of each target.
final class SurvivalScorePopupComponent extends TextComponent {
  SurvivalScorePopupComponent({
    required super.position,
    required this.score,
    required this.kind,
  }) : super(
         text: '+$score',
         anchor: Anchor.center,
         priority: 70,
         textRenderer: TextPaint(
           style: TextStyle(
             color: switch (kind) {
               SurvivalScorePopupKind.normal => const Color(0xFF36E1FF),
               SurvivalScorePopupKind.elite => const Color(0xFFFFC857),
               SurvivalScorePopupKind.miniBoss => const Color(0xFFFF4FD8),
             },
             fontSize: switch (kind) {
               SurvivalScorePopupKind.normal => 15,
               SurvivalScorePopupKind.elite => 19,
               SurvivalScorePopupKind.miniBoss => 23,
             },
             fontWeight: FontWeight.w900,
             letterSpacing: 0.8,
           ),
         ),
       );

  static const double lifetimeSeconds = 0.7;

  final int score;
  final SurvivalScorePopupKind kind;
  double _age = 0;
  bool _expired = false;

  double get age => _age;
  bool get isExpired => _expired;

  @override
  void update(double dt) {
    if (_expired || dt <= 0) {
      super.update(dt);
      return;
    }
    _age += dt;
    position.y -= 38 * dt;
    final entrance = (_age / 0.12).clamp(0.0, 1.0);
    scale.setAll(0.72 + entrance * 0.38);
    if (_age >= lifetimeSeconds) {
      _expired = true;
      removeFromParent();
    }
    super.update(dt);
  }
}
