import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class EnemyProjectileComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements ReflectableAttack {
  EnemyProjectileComponent({
    required super.position,
    required this.velocity,
    this.sourceId = 'enemy.sentinel.projectile',
    this.damage = 1,
    this.lifetimeSeconds = 8,
    this.attackTier = AttackTier.normal,
    this.assetSlug,
    Color? projectileColor,
    this.gravity = 0,
    this.remainingBounces = 0,
    this.impactImpulse = 0,
    double projectileRadius = 7,
  }) : projectileColor = projectileColor ?? attackTier.color,
       super(
         radius: projectileRadius,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 25,
       );

  final Vector2 velocity;
  final String sourceId;
  final int damage;
  final double lifetimeSeconds;
  @override
  final AttackTier attackTier;
  final String? assetSlug;
  final Color projectileColor;
  final double gravity;
  final double impactImpulse;
  int remainingBounces;
  late double _lifetime = lifetimeSeconds;
  @override
  bool isReflected = false;
  SpriteComponent? _spriteVisual;
  bool _budgetReserved = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    if (!game.combatEntityBudget.tryReserveEnemyProjectile()) {
      removeFromParent();
      return;
    }
    _budgetReserved = true;
    if (assetSlug != null) unawaited(_loadSpriteVisual());
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
  void onRemove() {
    if (_budgetReserved) {
      _budgetReserved = false;
      game.combatEntityBudget.releaseEnemyProjectile();
    }
    super.onRemove();
  }

  Future<void> _loadSpriteVisual() async {
    try {
      final image = await game.images.load(
        'sprites/combat_v2/projectiles/$assetSlug.png',
      );
      if (isRemoving) return;
      final visual = SpriteComponent(
        sprite: Sprite(
          image,
          srcPosition: Vector2(attackTier.index * 128.0, 0),
          srcSize: Vector2.all(128),
        ),
        size: Vector2.all(switch (attackTier) {
          AttackTier.normal => 32,
          AttackTier.enhanced => 46,
          AttackTier.parryable => 42,
        }),
        position: size / 2,
        anchor: Anchor.center,
      )..paint.filterQuality = FilterQuality.none;
      _spriteVisual = visual;
      await add(visual);
    } catch (_) {
      // Tier-aware procedural rendering remains the safe fallback.
    }
  }

  @override
  void render(Canvas canvas) {
    final direction = velocity.length2 == 0
        ? Vector2(1, 0)
        : velocity.normalized();
    final forward = Offset(direction.x, direction.y);
    final perpendicular = Offset(-direction.y, direction.x);
    final center = Offset(radius, radius);
    if (_spriteVisual == null) {
      canvas.drawLine(
        center - forward * 22,
        center,
        Paint()
          ..strokeWidth = attackTier == AttackTier.enhanced ? 5 : 3
          ..color = attackTier.trailColor,
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
    }
    if (attackTier == AttackTier.parryable && !isReflected) {
      for (final inset in <double>[0, 4]) {
        final diamond = Path()
          ..moveTo(center.dx, center.dy - 13 + inset)
          ..lineTo(center.dx + 13 - inset, center.dy)
          ..lineTo(center.dx, center.dy + 13 - inset)
          ..lineTo(center.dx - 13 + inset, center.dy)
          ..close();
        canvas.drawPath(
          diamond,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFFFFD35A),
        );
      }
    }
    if (isReflected) {
      canvas.drawCircle(
        center,
        13,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = const Color(0xFFFFFFFF),
      );
    }
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
  bool reflectFrom(Vector2 sourcePosition) {
    if (isReflected || !attackTier.canBeParried) return false;
    final direction = position - sourcePosition;
    if (direction.length2 == 0) {
      direction.setFrom(-velocity);
    }
    if (direction.length2 == 0) direction.x = 1;
    direction.normalize();
    final reflectedSpeed = velocity.length.clamp(190, 520).toDouble() * 1.25;
    velocity.setFrom(direction * reflectedSpeed);
    isReflected = true;
    remainingBounces = 0;
    return true;
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
      if (other.resolveIncomingAttack(this)) {
        return;
      }
      if (!isReflected) {
        other.takeDamage(damage, causeId: sourceId);
        if (impactImpulse != 0 && velocity.length2 > 0) {
          other.applyExternalImpulse(velocity.normalized() * impactImpulse);
        }
        removeFromParent();
      }
    } else if (isReflected && other is CombatTarget) {
      game.combatSystem.applyPlayerAttack(
        other as CombatTarget,
        sourceId: 'player.parry.$sourceId',
        amount: damage + 1,
      );
      removeFromParent();
    } else if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
