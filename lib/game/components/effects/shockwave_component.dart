import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class ShockwaveComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  ShockwaveComponent({required super.position})
    : super(anchor: Anchor.center, priority: 22);

  static const double expansionSpeed = 180;
  static const double maximumRadius = 190;
  static const double ringThickness = 10;
  double _radius = 8;
  double _previousRadius = 0;
  bool _playerHit = false;
  final Paint _paint = Paint()
    ..color = const Color(0xAAFF4FD8)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 5;

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (enemyDt > 0) {
      _previousRadius = _radius;
      _radius += expansionSpeed * enemyDt;
      _tryHitPlayer();
      if (_radius >= maximumRadius) removeFromParent();
    }
    super.update(dt);
  }

  void _tryHitPlayer() {
    if (_playerHit) return;
    final distance = position.distanceTo(game.world.player.position);
    if (distance <= _radius + ringThickness &&
        distance >= _previousRadius - ringThickness) {
      _playerHit = true;
      game.world.player.takeDamage(1, causeId: 'enemy.composite.shockwave');
    }
  }

  @override
  void render(Canvas canvas) => canvas.drawCircle(Offset.zero, _radius, _paint);
}
