import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
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
  late double _remaining = lifetimeSeconds;
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
      removeFromParent();
    } else if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      removeFromParent();
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
