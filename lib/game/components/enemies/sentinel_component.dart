import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum SentinelState { scan, telegraph, cooldown }

final class SentinelComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  SentinelComponent({
    required this.entityId,
    required super.position,
    this.fireInterval = 1.6,
    this.telegraphSeconds = 0.55,
  }) : health = HealthState(max: 2, current: 2),
       super(
         size: Vector2(34, 44),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0xFFFFC857),
         priority: 10,
       );

  @override
  final String entityId;
  final double fireInterval;
  final double telegraphSeconds;
  final HealthState health;
  SentinelState _state = SentinelState.scan;
  double _stateTimer = 0;
  Vector2 _lockedDirection = Vector2(1, 0);

  SentinelState get state => _state;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.76),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
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
    _stateTimer -= enemyDt;
    switch (_state) {
      case SentinelState.scan:
        paint.color = const Color(0xFFFFC857);
        if (_stateTimer <= 0) {
          _lockDirection();
          _state = SentinelState.telegraph;
          _stateTimer = telegraphSeconds;
        }
      case SentinelState.telegraph:
        paint.color = (_stateTimer * 14).floor().isEven
            ? const Color(0xFFFF6464)
            : const Color(0xFFFFC857);
        if (_stateTimer <= 0) {
          unawaited(_fire());
          _state = SentinelState.cooldown;
          _stateTimer = fireInterval;
        }
      case SentinelState.cooldown:
        paint.color = const Color(0xFFB48A39);
        if (_stateTimer <= 0) {
          _state = SentinelState.scan;
          _stateTimer = 0;
        }
    }
    super.update(dt);
  }

  void _lockDirection() {
    final direction = game.world.player.position - position;
    _lockedDirection = direction.length2 == 0
        ? Vector2(1, 0)
        : direction.normalized();
  }

  Future<void> _fire() async {
    await parent?.add(
      EnemyProjectileComponent(
        position: position.clone(),
        velocity: _lockedDirection * 130,
      ),
    );
  }

  @override
  void receiveDamage(int amount) {
    if (health.applyDamage(amount) == HealthMutation.defeated) {
      removeFromParent();
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}
