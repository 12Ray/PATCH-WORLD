import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';

final class EnemyProjectileComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  EnemyProjectileComponent({required super.position, required this.velocity})
    : super(
        radius: 7,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0xFFFF6464),
        priority: 25,
      );

  final Vector2 velocity;
  double _lifetime = 8;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      CircleHitbox.relative(
        1,
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (enemyDt > 0) {
      position += velocity * enemyDt;
      _lifetime -= enemyDt;
      if (_lifetime <= 0) removeFromParent();
    }
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is PlayerComponent) {
      other.takeDamage(1, causeId: 'enemy.sentinel.projectile');
      removeFromParent();
    } else if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
