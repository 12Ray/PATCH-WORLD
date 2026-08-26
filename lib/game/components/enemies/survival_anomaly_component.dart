import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum SurvivalAnomalyKind { riftStalker, arcWarden, mineLayer }

extension SurvivalAnomalyKindTelegraph on SurvivalAnomalyKind {
  double get attackTelegraphSeconds => switch (this) {
    SurvivalAnomalyKind.riftStalker => .52,
    SurvivalAnomalyKind.arcWarden => .48,
    SurvivalAnomalyKind.mineLayer => .55,
  };

  String get spriteAssetPath => switch (this) {
    SurvivalAnomalyKind.riftStalker =>
      'sprites/survival_v1/enemies/rift-stalker.webp',
    SurvivalAnomalyKind.arcWarden =>
      'sprites/survival_v1/enemies/arc-warden.webp',
    SurvivalAnomalyKind.mineLayer =>
      'sprites/survival_v1/enemies/mine-layer.webp',
  };

  Vector2 get visualSize => switch (this) {
    SurvivalAnomalyKind.riftStalker => Vector2.all(70),
    SurvivalAnomalyKind.arcWarden => Vector2.all(64),
    SurvivalAnomalyKind.mineLayer => Vector2(78, 64),
  };
}

int _healthFor(SurvivalAnomalyKind kind, bool elite) =>
    (switch (kind) {
      SurvivalAnomalyKind.riftStalker => 3,
      SurvivalAnomalyKind.arcWarden => 4,
      SurvivalAnomalyKind.mineLayer => 5,
    }) +
    (elite ? 3 : 0);

