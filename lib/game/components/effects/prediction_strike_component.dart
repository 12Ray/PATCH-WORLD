import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class PredictionStrikeComponent extends CircleComponent
    with HasGameReference<PatchWorldGame> {
  PredictionStrikeComponent({required super.position})
    : super(
        radius: 48,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x33FF6464),
        priority: 24,
      );

  static const double warningSeconds = 0.8;
  double _remaining = warningSeconds;
  bool _resolved = false;

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (_resolved || enemyDt <= 0) {
      super.update(dt);
      return;
    }
    _remaining -= enemyDt;
    final progress = (1 - _remaining / warningSeconds).clamp(0, 1);
    paint.color = Color.fromARGB((50 + progress * 150).round(), 255, 100, 100);
    if (_remaining <= 0) {
      _resolved = true;
      if (position.distanceTo(game.world.player.position) <= radius) {
        game.world.player.takeDamage(1, causeId: 'boss.optimizer.prediction');
      }
      removeFromParent();
    }
    super.update(dt);
  }
}
