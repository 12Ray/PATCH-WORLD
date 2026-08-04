import 'dart:async';
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/effects/shockwave_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
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
         paint: Paint()..color = const Color(0x00000000),
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
  EntitySpriteVisual? _visual;
  List<Sprite>? _shockwaveFrames;

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
    unawaited(_loadVisuals());
    await add(
      RectangleHitbox.relative(
        Vector2.all(0.74),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
  }

  Future<void> _loadVisuals() async {
    try {
      final visual = EntitySpriteVisual(
        sprite: await game.loadSprite('sprites/composite.png'),
        size: Vector2.all(104),
        parentSize: size,
        bobAmplitude: 1.3,
        bobSpeed: 3.7,
        rotationAmplitude: 0.018,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      final stalkImage = await game.images.load(
        'sprites/animations/composite-stalk.png',
      );
      final shockwaveImage = await game.images.load(
        'sprites/animations/composite-shockwave.png',
      );
      if (isRemoving) return;
      visual.setDefaultAnimation(_frames(stalkImage, 6), fps: 8);
      _shockwaveFrames = _frames(shockwaveImage, 5);
    } catch (_) {
      paint.color = const Color(0xFFFF4FD8);
    }
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
    if (_telegraphing) {
      _telegraphRemaining -= enemyDt;
      final tint = (_telegraphRemaining * 12).floor().isEven
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFFF4FD8);
      _visual?.setStateTint(tint);
      scale.setAll(1 + (1 - _telegraphRemaining / 0.55) * 0.12);
      if (_telegraphRemaining <= 0) {
        _telegraphing = false;
        scale.setAll(1);
        _visual?.setStateTint(null);
        _visual?.squash(seconds: 0.22);
        final shockwaveFrames = _shockwaveFrames;
        if (shockwaveFrames != null) {
          _visual?.playOnce(shockwaveFrames, fps: 10);
        }
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
        _visual?.faceMovement(direction);
        position += direction * (60 * enemyDt);
      } else {
        _visual?.faceMovement(Vector2.zero());
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
      if (isMounted) {
        game.world.spawnDataShards(position, count: 4, corrupted: true);
      }
      onDefeated();
      removeFromParent();
    } else {
      _visual?.flash(const Color(0xFFFFFFFF));
      _visual?.squash();
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}
