import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

final class PatchPulseComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame> {
  PatchPulseComponent({required super.position, this.onTargetHit})
    : super(
        radius: radiusValue,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x5536E1FF),
        priority: 30,
      );

  static const double radiusValue = 52;
  static const double lifetimeSeconds = 0.10;

  final void Function(CombatTarget target)? onTargetHit;
  final Set<CombatTarget> _hitTargets = <CombatTarget>{};
  double _remainingLifetime = lifetimeSeconds;

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
    _remainingLifetime -= dt;
    final progress = (_remainingLifetime / lifetimeSeconds)
        .clamp(0, 1)
        .toDouble();
    paint.color = Color.fromRGBO(54, 225, 255, progress * 0.45);

    if (_remainingLifetime <= 0) {
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is CombatTarget) {
      final target = other as CombatTarget;
      if (_hitTargets.add(target)) {
        final handler = onTargetHit;
        if (handler != null) {
          handler(target);
        } else {
          game.combatSystem.applyPlayerPulse(target);
        }
      }
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
