import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/effects/prediction_strike_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/components/visuals/entity_sprite_visual.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_phase_eleven.dart';
import 'package:patch_world/game/systems/combat_system.dart';

extension SurvivalNexusBossKindArt on SurvivalNexusBossKind {
  String get spriteAssetPath => switch (this) {
    SurvivalNexusBossKind.foundryOverseer =>
      'sprites/survival_v1/bosses/foundry-overseer.webp',
    SurvivalNexusBossKind.temporalRegent =>
      'sprites/survival_v1/bosses/temporal-regent.webp',
    SurvivalNexusBossKind.collisionBehemoth =>
      'sprites/survival_v1/bosses/collision-behemoth.webp',
    SurvivalNexusBossKind.nexusCore =>
      'sprites/survival_v1/bosses/nexus-core.webp',
  };

  Vector2 get visualSize => switch (this) {
    SurvivalNexusBossKind.foundryOverseer => Vector2.all(118),
    SurvivalNexusBossKind.temporalRegent => Vector2.all(118),
    SurvivalNexusBossKind.collisionBehemoth => Vector2(124, 118),
    SurvivalNexusBossKind.nexusCore => Vector2.all(142),
  };
}

final class SurvivalNexusBossComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  SurvivalNexusBossComponent({
    required this.entityId,
    required this.kind,
    required super.position,
    required this.arenaCenter,
    required this.onPhaseChanged,
    required this.onDefeated,
  }) : health = HealthState(
         max: kind.healthMaximum,
         current: kind.healthMaximum,
       ),
       super(
         radius: kind == SurvivalNexusBossKind.nexusCore ? 54 : 44,
         anchor: Anchor.center,
         priority: 44,
         paint: Paint()..color = const Color(0x00000000),
       );

  @override
  final String entityId;
  final SurvivalNexusBossKind kind;
  final Vector2 arenaCenter;
  final HealthState health;
  final void Function(int phase) onPhaseChanged;
  final void Function() onDefeated;

  double _introRemaining = 2.1;
  double _attackCooldown = 1.2;
  double _telegraphRemaining = 0;
  double _visualTime = 0;
  int _patternCursor = 0;
  int? _armedPattern;
  int _reportedPhase = 1;
  bool _defeatReported = false;
  double _defeatTimer = 0;
  final Vector2 _previousPosition = Vector2.zero();
  EntitySpriteVisual? _visual;
  List<Sprite>? _frames;

  int get phase {
    final ratio = health.current / health.max;
    if (kind.phaseCount == 3) {
      if (ratio > .66) return 1;
      if (ratio > .33) return 2;
      return 3;
    }
    return ratio > .52 ? 1 : 2;
  }

  List<String> get activePatternIds => kind.patternIdsForPhase(phase);

  Color get accent => switch (kind) {
    SurvivalNexusBossKind.foundryOverseer => const Color(0xFF45F3A6),
    SurvivalNexusBossKind.temporalRegent => const Color(0xFF36E1FF),
    SurvivalNexusBossKind.collisionBehemoth => const Color(0xFFFF4FD8),
    SurvivalNexusBossKind.nexusCore => const Color(0xFFFFC857),
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    unawaited(_loadVisual());
    await add(
      CircleHitbox.relative(
        .9,
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
      final visual = EntitySpriteVisual(
        sprite: frames.first,
        size: kind.visualSize,
        parentSize: size,
        bobAmplitude: kind == SurvivalNexusBossKind.collisionBehemoth
            ? .45
            : 1.2,
        bobSpeed: kind == SurvivalNexusBossKind.temporalRegent ? 4.8 : 3.5,
        rotationAmplitude: kind == SurvivalNexusBossKind.collisionBehemoth
            ? .006
            : .018,
      );
      if (isRemoving || _defeatReported) return;
      _frames = frames;
      _visual = visual;
      await add(visual);
      visual.setDefaultAnimation(frames.sublist(0, 3), fps: 6);
      if (_introRemaining > 0) {
        visual.playOnce(<Sprite>[frames[3]], fps: 1 / _introRemaining);
      }
    } catch (_) {
      // Code-native rings remain available if a packaged sprite cannot load.
    }
  }

  void _playTelegraph() {
    final frames = _frames;
    if (frames == null) return;
    _visual?.playOnce(<Sprite>[
      frames[4],
    ], fps: 1 / math.max(.01, _telegraphRemaining));
  }

  void _playAttack() {
    final frames = _frames;
    if (frames != null) _visual?.playOnce(<Sprite>[frames[5]], fps: 4);
  }

  void _playPhaseTransition() {
    final frames = _frames;
    if (frames != null) {
      _visual?.playOnce(<Sprite>[frames[6]], fps: 2.2);
    }
    _visual
      ?..flash(const Color(0xFFFFFFFF), seconds: .18)
      ..squash(seconds: .3);
  }

  void _playDeath() {
    final frames = _frames;
    if (frames != null) {
      _visual?.playOnce(<Sprite>[frames[7]], fps: 1 / _defeatTimer);
    }
  }

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    _visualTime += enemyDt;
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
    if (_introRemaining > 0) {
      _introRemaining = math.max(0, _introRemaining - enemyDt);
      super.update(dt);
      return;
    }
    _previousPosition.setFrom(position);
    _move(enemyDt);
    _visual?.faceMovement(position - _previousPosition);
    if (_telegraphRemaining > 0) {
      _telegraphRemaining -= enemyDt;
      if (_telegraphRemaining <= 0) {
        final pattern = _armedPattern;
        if (pattern != null) {
          _armedPattern = null;
          _resolvePattern(pattern);
          _attackCooldown = math.max(.72, 1.65 - phase * .18);
        }
      }
      super.update(dt);
      return;
    }
    _attackCooldown -= enemyDt;
    if (_attackCooldown <= 0) {
      _armedPattern = _patternCursor++ % 3;
      _telegraphRemaining = math.max(.58, .82 - phase * .06);
      _playTelegraph();
    }
    super.update(dt);
  }

  void _move(double dt) {
    final player = game.world.player.position;
    final orbit =
        _visualTime *
        switch (kind) {
          SurvivalNexusBossKind.foundryOverseer => .42,
          SurvivalNexusBossKind.temporalRegent => .78,
          SurvivalNexusBossKind.collisionBehemoth => .28,
          SurvivalNexusBossKind.nexusCore => .62,
        };
    final orbitRadius = switch (kind) {
      SurvivalNexusBossKind.foundryOverseer => 145.0,
      SurvivalNexusBossKind.temporalRegent => 182.0,
      SurvivalNexusBossKind.collisionBehemoth => 112.0,
      SurvivalNexusBossKind.nexusCore => 160.0,
    };
    final orbitTarget =
        arenaCenter +
        Vector2(math.cos(orbit), math.sin(orbit * 1.13)) * orbitRadius;
    final chaseWeight = switch (kind) {
      SurvivalNexusBossKind.collisionBehemoth => .42,
      SurvivalNexusBossKind.nexusCore when phase >= 2 => .24,
      _ => .08,
    };
    final target = orbitTarget * (1 - chaseWeight) + player * chaseWeight;
    final delta = target - position;
    if (delta.length2 > 4) {
      final speed = 54 + phase * 11;
      position += delta.normalized() * (speed * dt);
    }
  }

  void _resolvePattern(int pattern) {
    final phaseOffset = (phase - 1) * 3;
    switch (phaseOffset + pattern) {
      case 0:
        _aimedFan(count: 3 + kind.index, spread: .24, speed: 185);
      case 1:
        _radial(count: 8 + kind.index * 2, speed: 150, rotation: 0);
      case 2:
        _targetGrid(count: 3, spacing: 62, warning: .68);
      case 3:
        _crossfire(speed: 205);
      case 4:
        _radial(
          count: 12 + kind.index * 2,
          speed: 178,
          rotation: _visualTime * .48,
          alternating: true,
        );
      case 5:
        _collapseChase();
      case 6:
        _aimedFan(count: 7, spread: .16, speed: 235, mirrored: true);
      case 7:
        _radial(
          count: 20,
          speed: 205,
          rotation: _visualTime,
          alternating: true,
        );
      case 8:
        _targetGrid(count: 7, spacing: 46, warning: .52, damage: 2);
    }
    _playAttack();
    unawaited(game.audio.playEnemyAttack('survivalBoss.${kind.id}'));
  }

  void _aimedFan({
    required int count,
    required double spread,
    required double speed,
    bool mirrored = false,
  }) {
    final delta = game.world.player.position - position;
    final base = delta.length2 == 0 ? 0.0 : math.atan2(delta.y, delta.x);
    final center = (count - 1) / 2;
    for (var index = 0; index < count; index += 1) {
      final angle = base + (index - center) * spread;
      _projectile(
        angle,
        speed,
        'fan',
        tier: index == center.round()
            ? AttackTier.parryable
            : AttackTier.normal,
      );
      if (mirrored) _projectile(angle + math.pi, speed * .86, 'mirror');
    }
  }

  void _radial({
    required int count,
    required double speed,
    required double rotation,
    bool alternating = false,
  }) {
    for (var index = 0; index < count; index += 1) {
      final angle = rotation + math.pi * 2 * index / count;
      _projectile(
        angle,
        speed,
        'radial',
        tier: alternating && index.isEven
            ? AttackTier.parryable
            : AttackTier.normal,
      );
    }
  }

  void _crossfire({required double speed}) {
    final rotation = _visualTime * .18;
    for (var index = 0; index < 8; index += 1) {
      _projectile(
        rotation + math.pi * index / 4,
        speed,
        'crossfire',
        tier: index % 4 == 0 ? AttackTier.parryable : AttackTier.enhanced,
      );
    }
  }

  void _targetGrid({
    required int count,
    required double spacing,
    required double warning,
    int damage = 1,
  }) {
    final player = game.world.player.position;
    final center = (count - 1) / 2;
    for (var index = 0; index < count; index += 1) {
      final host = parent;
      if (host == null || !game.world.canSpawnCombatEffect) break;
      final horizontal = index.isEven;
      final offset = (index - center) * spacing;
      unawaited(
        game.world.tryAddCombatEffect(
          PredictionStrikeComponent(
            position:
                player + (horizontal ? Vector2(offset, 0) : Vector2(0, offset)),
            warningSeconds: warning + index * .025,
            sourceId: 'boss.${kind.id}.targetGrid',
            damage: damage,
            dangerColor: accent,
            strikeRadius: kind == SurvivalNexusBossKind.nexusCore ? 54 : 46,
          ),
          host: host,
        ),
      );
    }
  }

  void _collapseChase() {
    final player = game.world.player.position;
    _targetGrid(count: 5, spacing: 52, warning: .58);
    final escape = arenaCenter - player;
    if (escape.length2 > 1) {
      position.setFrom(player + escape.normalized() * 150);
    }
    _radial(count: 10, speed: 190, rotation: _visualTime * .3);
  }

  void _projectile(
    double angle,
    double speed,
    String pattern, {
    AttackTier tier = AttackTier.normal,
  }) {
    if (!game.world.canSpawnProjectile) return;
    parent?.add(
      EnemyProjectileComponent(
        position: position.clone(),
        velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
        sourceId: 'boss.${kind.id}.$pattern',
        attackTier: tier,
        projectileColor: accent,
        projectileRadius: tier == AttackTier.enhanced ? 9 : 7,
        lifetimeSeconds: 5,
      ),
    );
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(radius, radius);
    final telegraphProgress = _telegraphRemaining <= 0
        ? 0.0
        : (1 - _telegraphRemaining / .82).clamp(0, 1).toDouble();
    if (_visual == null) {
      canvas.drawCircle(
        center,
        radius - 5,
        Paint()
          ..color = accent.withValues(alpha: .28)
          ..style = PaintingStyle.fill,
      );
      for (var ring = 0; ring < phase + 1; ring += 1) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius - 5 - ring * 8),
          _visualTime * (.6 + ring * .2),
          math.pi * (1.1 + ring * .18),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = ring.isEven ? accent : const Color(0xFFFFFFFF),
        );
      }
    }
    if (_armedPattern != null) {
      canvas.drawCircle(
        center,
        radius + 10 + telegraphProgress * 14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 + telegraphProgress * 4
          ..color = const Color(0xFFFF6464),
      );
    }
    super.render(canvas);
  }

  @override
  void receiveDamage(int amount) {
    if (amount <= 0 || _defeatReported) return;
    final previousPhase = phase;
    final mutation = health.applyDamage(amount);
    if (mutation == HealthMutation.defeated) {
      _defeatReported = true;
      _defeatTimer = .8;
      _telegraphRemaining = 0;
      _armedPattern = null;
      for (final hitbox in children.whereType<CircleHitbox>().toList()) {
        hitbox.removeFromParent();
      }
      _playDeath();
      onDefeated();
      return;
    }
    _visual?.flash(const Color(0xFFFFFFFF), seconds: .1);
    final nextPhase = phase;
    if (nextPhase != previousPhase && nextPhase != _reportedPhase) {
      _reportedPhase = nextPhase;
      _attackCooldown = .35;
      _telegraphRemaining = 0;
      _armedPattern = null;
      _playPhaseTransition();
      onPhaseChanged(nextPhase);
    }
  }

  @override
  void receiveHealing(int amount) => health.applyHealing(amount);
}

