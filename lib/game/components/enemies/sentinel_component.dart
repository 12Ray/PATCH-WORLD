import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
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
         paint: Paint()..color = const Color(0x00000000),
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
  EntitySpriteVisual? _visual;

  SentinelState get state => _state;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
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

  Future<void> _loadVisual() async {
    try {
      final visual = EntitySpriteVisual(
        sprite: await game.loadSprite('sprites/sentinel.png'),
        size: Vector2.all(62),
        parentSize: size,
        bobAmplitude: 2.4,
        bobSpeed: 2.8,
        canFlipHorizontally: false,
        rotationAmplitude: 0.06,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
    } catch (_) {
      paint.color = const Color(0xFFFFC857);
    }
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
        _visual?.setStateTint(null);
        if (_stateTimer <= 0) {
          _lockDirection();
          _state = SentinelState.telegraph;
          _stateTimer = telegraphSeconds;
        }
      case SentinelState.telegraph:
        _visual?.setStateTint(
          (_stateTimer * 14).floor().isEven
              ? const Color(0xFFFF7A7A)
              : const Color(0xFFFF4FD8),
        );
        scale.setAll(1 + (1 - _stateTimer / telegraphSeconds) * 0.14);
        if (_stateTimer <= 0) {
          _visual?.squash(seconds: 0.20);
          unawaited(_fire());
          _state = SentinelState.cooldown;
          _stateTimer = fireInterval;
        }
      case SentinelState.cooldown:
        scale.setAll(1);
        _visual?.setStateTint(const Color(0xFF7E7394));
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
    if (!game.world.canSpawnProjectile) return;
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
      if (isMounted) game.world.spawnDataShards(position, count: 2);
      removeFromParent();
    } else {
      _visual?.flash(const Color(0xFFFFFFFF));
      _visual?.squash();
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}
