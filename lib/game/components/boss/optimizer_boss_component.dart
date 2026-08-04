import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/effects/prediction_strike_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/core/stability_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';
import 'package:patch_world/game/systems/player_pattern_tracker.dart';

enum OptimizerPhase { analyze, predict, perfect, overflow, defeated }

final class OptimizerBossComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget, DuplicateSource {
  OptimizerBossComponent({
    required super.position,
    required this.onPerfectStateEntered,
    required this.onDefeated,
  }) : super(
         radius: 48,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFFFE39A),
         priority: 18,
       );

  @override
  String get entityId => 'boss.optimizer';
  final void Function() onPerfectStateEntered;
  final void Function() onDefeated;
  final StabilityState stability = StabilityState();
  OptimizerPhase phase = OptimizerPhase.analyze;
  int health = 20;
  double _attackTimer = 1.2;
  int _attackIndex = 0;
  bool _duplicateClaimed = false;

  @override
  Vector2 get duplicatePosition => position;
  @override
  DuplicateArchetype get duplicateArchetype => DuplicateArchetype.optimizer;
  @override
  bool claimDuplicate() {
    if (_duplicateClaimed || phase == OptimizerPhase.perfect) return false;
    _duplicateClaimed = true;
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(CircleHitbox());
  }

  @override
  void update(double dt) {
    if (phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated ||
        phase == OptimizerPhase.perfect) {
      super.update(dt);
      return;
    }
    final enemyDt = game.clock.enemyDt;
    if (enemyDt > 0) {
      _attackTimer -= enemyDt;
      if (_attackTimer <= 0) {
        _attackTimer = phase == OptimizerPhase.predict ? 1.2 : 1.55;
        unawaited(_performNextAttack());
      }
    }
    super.update(dt);
  }

  Future<void> _performNextAttack() async {
    _attackIndex += 1;
    if (phase == OptimizerPhase.predict && _attackIndex.isEven) {
      final pattern = game.patternTracker.snapshot;
      final offset = switch (pattern.preferredDirection) {
        DirectionBucket.up => Vector2(0, -84),
        DirectionBucket.down => Vector2(0, 84),
        DirectionBucket.left => Vector2(-84, 0),
        DirectionBucket.right => Vector2(84, 0),
        null => Vector2.zero(),
      };
      await parent?.add(
        PredictionStrikeComponent(
          position: game.world.player.position + offset,
        ),
      );
      return;
    }
    final count = phase == OptimizerPhase.predict ? 12 : 8;
    for (var i = 0; i < count; i += 1) {
      final angle = math.pi * 2 * i / count;
      await parent?.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: Vector2(math.cos(angle), math.sin(angle)) * 125,
        ),
      );
    }
  }

  @override
  void receiveDamage(int amount) {
    if (amount <= 0 ||
        phase == OptimizerPhase.perfect ||
        phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated) {
      return;
    }
    health = math.max(6, health - amount);
    if (health <= 13 && phase == OptimizerPhase.analyze) {
      phase = OptimizerPhase.predict;
    }
    if (health <= 6) {
      phase = OptimizerPhase.perfect;
      stability.resetPerfectPhase();
      paint.color = const Color(0xFFFFFFFF);
      onPerfectStateEntered();
    }
  }

  @override
  void receiveHealing(int amount) {
    if (phase != OptimizerPhase.perfect || amount <= 0) return;
    stability.addHealingUnit(amount);
    scale.setAll(1 + (stability.current / 150) * 0.12);
    paint.color = stability.current > 100
        ? const Color(0xFFFF4FD8)
        : const Color(0xFFFFFFFF);
    if (stability.isOverflowed) _triggerOverflow();
  }

  void _triggerOverflow() {
    if (phase == OptimizerPhase.overflow || phase == OptimizerPhase.defeated) {
      return;
    }
    phase = OptimizerPhase.overflow;
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      phase = OptimizerPhase.defeated;
      onDefeated();
      removeFromParent();
    });
  }

  void resetFailedLegacyAttempt() {
    if (phase == OptimizerPhase.perfect) {
      stability.resetPerfectPhase();
      scale.setAll(1);
      paint.color = const Color(0xFFFFFFFF);
    }
  }
}
