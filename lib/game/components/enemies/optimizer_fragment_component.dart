import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/effects/optimizer_volley_telegraph_component.dart';
import 'package:patch_world/game/components/effects/prediction_strike_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';

final class OptimizerFragmentComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget, DuplicateSource {
  OptimizerFragmentComponent({
    required this.entityId,
    required super.position,
    required this.onDefeated,
    int healthMaximum = 16,
  }) : health = HealthState(max: healthMaximum, current: healthMaximum),
       super(
         radius: 36,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 18,
       );

  @override
  final String entityId;
  final HealthState health;
  final void Function() onDefeated;
  double _attackRemaining = 1.0;
  int _attackIndex = 0;
  double _visualTime = 0;
  bool _duplicateClaimed = false;
  EntitySpriteVisual? _visual;
  List<Sprite>? _predictFrames;

  @override
  Vector2 get duplicatePosition => position;
  @override
  DuplicateArchetype get duplicateArchetype => DuplicateArchetype.optimizer;
  @override
  bool claimDuplicate() {
    if (_duplicateClaimed || isRemoving) return false;
    _duplicateClaimed = true;
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
    await add(CircleHitbox());
  }

  Future<void> _loadVisual() async {
    try {
      final visual = EntitySpriteVisual(
        sprite: await game.loadSprite('sprites/optimizer.png'),
        size: Vector2.all(104),
        parentSize: size,
        bobAmplitude: 1.4,
        bobSpeed: 2.5,
        canFlipHorizontally: false,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      final image = await game.images.load(
        'sprites/animations/optimizer-predict.png',
      );
      if (isRemoving) return;
      _predictFrames = List<Sprite>.generate(
        5,
        (index) => Sprite(
          image,
          srcPosition: Vector2(index * 256.0, 0),
          srcSize: Vector2.all(256),
        ),
      );
      visual.setDefaultAnimation(_predictFrames!, fps: 8);
    } catch (_) {
      paint.color = const Color(0xFFFFE39A);
    }
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    _visualTime += enemyDt;
    _visual?.angle += enemyDt * 0.16;
    if (enemyDt > 0) {
      final toCenter = Vector2(480, 270) - position;
      if (toCenter.length2 > 150 * 150) {
        toCenter.normalize();
        position += toCenter * (34 * enemyDt);
      }
      _attackRemaining -= enemyDt;
      if (_attackRemaining <= 0) {
        _attackRemaining = 1.45;
        unawaited(_attack());
      }
    }
    super.update(dt);
  }

  Future<void> _attack() async {
    _attackIndex += 1;
    _visual?.flash(const Color(0xFFFF4FD8), seconds: 0.16);
    _visual?.squash(seconds: 0.22);
    final frames = _predictFrames;
    if (frames != null) _visual?.playOnce(frames, fps: 11);
    if (_attackIndex.isEven) {
      final player = game.world.player.position;
      for (var index = -1; index <= 1; index += 1) {
        await parent?.add(
          PredictionStrikeComponent(
            position: player + Vector2(index * 58.0, index.isEven ? 44 : 0),
            warningSeconds: 0.62 + index.abs() * 0.08,
          ),
        );
      }
      return;
    }
    await parent?.add(
      OptimizerVolleyTelegraphComponent(
        position: position.clone(),
        laneCount: 10,
        onResolved: () => unawaited(_spawnVolley()),
      ),
    );
  }

  Future<void> _spawnVolley() async {
    if (!isMounted) return;
    for (var index = 0; index < 10; index += 1) {
      if (!game.world.canSpawnProjectile) break;
      final angle = math.pi * 2 * (index + 0.5) / 10 + _visualTime * 0.12;
      await parent?.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: Vector2(math.cos(angle), math.sin(angle)) * 145,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    for (var index = 0; index < 3; index += 1) {
      final angle = _visualTime * (0.8 + index * 0.15) + index * 2.1;
      final marker = center + Offset(math.cos(angle), math.sin(angle)) * 48;
      canvas.drawRect(
        Rect.fromCenter(center: marker, width: 9, height: 9),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = index.isEven
              ? const Color(0xFFFF4FD8)
              : const Color(0xFF36E1FF),
      );
    }
    canvas.drawCircle(
      center,
      34,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFC857),
    );
    super.render(canvas);
  }

  @override
  void receiveDamage(int amount) {
    if (amount <= 0) return;
    if (health.applyDamage(amount) == HealthMutation.defeated) {
      if (isMounted) {
        game.world.spawnDataShards(position, count: 12, corrupted: true);
      }
      onDefeated();
      removeFromParent();
    } else {
      _visual?.flash(const Color(0xFFFFFFFF), seconds: 0.10);
      _visual?.squash();
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}
