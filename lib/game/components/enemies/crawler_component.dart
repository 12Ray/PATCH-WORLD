import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';

final class CrawlerComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget, DuplicateSource {
  CrawlerComponent({
    required this.entityId,
    required super.position,
    int initialHealth = maxHealth,
    this.onOverflow,
    this.mergeShielded = false,
    this.canDuplicate = true,
    this.speedMultiplier = 1,
    this.onDefeated,
    int healthMaximum = maxHealth,
  }) : healthState = HealthState(max: healthMaximum, current: initialHealth),
       super(
         size: Vector2.all(32),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 10,
       );

  static const double moveSpeed = 70;
  static const int maxHealth = 3;
  static const double overflowDelaySeconds = 0.42;

  @override
  final String entityId;
  final HealthState healthState;
  final void Function(CrawlerComponent crawler)? onOverflow;
  final bool mergeShielded;
  final bool canDuplicate;
  final double speedMultiplier;
  final void Function()? onDefeated;
  final Vector2 _previousPosition = Vector2.zero();
  final Vector2 _externalVelocity = Vector2.zero();

  bool _overflowStarted = false;
  double _overflowTimer = 0;
  bool _mergeConsumed = false;
  bool _duplicateClaimed = false;
  EntitySpriteVisual? _visual;
  List<Sprite>? _healFrames;
  List<Sprite>? _overflowFrames;

  int get health => healthState.current;
  bool get isDefeated => healthState.isDefeated;
  bool get isOverflowing => _overflowStarted;
  bool get canMerge => mergeShielded && !_mergeConsumed && !isRemoving;

  @override
  Vector2 get duplicatePosition => position;

  @override
  DuplicateArchetype get duplicateArchetype => DuplicateArchetype.crawler;

  @override
  bool claimDuplicate() {
    if (!canDuplicate || _duplicateClaimed || isRemoving) return false;
    _duplicateClaimed = true;
    return true;
  }

  void consumeForMerge() => _mergeConsumed = true;

  void applyMagneticPull(Vector2 target, double dt) {
    if (!mergeShielded || isRemoving || dt <= 0) return;
    final direction = target - position;
    if (direction.length2 < 18 * 18) return;
    direction.normalize();
    _externalVelocity.add(direction * (96 * dt));
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.72),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  Future<void> _loadVisual() async {
    try {
      final visual = EntitySpriteVisual(
        sprite: await game.loadSprite('sprites/crawler.png'),
        size: Vector2.all(58),
        parentSize: size,
        bobAmplitude: 1.5,
        bobSpeed: 5.2,
        rotationAmplitude: 0.045,
        phaseOffset: entityId.hashCode.remainder(17).toDouble(),
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      await _loadAnimations(visual);
    } catch (_) {
      paint.color = const Color(0xFFFF6464);
    }
  }

  Future<void> _loadAnimations(EntitySpriteVisual visual) async {
    final chaseImage = await game.images.load(
      'sprites/animations/crawler-chase.png',
    );
    final overflowImage = await game.images.load(
      'sprites/animations/crawler-overflow.png',
    );
    final healImage = await game.images.load(
      'sprites/animations/crawler-heal.png',
    );
    if (isRemoving) return;
    visual.setDefaultAnimation(_frames(chaseImage, 6), fps: 9);
    _healFrames = _frames(healImage, 3);
    _overflowFrames = _frames(overflowImage, 5);
  }

  List<Sprite> _frames(Image image, int count) => List.generate(
    count,
    (index) => Sprite(
      image,
      srcPosition: Vector2(index * 256.0, 0),
      srcSize: Vector2.all(256),
    ),
  );

  void takePulseDamage(int amount) => receiveDamage(amount);

  @override
  void receiveDamage(int amount) {
    if (mergeShielded) {
      if (isMounted) {
        final away = position - game.world.player.position;
        if (away.length2 > 0) {
          away.normalize();
          _externalVelocity.add(away * 118);
        }
        _visual?.flash(const Color(0xFF36E1FF), seconds: 0.10);
        _visual?.squash(seconds: 0.18);
      }
      return;
    }
    final mutation = healthState.applyDamage(amount);
    if (mutation == HealthMutation.defeated) {
      if (isMounted) game.world.spawnDataShards(position, count: 1);
      onDefeated?.call();
      removeFromParent();
    } else if (mutation == HealthMutation.damaged) {
      _visual?.flash(const Color(0xFFFFFFFF));
      _visual?.squash();
    }
  }

  @override
  void receiveHealing(int amount) {
    final mutation = healthState.applyHealing(amount);
    if (mutation == HealthMutation.healed) {
      final healFrames = _healFrames;
      if (healFrames != null) {
        _visual?.playOnce(healFrames, fps: 8);
      }
      _visual?.flash(const Color(0xFF36E1FF));
    } else if (mutation == HealthMutation.overflowed) {
      _overflowStarted = true;
      _overflowTimer = overflowDelaySeconds;
      final overflowFrames = _overflowFrames;
      if (overflowFrames != null) {
        _visual?.playOnce(overflowFrames, fps: 12);
      }
      _visual?.setStateTint(const Color(0xFFFF4FD8));
      _visual?.squash(seconds: 0.28);
    }
  }

  @override
  void update(double dt) {
    final simulationDt = game.clock.simulationDt;
    final enemyDt = game.clock.enemyDt;
    if (_overflowStarted) {
      _overflowTimer -= simulationDt;
      scale.setAll(1 + (overflowDelaySeconds - _overflowTimer) * 0.55);
      if (_overflowTimer <= 0) {
        game.world.spawnDataShards(position, count: 3, corrupted: true);
        onDefeated?.call();
        onOverflow?.call(this);
        removeFromParent();
      }
      super.update(dt);
      return;
    }

    if (!game.world.isReady) {
      super.update(dt);
      return;
    }
    if (enemyDt > 0) {
      _previousPosition.setFrom(position);
      if (_externalVelocity.length2 > 0.5) {
        position += _externalVelocity * enemyDt;
        _externalVelocity.scale(math.pow(0.12, enemyDt).toDouble());
      } else {
        _externalVelocity.setZero();
      }
      final direction = game.world.player.position - position;
      if (direction.length2 > 16) {
        direction.normalize();
        _visual?.setAnimationPlaying(true);
        _visual?.faceMovement(direction);
        position += direction * (moveSpeed * speedMultiplier * enemyDt);
      } else {
        _visual?.setAnimationPlaying(false);
      }
    }
    super.update(dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is WallComponent) {
      position.setFrom(_previousPosition);
    } else if (other is CrawlerComponent && canMerge && other.canMerge) {
      game.world.tryMergeCrawlers(this, other);
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    if (other is CrawlerComponent && canMerge && other.canMerge) {
      game.world.tryMergeCrawlers(this, other);
    }
    super.onCollisionStart(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    const barHeight = 4.0;
    final maxRatio = healthState.max / healthState.overflowThreshold;
    final currentRatio = healthState.normalizedForOverflowBar;
    canvas.drawRect(
      Rect.fromLTWH(0, -8, width, barHeight),
      Paint()..color = const Color(0xFF1C2435),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, -8, width * maxRatio, barHeight),
      Paint()..color = const Color(0xFF36E1FF),
    );
    if (currentRatio > maxRatio) {
      canvas.drawRect(
        Rect.fromLTWH(
          width * maxRatio,
          -8,
          width * (currentRatio - maxRatio),
          barHeight,
        ),
        Paint()..color = const Color(0xFFFF4FD8),
      );
    }
  }
}