/// Three survival-native enemies sharing a compact rendering shell while
/// keeping clearly different movement and attack decisions.
final class SurvivalAnomalyComponent extends RectangleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  SurvivalAnomalyComponent({
    required this.entityId,
    required this.kind,
    required super.position,
    required this.onDefeated,
    bool elite = false,
  }) : _elite = elite,
       health = HealthState(
         max: _healthFor(kind, elite),
         current: _healthFor(kind, elite),
       ),
       super(
         size: Vector2.all(elite ? 46 : 38),
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 13,
       );

  @override
  final String entityId;
  final SurvivalAnomalyKind kind;
  final void Function() onDefeated;
  final bool _elite;
  final HealthState health;
  final Vector2 _previousPosition = Vector2.zero();
  double _attackTimer = 1.2;
  double _telegraph = 0;
  double _phase = 0;
  bool _attackArmed = false;
  bool _defeatReported = false;
  double _defeatTimer = 0;
  EntitySpriteVisual? _visual;
  List<Sprite>? _frames;

  Color get _accent => switch (kind) {
    SurvivalAnomalyKind.riftStalker => const Color(0xFF9D8CFF),
    SurvivalAnomalyKind.arcWarden => const Color(0xFF36E1FF),
    SurvivalAnomalyKind.mineLayer => const Color(0xFFFF4FD8),
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
    await add(
      RectangleHitbox.relative(
        Vector2.all(.76),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
        collisionType: CollisionType.passive,
      ),
    );
  }

  Future<void> _loadVisual() async {
    try {
      final image = await game.images.load(kind.spriteAssetPath);
      final frames = List<Sprite>.generate(
        8,
        (index) => Sprite(
          image,
          srcPosition: Vector2(index * 256.0, 0),
          srcSize: Vector2.all(256),
        ),
        growable: false,
      );
      final scale = _elite ? 1.15 : 1.0;
      final visual = EntitySpriteVisual(
        sprite: frames.first,
        size: kind.visualSize * scale,
        parentSize: size,
        bobAmplitude: kind == SurvivalAnomalyKind.arcWarden ? .80 : .20,
        bobSpeed: kind == SurvivalAnomalyKind.arcWarden ? 3.0 : 4.0,
        rotationAmplitude: kind == SurvivalAnomalyKind.arcWarden ? .012 : 0,
        animationDeltaResolver: (rawDt) =>
            isMounted ? game.clock.enemyDt : rawDt,
      );
      if (isRemoving || _defeatReported) return;
      _frames = frames;
      _visual = visual;
      await add(visual);
      visual.setDefaultAnimation(frames.sublist(0, 4), fps: 7);
    } catch (_) {
      // The existing code-native silhouette remains a safe offline fallback.
    }
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (enemyDt <= 0) {
      super.update(dt);
      return;
    }
    if (_defeatReported) {
      _defeatTimer = math.max(0, _defeatTimer - enemyDt);
      if (_defeatTimer == 0) removeFromParent();
      super.update(dt);
      return;
    }
    _previousPosition.setFrom(position);
    _phase += enemyDt;
    _attackTimer -= enemyDt;
    _telegraph = math.max(0, _telegraph - enemyDt);
    final player = game.world.player.position;
    switch (kind) {
      case SurvivalAnomalyKind.riftStalker:
        _updateRiftStalker(player, enemyDt);
      case SurvivalAnomalyKind.arcWarden:
        _updateArcWarden(player, enemyDt);
      case SurvivalAnomalyKind.mineLayer:
        _updateMineLayer(player, enemyDt);
    }
    _visual?.faceMovement(position - _previousPosition);
    super.update(dt);
  }

  void _playTelegraph() {
    final frames = _frames;
    if (frames == null) return;
    _visual?.playOnce(<Sprite>[
      frames[4],
    ], fps: 1 / kind.attackTelegraphSeconds);
  }

  void _playAttack() {
    final frames = _frames;
    if (frames == null) return;
    _visual?.playOnce(<Sprite>[frames[5], frames[6]], fps: 10);
  }

  void _updateRiftStalker(Vector2 player, double dt) {
    final delta = player - position;
    if (_attackTimer <= 0 && !_attackArmed) {
      _telegraph = kind.attackTelegraphSeconds;
      _attackTimer = 3.0;
      _attackArmed = true;
      _playTelegraph();
      return;
    }
    if (_attackArmed) {
      if (_telegraph > 0) return;
      final direction = delta.length2 == 0 ? Vector2(1, 0) : delta.normalized();
      position.setFrom(player - direction * 86);
      game.world.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: direction * 260,
          sourceId: 'enemy.rift_stalker.blink',
          attackTier: AttackTier.parryable,
          projectileColor: _accent,
          projectileRadius: 9,
          lifetimeSeconds: 1.1,
        ),
      );
      unawaited(game.audio.playEnemyAttack('riftStalkerBlink'));
      _attackArmed = false;
      _playAttack();
      return;
    }
    _moveWithCrowd(delta, dt, speed: 92, preferredDistance: 125);
  }

  void _updateArcWarden(Vector2 player, double dt) {
    final delta = player - position;
    final distance = delta.length;
    if (distance > 1) {
      final direction = delta / distance;
      final tangent = Vector2(-direction.y, direction.x);
      final radial = distance > 220
          ? 1.0
          : distance < 155
          ? -.7
          : 0.0;
      final steering = direction * radial + tangent * .72;
      if (steering.length2 > 1) steering.normalize();
      position += steering * (74 * dt);
    }
    if (_attackTimer <= 0 && !_attackArmed) {
      _telegraph = kind.attackTelegraphSeconds;
      _attackTimer = 2.35;
      _attackArmed = true;
      _playTelegraph();
      return;
    }
    if (!_attackArmed || _telegraph > 0) return;
    _attackArmed = false;
    if (!game.world.canSpawnProjectile) {
      _attackTimer = .3;
      return;
    }
    for (var index = 0; index < 6; index += 1) {
      final angle = index * math.pi / 3 + _phase * .25;
      parent?.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: Vector2(math.cos(angle), math.sin(angle)) * 150,
          sourceId: 'enemy.arc_warden.radial',
          attackTier: index.isEven ? AttackTier.normal : AttackTier.parryable,
          projectileColor: _accent,
          projectileRadius: 7,
        ),
      );
    }
    unawaited(game.audio.playEnemyAttack('arcWardenRadial'));
    _playAttack();
  }

  void _updateMineLayer(Vector2 player, double dt) {
    final delta = player - position;
    _moveWithCrowd(-delta, dt, speed: 62, preferredDistance: 210);
    if (_attackTimer <= 0 && !_attackArmed) {
      _telegraph = kind.attackTelegraphSeconds;
      _attackTimer = 3.1;
      _attackArmed = true;
      _playTelegraph();
      return;
    }
    if (!_attackArmed || _telegraph > 0) return;
    _attackArmed = false;
    parent?.add(
      SurvivalDataMineComponent(
        position: position.clone(),
        sourceId: 'enemy.mine_layer.dataMine',
      ),
    );
    unawaited(game.audio.playEnemyAttack('mineLayerField'));
    _playAttack();
  }

  void _moveWithCrowd(
    Vector2 delta,
    double dt, {
    required double speed,
    required double preferredDistance,
  }) {
    if (delta.length2 <= 1) return;
    final distance = delta.length;
    var direction = delta / distance;
    if (distance < preferredDistance) direction = -direction * .35;
    direction += game.world.survivalCrowdSteering(
      entityId: entityId,
      position: position,
      separationRadius: 62,
    );
    if (direction.length2 > 1) direction.normalize();
    position += direction * (speed * dt);
  }

  @override
  void onCollision(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is WallComponent ||
        (other is PhaseWallComponent && other.isSolid)) {
      position.setFrom(_previousPosition);
    }
    super.onCollision(intersectionPoints, other);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(width / 2, height / 2);
    final pulse = .8 + math.sin(_phase * 5) * .12;
    final radius = (width / 2 - 4) * pulse;
    final body = Paint()..color = _accent.withValues(alpha: .72);
    if (_visual == null) {
      switch (kind) {
        case SurvivalAnomalyKind.riftStalker:
          final diamond = Path()
            ..moveTo(center.dx, center.dy - radius)
            ..lineTo(center.dx + radius, center.dy)
            ..lineTo(center.dx, center.dy + radius)
            ..lineTo(center.dx - radius, center.dy)
            ..close();
          canvas.drawPath(diamond, body);
        case SurvivalAnomalyKind.arcWarden:
          canvas.drawCircle(center, radius, body);
          for (var index = 0; index < 3; index += 1) {
            final angle = _phase + index * math.pi * 2 / 3;
            canvas.drawCircle(
              center + Offset(math.cos(angle), math.sin(angle)) * (radius + 6),
              3,
              Paint()..color = const Color(0xFFFFFFFF),
            );
          }
        case SurvivalAnomalyKind.mineLayer:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCircle(center: center, radius: radius),
              const Radius.circular(5),
            ),
            body,
          );
          canvas.drawLine(
            center - Offset(radius * .6, 0),
            center + Offset(radius * .6, 0),
            Paint()
              ..strokeWidth = 3
              ..color = const Color(0xFFFFFFFF),
          );
      }
    }
    if (_telegraph > 0) {
      canvas.drawCircle(
        center,
        radius + 14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0xFFFFC857),
      );
    }
    final ratio = health.current / health.max;
    canvas.drawRect(
      Rect.fromLTWH(2, -7, width - 4, 3),
      Paint()..color = const Color(0xFF25304A),
    );
    canvas.drawRect(
      Rect.fromLTWH(2, -7, (width - 4) * ratio, 3),
      Paint()..color = _accent,
    );
    if (_elite) {
      canvas.drawCircle(
        center,
        width / 2 + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFC857),
      );
    }
    super.render(canvas);
  }

  @override
  void receiveDamage(int amount) {
    if (_defeatReported || amount <= 0) return;
    if (health.applyDamage(amount) == HealthMutation.defeated) {
      _defeatReported = true;
      _defeatTimer = .42;
      for (final hitbox in children.whereType<RectangleHitbox>()) {
        hitbox.removeFromParent();
      }
      final frames = _frames;
      if (frames != null) {
        _visual?.playOnce(<Sprite>[frames[7]], fps: 1 / _defeatTimer);
      }
      game.world.spawnDataShards(
        position,
        count: _elite ? 6 : 3,
        alternatingCorruption: false,
      );
      onDefeated();
    } else {
      final frames = _frames;
      if (frames != null) {
        _visual
          ?..flash(const Color(0xFFFFFFFF), seconds: .10)
          ..playOnce(<Sprite>[frames[6]], fps: 7);
      }
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}

final class SurvivalDataMineComponent extends CircleComponent
    with HasGameReference<PatchWorldGame> {
  SurvivalDataMineComponent({required super.position, required this.sourceId})
    : super(
        radius: 15,
        anchor: Anchor.center,
        paint: Paint()..color = const Color(0x44FF4FD8),
        priority: 8,
      );

  final String sourceId;
  double _fuse = 2.1;

  @override
  void update(double dt) {
    _fuse -= game.clock.enemyDt;
    if (_fuse <= 0) {
      if (game.world.player.position.distanceTo(position) <= 82) {
        game.world.player.takeDamage(1, causeId: sourceId);
      }
      removeFromParent();
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final progress = (1 - _fuse / 2.1).clamp(0.0, 1.0);
    final center = Offset(radius, radius);
    canvas.drawCircle(center, 14, Paint()..color = const Color(0xFFFF4FD8));
    canvas.drawCircle(
      center,
      18 + progress * 64,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 + progress * 3
        ..color = Color.fromRGBO(255, 79, 216, .22 + progress * .55),
    );
    super.render(canvas);
  }
}
