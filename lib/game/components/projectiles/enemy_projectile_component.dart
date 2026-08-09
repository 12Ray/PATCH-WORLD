import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class EnemyProjectileComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  EnemyProjectileComponent({
    required super.position,
    required this.velocity,
    this.sourceId = 'enemy.sentinel.projectile',
    this.damage = 1,
    this.lifetimeSeconds = 8,
    this.projectileColor = const Color(0xFFFF4FD8),
    this.gravity = 0,
    this.remainingBounces = 0,
  }) : super(
         radius: 7,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 25,
       );

  final Vector2 velocity;
  final String sourceId;
  final int damage;
  final double lifetimeSeconds;
  final Color projectileColor;
  final double gravity;
  int remainingBounces;
  late double _lifetime = lifetimeSeconds;

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
  void render(Canvas canvas) {
    final direction = velocity.length2 == 0
        ? Vector2(1, 0)
        : velocity.normalized();
    final forward = Offset(direction.x, direction.y);
    final perpendicular = Offset(-direction.y, direction.x);
    final center = Offset(radius, radius);
    canvas.drawLine(
      center - forward * 22,
      center,
      Paint()
        ..strokeWidth = 3
        ..color = const Color(0x8836E1FF),
    );
    final bolt = Path()
      ..moveTo(center.dx + forward.dx * 8, center.dy + forward.dy * 8)
      ..lineTo(
        center.dx + perpendicular.dx * 5,
        center.dy + perpendicular.dy * 5,
      )
      ..lineTo(center.dx - forward.dx * 8, center.dy - forward.dy * 8)
      ..lineTo(
        center.dx - perpendicular.dx * 5,
        center.dy - perpendicular.dy * 5,
      )
      ..close();
    canvas.drawPath(bolt, Paint()..color = projectileColor);
    canvas.drawCircle(center, 2.5, Paint()..color = const Color(0xFFFFFFFF));
    if (game.clock.isSimulationFrozen) {
      canvas.drawCircle(
        center,
        11,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xAA36E1FF),
      );
    }
    super.render(canvas);
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (enemyDt > 0) {
      velocity.y += gravity * enemyDt;
      position += velocity * enemyDt;
      final activeRoom = game.world.activeRoom;
      if (activeRoom is PlatformerRoomGeometry) {
        final geometry = activeRoom as PlatformerRoomGeometry;
        final point = Offset(position.x, position.y);
        if (geometry.solidBounds.any((solid) => solid.contains(point))) {
          if (remainingBounces > 0) {
            position -= velocity * enemyDt;
            velocity.y = -velocity.y.abs() * 0.82;
            velocity.x *= 0.92;
            remainingBounces -= 1;
          } else {
            removeFromParent();
          }
        }
      }
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
      other.takeDamage(damage, causeId: sourceId);
      removeFromParent();
    } else if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
