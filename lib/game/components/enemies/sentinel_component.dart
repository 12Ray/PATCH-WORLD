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
    this.onDefeated,
    this.isElite = false,
    this.projectileSpeed = 130,
    int healthMaximum = 2,
  }) : health = HealthState(max: healthMaximum, current: healthMaximum),
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
  final void Function()? onDefeated;
  final bool isElite;
  final double projectileSpeed;
  final HealthState health;
  SentinelState _state = SentinelState.scan;
  double _stateTimer = 0;
  double _fireAnimationRemaining = 0;
  Vector2 _lockedDirection = Vector2(1, 0);
  EntitySpriteVisual? _visual;
  List<Sprite>? _fireFrames;
  List<Sprite>? _cooldownFrames;
  bool _cooldownAnimationQueued = false;

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
        size: Vector2.all(isElite ? 78 : 62),
        parentSize: size,
        bobAmplitude: 2.4,
        bobSpeed: 2.8,
        canFlipHorizontally: false,
        rotationAmplitude: 0.06,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      await _loadAnimations(visual);
    } catch (_) {
      paint.color = const Color(0xFFFFC857);
    }
  }

  Future<void> _loadAnimations(EntitySpriteVisual visual) async {
    final scanImage = await game.images.load(
      'sprites/animations/sentinel-scan.png',
    );
    final fireImage = await game.images.load(
      'sprites/animations/sentinel-fire.png',
    );
    final cooldownImage = await game.images.load(
      'sprites/animations/sentinel-cooldown.png',
    );
    if (isRemoving) return;
    visual.setDefaultAnimation(_frames(scanImage, 4), fps: 6);
    _fireFrames = _frames(fireImage, 4);
    _cooldownFrames = _frames(cooldownImage, 3);
  }

  List<Sprite> _frames(Image image, int count) => List.generate(
    count,
    (index) => Sprite(
      image,
      srcPosition: Vector2(index * 256.0, 0),
      srcSize: Vector2.all(256),
    ),
  );

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
          final fireFrames = _fireFrames;
          if (fireFrames != null) {
            _visual?.playOnce(fireFrames, fps: 10);
            _fireAnimationRemaining = 0.4;
            _cooldownAnimationQueued = true;
          }
          _visual?.squash(seconds: 0.20);
          unawaited(_fire());
          _state = SentinelState.cooldown;
          _stateTimer = fireInterval;
        }
      case SentinelState.cooldown:
        scale.setAll(1);
        _visual?.setStateTint(const Color(0xFF7E7394));
        if (_cooldownAnimationQueued) {
          _fireAnimationRemaining -= enemyDt;
          if (_fireAnimationRemaining <= 0) {
            final cooldownFrames = _cooldownFrames;
            if (cooldownFrames != null) {
              _visual?.playOnce(cooldownFrames, fps: 8);
            }
            _cooldownAnimationQueued = false;
          }
        }
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
        velocity: _lockedDirection * projectileSpeed,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    if (isElite) {
      canvas.drawCircle(
        Offset(width / 2, height / 2),
        28,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFC857),
      );
    }
    if (_state == SentinelState.telegraph) {
      final progress = (1 - _stateTimer / telegraphSeconds).clamp(0, 1);
      final origin = Offset(width / 2, height / 2);
      final target =
          origin + Offset(_lockedDirection.x, _lockedDirection.y) * 900;
      canvas.drawLine(
        origin,
        target,
        Paint()
          ..strokeWidth = 1.4 + progress * 2.6
          ..color = Color.fromRGBO(255, 79, 216, 0.24 + progress * 0.58),
      );
      canvas.drawCircle(
        origin,
        9 + progress * 9,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF36E1FF),
      );
    }
    super.render(canvas);
  }

  @override
  void receiveDamage(int amount) {
    if (health.applyDamage(amount) == HealthMutation.defeated) {
      if (isMounted) {
        game.world.spawnDataShards(position, count: isElite ? 6 : 2);
      }
      onDefeated?.call();
      removeFromParent();
    } else {
      _visual?.flash(const Color(0xFFFFFFFF));
      _visual?.squash();
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}
