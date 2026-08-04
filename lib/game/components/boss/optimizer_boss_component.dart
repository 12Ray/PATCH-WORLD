import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/components/effects/prediction_strike_component.dart';
import 'package:patch_world/game/components/effects/optimizer_volley_telegraph_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/core/stability_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
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
         paint: Paint()..color = const Color(0x00000000),
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
  EntitySpriteVisual? _visual;
  List<Sprite>? _analyzeFrames;
  List<Sprite>? _predictFrames;
  List<Sprite>? _perfectFrames;
  List<Sprite>? _overflowFrames;
  double _visualTime = 0;

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
    unawaited(_loadVisual());
    await add(CircleHitbox());
  }

  Future<void> _loadVisual() async {
    try {
      final visual = EntitySpriteVisual(
        sprite: await game.loadSprite('sprites/optimizer.png'),
        size: Vector2.all(132),
        parentSize: size,
        bobAmplitude: 1.2,
        bobSpeed: 1.8,
        canFlipHorizontally: false,
        rotationAmplitude: 0,
      );
      if (isRemoving) return;
      _visual = visual;
      await add(visual);
      await _loadAnimations(visual);
    } catch (_) {
      paint.color = const Color(0xFFFFE39A);
    }
  }

  Future<void> _loadAnimations(EntitySpriteVisual visual) async {
    final analyzeImage = await game.images.load(
      'sprites/animations/optimizer-analyze.png',
    );
    final predictImage = await game.images.load(
      'sprites/animations/optimizer-predict.png',
    );
    final perfectImage = await game.images.load(
      'sprites/animations/optimizer-perfect.png',
    );
    final overflowImage = await game.images.load(
      'sprites/animations/optimizer-overflow.png',
    );
    if (isRemoving) return;
    _analyzeFrames = _frames(analyzeImage, 6);
    _predictFrames = _frames(predictImage, 5);
    _perfectFrames = _frames(perfectImage, 4);
    _overflowFrames = _frames(overflowImage, 6);
    _applyPhaseAnimation();
  }

  List<Sprite> _frames(Image image, int count) => List.generate(
    count,
    (index) => Sprite(
      image,
      srcPosition: Vector2(index * 256.0, 0),
      srcSize: Vector2.all(256),
    ),
  );

  void _applyPhaseAnimation() {
    final visual = _visual;
    if (visual == null) return;
    switch (phase) {
      case OptimizerPhase.analyze:
      case OptimizerPhase.predict:
        final frames = _analyzeFrames;
        if (frames != null) visual.setDefaultAnimation(frames, fps: 6);
      case OptimizerPhase.perfect:
        final frames = _perfectFrames;
        if (frames != null) visual.setDefaultAnimation(frames, fps: 6);
      case OptimizerPhase.overflow:
        final frames = _overflowFrames;
        if (frames != null) visual.playOnce(frames, fps: 9);
      case OptimizerPhase.defeated:
        visual.setAnimationPlaying(false);
    }
  }

  @override
  void update(double dt) {
    _visualTime += dt;
    final visual = _visual;
    if (visual != null) {
      visual.angle +=
          dt *
          switch (phase) {
            OptimizerPhase.analyze => 0.06,
            OptimizerPhase.predict => -0.11,
            OptimizerPhase.perfect => 0.02,
            OptimizerPhase.overflow => 0.30,
            OptimizerPhase.defeated => 0,
          };
    }
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
    final predictFrames = _predictFrames;
    if (phase == OptimizerPhase.predict && predictFrames != null) {
      _visual?.playOnce(predictFrames, fps: 10);
    }
    _visual?.flash(const Color(0xFFFF4FD8), seconds: 0.16);
    _visual?.squash(seconds: 0.24);
    if (phase == OptimizerPhase.predict && _attackIndex.isEven) {
      final pattern = game.patternTracker.snapshot;
      final direction = switch (pattern.preferredDirection) {
        DirectionBucket.up => Vector2(0, -1),
        DirectionBucket.down => Vector2(0, 1),
        DirectionBucket.left => Vector2(-1, 0),
        DirectionBucket.right => Vector2(1, 0),
        null => Vector2.zero(),
      };
      for (var index = 1; index <= 3; index += 1) {
        await parent?.add(
          PredictionStrikeComponent(
            position: game.world.player.position + direction * (52.0 * index),
            warningSeconds: 0.62 + index * 0.10,
          ),
        );
      }
      return;
    }
    final count = phase == OptimizerPhase.predict ? 12 : 8;
    await parent?.add(
      OptimizerVolleyTelegraphComponent(
        position: position.clone(),
        laneCount: count,
        onResolved: () => unawaited(_spawnRadialVolley(count)),
      ),
    );
  }

  Future<void> _spawnRadialVolley(int count) async {
    if (!isMounted ||
        phase == OptimizerPhase.perfect ||
        phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated) {
      return;
    }
    for (var i = 0; i < count; i += 1) {
      if (!game.world.canSpawnProjectile) break;
      final angle = math.pi * 2 * (i + 0.5) / count;
      await parent?.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: Vector2(math.cos(angle), math.sin(angle)) * 125,
        ),
      );
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final patches = game.runState.selectedPatchIds;
    if (patches.isEmpty) return;
    final center = Offset(radius, radius);
    for (var index = 0; index < patches.length; index += 1) {
      final angle = _visualTime * 0.55 + math.pi * 2 * index / patches.length;
      final orbit = 67.0 + (index.isOdd ? 7 : 0);
      final marker = center + Offset(math.cos(angle), math.sin(angle)) * orbit;
      final color = _patchColor(patches[index]);
      if (phase == OptimizerPhase.perfect) {
        canvas.drawLine(
          center,
          marker,
          Paint()
            ..strokeWidth = 1.4
            ..color = color.withValues(alpha: 0.52),
        );
      }
      canvas.drawRect(
        Rect.fromCenter(center: marker, width: 8, height: 8),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color,
      );
    }
  }

  Color _patchColor(String patchId) => switch (patchId) {
    RuleIds.motionTax || RuleIds.retaliationEcho => const Color(0xFFFFA642),
    RuleIds.hostileTurbo || RuleIds.frameBurst => const Color(0xFFFF4FD8),
    RuleIds.phaseLeak || RuleIds.duplicateFault => const Color(0xFF36E1FF),
    _ => const Color(0xFFF4F7FF),
  };

  @override
  void receiveDamage(int amount) {
    if (amount <= 0 ||
        phase == OptimizerPhase.perfect ||
        phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated) {
      return;
    }
    health = math.max(6, health - amount);
    _visual?.flash(const Color(0xFFFFFFFF), seconds: 0.10);
    if (health <= 13 && phase == OptimizerPhase.analyze) {
      phase = OptimizerPhase.predict;
      _applyPhaseAnimation();
    }
    if (health <= 6) {
      phase = OptimizerPhase.perfect;
      stability.resetPerfectPhase();
      _visual?.setStateTint(const Color(0xFFFFFFFF));
      _applyPhaseAnimation();
      onPerfectStateEntered();
    }
  }

  @override
  void receiveHealing(int amount) {
    if (phase != OptimizerPhase.perfect || amount <= 0) return;
    stability.addHealingUnit(amount);
    scale.setAll(1 + (stability.current / 150) * 0.12);
    _visual?.setStateTint(
      stability.current > 100
          ? const Color(0xFFFF4FD8)
          : const Color(0xFFFFFFFF),
    );
    _visual?.flash(const Color(0xFF36E1FF), seconds: 0.08);
    if (stability.isOverflowed) _triggerOverflow();
  }

  void _triggerOverflow() {
    if (phase == OptimizerPhase.overflow || phase == OptimizerPhase.defeated) {
      return;
    }
    phase = OptimizerPhase.overflow;
    _visual?.setStateTint(const Color(0xFFFF4FD8));
    _visual?.squash(seconds: 0.30);
    _applyPhaseAnimation();
    Future<void>.delayed(const Duration(milliseconds: 650), () {
      if (!isMounted) return;
      phase = OptimizerPhase.defeated;
      onDefeated();
      removeFromParent();
    });
  }

  void resetFailedLegacyAttempt() {
    if (phase == OptimizerPhase.perfect) {
      stability.resetPerfectPhase();
      scale.setAll(1);
      _visual?.setStateTint(const Color(0xFFFFFFFF));
    }
  }
}
