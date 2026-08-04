import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/effects/shockwave_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';

final class CompositeComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget, DuplicateSource {
  CompositeComponent({
    required this.entityId,
    required super.position,
    required int combinedHealth,
    required this.onDefeated,
  }) : health = HealthState(
         max: combinedHealth + 2,
         current: combinedHealth + 2,
       ),
       super(
         size: Vector2.all(52),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFFF4FD8),
         priority: 14,
       );

  @override
  final String entityId;
  final HealthState health;
  final void Function() onDefeated;
  double _shockwaveCooldown = 1.4;
  double _telegraphRemaining = 0;
  bool _telegraphing = false;
  bool _duplicateClaimed = false;

  @override
  Vector2 get duplicatePosition => position;
  @override
  DuplicateArchetype get duplicateArchetype => DuplicateArchetype.crawler;
  @override
  bool claimDuplicate() {
    if (_duplicateClaimed || isRemoving) return false;
    _duplicateClaimed = true;
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.74),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (enemyDt <= 0) {
      super.update(dt);
      return;
    }
    if (_telegraphing) {
      _telegraphRemaining -= enemyDt;
      paint.color = (_telegraphRemaining * 12).floor().isEven
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFFF4FD8);
      if (_telegraphRemaining <= 0) {
        _telegraphing = false;
        _shockwaveCooldown = 2.2;
        unawaited(_emitShockwave());
      }
    } else {
      _shockwaveCooldown -= enemyDt;
      if (_shockwaveCooldown <= 0) {
        _telegraphing = true;
        _telegraphRemaining = 0.55;
      }
      final direction = game.world.player.position - position;
      if (direction.length2 > 64) {
        direction.normalize();
        position += direction * (60 * enemyDt);
      }
    }
    super.update(dt);
  }

  Future<void> _emitShockwave() async {
    await parent?.add(ShockwaveComponent(position: position.clone()));
  }

  @override
  void receiveDamage(int amount) {
    if (health.applyDamage(amount) == HealthMutation.defeated) {
      onDefeated();
      removeFromParent();
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}
