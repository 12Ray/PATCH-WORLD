import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/effects/player_strike_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class PlayerProjectileComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PlayerProjectileComponent({
    required super.position,
    required this.velocity,
    required this.sourceId,
    this.damage = 1,
    this.lifetimeSeconds = 2.4,
    this.projectileColor = const Color(0xFF36E1FF),
    this.maxHits = 1,
    this.ricochetRadians = 0,
    this.blastRadius = 0,
    this.blastDamage = 0,
    double radius = 6,
  }) : super(
         radius: radius,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 31,
       );

  final Vector2 velocity;
  final String sourceId;
  final int damage;
  final double lifetimeSeconds;
  final Color projectileColor;
  final int maxHits;
  final double ricochetRadians;
  final double blastRadius;
  final int blastDamage;
  late double _remaining = lifetimeSeconds;
  int _hits = 0;
  final Set<CombatTarget> _hitTargets = <CombatTarget>{};

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
    position += velocity * dt;
    final activeRoom = game.world.activeRoom;
    if (activeRoom is PlatformerRoomGeometry) {
      final geometry = activeRoom as PlatformerRoomGeometry;
      final point = Offset(position.x, position.y);
      if (geometry.solidBounds.any((solid) => solid.contains(point))) {
        removeFromParent();
      }
    }
    _remaining -= dt;
    if (_remaining <= 0) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = projectileColor
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    canvas.drawCircle(
      center,
      radius * 0.42,
      Paint()..color = const Color(0xFFFFFFFF),
    );
    super.render(canvas);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is CombatTarget) {
      final target = other as CombatTarget;
      if (!_hitTargets.add(target)) {
        super.onCollisionStart(intersectionPoints, other);
        return;
      }
      game.combatSystem.applyPlayerAttack(
        target,
        sourceId: sourceId,
        amount: damage,
      );
      game.triggerPlayerWeaponImpactFeedback(
        sourceId: sourceId,
        position: other.position,
        direction: velocity,
        damage: damage,
      );
      if (blastRadius > 0 && blastDamage > 0) {
        game.world.add(
          PlayerStrikeComponent(
            position: other.position.clone(),
            size: Vector2.all(blastRadius * 2),
            sourceId: '$sourceId.explosion',
            damage: blastDamage,
            activeSeconds: .10,
            strikeColor: projectileColor.withValues(alpha: .62),
          ),
        );
      }
      _hits += 1;
      if (_hits >= maxHits) {
        removeFromParent();
      } else if (ricochetRadians != 0) {
        final turn = _hits.isOdd ? ricochetRadians : -ricochetRadians;
        final cosine = math.cos(turn);
        final sine = math.sin(turn);
        final nextX = velocity.x * cosine - velocity.y * sine;
        final nextY = velocity.x * sine + velocity.y * cosine;
        velocity.setValues(nextX, nextY);
      }
    } else if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
