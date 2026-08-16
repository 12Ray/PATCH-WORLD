import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PredictionStrikeComponent extends CircleComponent
    with HasGameReference<PatchWorldGame> {
  PredictionStrikeComponent({
    required super.position,
    this.warningSeconds = 0.8,
    this.sourceId = 'boss.optimizer.prediction',
    this.damage = 1,
    this.dangerColor = const Color(0xFFFF4FD8),
    this.strikeRadius = 48,
  }) : super(
         radius: strikeRadius,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 24,
       );

  final double warningSeconds;
  final String sourceId;
  final int damage;
  final Color dangerColor;
  final double strikeRadius;
  late double _remaining = warningSeconds;
  double _progress = 0;
  bool _resolved = false;

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (_resolved || enemyDt <= 0) {
      super.update(dt);
      return;
    }
    _remaining -= enemyDt;
    _progress = (1 - _remaining / warningSeconds).clamp(0, 1);
    if (_remaining <= 0) {
      _resolved = true;
      if (position.distanceTo(game.world.player.position) <= radius) {
        game.world.player.takeDamage(damage, causeId: sourceId);
      }
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    final danger = dangerColor.withValues(alpha: 0.22 + _progress * 0.65);
    canvas.drawCircle(
      center,
      radius * (1.35 - _progress * 0.35),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + _progress * 3
        ..color = danger,
    );
    canvas.drawLine(
      center - Offset(radius * 0.72, 0),
      center + Offset(radius * 0.72, 0),
      Paint()
        ..strokeWidth = 1.5 + _progress * 2
        ..color = danger,
    );
    canvas.drawLine(
      center - Offset(0, radius * 0.72),
      center + Offset(0, radius * 0.72),
      Paint()
        ..strokeWidth = 1.5 + _progress * 2
        ..color = danger,
    );
    canvas.drawRect(
      Rect.fromCenter(
        center: center,
        width: 10 + _progress * 12,
        height: 10 + _progress * 12,
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF36E1FF),
    );
    super.render(canvas);
  }
}