final class SurvivalBossCutInComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  SurvivalBossCutInComponent({required this.title, required this.accent})
    : super(size: Vector2(760, 96), anchor: Anchor.center, priority: 150);

  final String title;
  final Color accent;
  double _remaining = 2.1;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      TextComponent(
        text: title,
        position: size / 2,
        anchor: Anchor.center,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: accent,
            fontSize: 30,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.4,
          ),
        ),
      ),
    );
  }

  @override
  void update(double dt) {
    position.setFrom(game.camera.viewfinder.position);
    _remaining -= dt.clamp(0, .05);
    if (_remaining <= 0) removeFromParent();
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final fade = (_remaining / 2.1).clamp(0, 1).toDouble();
    canvas.drawRRect(
      RRect.fromRectAndRadius(size.toRect(), const Radius.circular(12)),
      Paint()..color = const Color(0xEE080B14).withValues(alpha: .88 * fade),
    );
    canvas.drawLine(
      const Offset(0, 2),
      Offset(width, 2),
      Paint()
        ..strokeWidth = 4
        ..color = accent.withValues(alpha: fade),
    );
    canvas.drawLine(
      Offset(0, height - 2),
      Offset(width, height - 2),
      Paint()
        ..strokeWidth = 4
        ..color = accent.withValues(alpha: fade),
    );
    super.render(canvas);
  }
}
