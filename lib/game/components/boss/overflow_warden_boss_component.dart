import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum OverflowWardenPhase {
  dormant,
  intro,
  shielded,
  breached,
  critical,
  overflowing,
  defeated,
}

/// Dedicated ROOM 1 boss. Unlike the old enlarged standard enemy, the Warden
/// has an authored intro, three readable phases, context-selected attacks and
/// a short overflow defeat presentation.
final class OverflowWardenBossComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  OverflowWardenBossComponent({
    required super.position,
    required this.onDefeated,
    this.onPhaseChanged,
    this.arenaFloorY = 1024,
  }) : healthState = HealthState(max: 18, current: 12, overflowMargin: 6),
       super(size: Vector2(76, 88), anchor: Anchor.center, priority: 17);

  final HealthState healthState;
  final VoidCallback onDefeated;
  final void Function(OverflowWardenPhase phase)? onPhaseChanged;
  final double arenaFloorY;
  OverflowWardenPhase phase = OverflowWardenPhase.dormant;

  SpriteComponent? _visual;
  List<Sprite>? _frames;
  double _clock = 0;
  double _attackCooldown = 1.1;
  double _phaseTimer = 0;
  double _defeatTimer = 0;
  String? _pendingAttack;
  final List<String> _recentAttacks = <String>[];
  int _decisionCursor = 0;
  bool _resolved = false;

  @override
  String get entityId => 'platformer.overflowWardenBoss';
  int get health => healthState.current;
  int get maximumOverflowHealth => healthState.overflowThreshold;
  bool get hasArtV3Visual => _frames?.length == 8;
  bool get isActive => switch (phase) {
    OverflowWardenPhase.shielded ||
    OverflowWardenPhase.breached ||
    OverflowWardenPhase.critical => true,
    _ => false,
  };

  String get phaseId => switch (phase) {
    OverflowWardenPhase.dormant => 'warden_dormant',
    OverflowWardenPhase.intro => 'warden_intro',
    OverflowWardenPhase.shielded => 'warden_shielded',
    OverflowWardenPhase.breached => 'warden_breached',
    OverflowWardenPhase.critical => 'warden_critical',
    OverflowWardenPhase.overflowing => 'warden_overflow',
    OverflowWardenPhase.defeated => 'warden_defeated',
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RectangleHitbox.relative(
        Vector2(.72, .84),
        parentSize: size,
        position: size / 2,
        anchor: Anchor.center,
      ),
    );
    await add(
      TextComponent(
        text: game.localization.text('enemy.overflowWarden.name'),
        position: Vector2(size.x / 2, -18),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: const TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: Color(0xFFFFD35A),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
    );
    unawaited(_loadSpriteVisual());
  }

  Future<void> _loadSpriteVisual() async {
    try {
      final image = await game.images.load(
        'sprites/art_v3/enemies/overflow-warden.png',
      );
      _frames = List<Sprite>.generate(
        8,
        (index) => Sprite(
          image,
          srcPosition: Vector2(index * 256.0, 0),
          srcSize: Vector2.all(256),
        ),
      );
      final visual = SpriteComponent(
        sprite: _frames!.first,
        size: Vector2.all(142),
        position: size / 2,
        anchor: Anchor.center,
        priority: 2,
      )..paint.filterQuality = FilterQuality.none;
      _visual = visual;
      await add(visual);
    } catch (_) {
      // The procedural boss silhouette below remains a safe fallback.
    }
  }

  void beginIntro() {
    if (phase != OverflowWardenPhase.dormant) return;
    phase = OverflowWardenPhase.intro;
    onPhaseChanged?.call(phase);
    _phaseTimer = 2.8;
    game.publishUiSnapshot(force: true);
  }

  void activate() {
    if (phase != OverflowWardenPhase.intro) return;
    phase = OverflowWardenPhase.shielded;
    _attackCooldown = .7;
    onPhaseChanged?.call(phase);
    game.publishUiSnapshot(force: true);
  }

  @override
  void receiveDamage(int amount) {
    if (!isActive || amount <= 0) return;
    final previous = phase;
    healthState.applyDamage(amount);
    _refreshPhase(previous);
  }

  @override
  void receiveHealing(int amount) {
    if (!isActive || amount <= 0) return;
    final previous = phase;
    final mutation = healthState.applyHealing(amount);
    if (mutation == HealthMutation.overflowed) {
      _beginOverflowDefeat();
      return;
    }
    _refreshPhase(previous);
  }

  void _refreshPhase(OverflowWardenPhase previous) {
    phase = switch (healthState.current) {
      >= 21 => OverflowWardenPhase.critical,
      >= 18 => OverflowWardenPhase.breached,
      _ => OverflowWardenPhase.shielded,
    };
    if (phase != previous) {
      _attackCooldown = .35;
      scale.setAll(1.12);
      onPhaseChanged?.call(phase);
      game.triggerImpactFeedback();
      game.publishUiSnapshot(force: true);
    }
  }

  void _beginOverflowDefeat() {
    if (_resolved) return;
    phase = OverflowWardenPhase.overflowing;
    onPhaseChanged?.call(phase);
    _pendingAttack = null;
    _defeatTimer = 1.35;
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  @override
  void update(double dt) {
    final simulationDt = isMounted ? game.clock.enemyDt : dt;
    _clock += simulationDt;
    if (phase == OverflowWardenPhase.intro) {
      _phaseTimer = math.max(0, _phaseTimer - simulationDt);
      _syncVisual();
      super.update(dt);
      return;
    }
    if (phase == OverflowWardenPhase.overflowing) {
      _defeatTimer = math.max(0, _defeatTimer - simulationDt);
      final progress = 1 - _defeatTimer / 1.35;
      scale.setAll(1 + math.sin(progress * math.pi * 8).abs() * .16);
      angle = math.sin(progress * math.pi * 12) * .035;
      if (_defeatTimer <= 0) _finishDefeat();
      _syncVisual();
      super.update(dt);
      return;
    }
    if (!isActive) {
      _syncVisual();
      super.update(dt);
      return;
    }

    _attackCooldown = math.max(0, _attackCooldown - simulationDt);
    _phaseTimer = math.max(0, _phaseTimer - simulationDt);
    if (_pendingAttack != null && _phaseTimer <= 0) {
      final attack = _pendingAttack!;
      _pendingAttack = null;
      _executeAttack(attack);
      _attackCooldown = switch (phase) {
        OverflowWardenPhase.critical => .72,
        OverflowWardenPhase.breached => .92,
        _ => 1.15,
      };
    } else if (_pendingAttack == null && _attackCooldown <= 0) {
      _telegraph(_chooseAttack());
    }
    _syncVisual();
    super.update(dt);
  }

  String _chooseAttack() {
    final distance = game.world.player.position.distanceTo(position);
    final candidates = <String>[
      if (distance < 190) 'shieldSlam',
      if (distance >= 130) 'overflowGrenade',
      if (phase != OverflowWardenPhase.shielded) 'checksumFan',
      if (phase == OverflowWardenPhase.critical) 'memoryQuake',
      'shieldCharge',
    ].where((id) => !_recentAttacks.take(2).contains(id)).toList();
    final pool = candidates.isEmpty
        ? <String>['shieldSlam', 'overflowGrenade']
        : candidates;
    final chosen = pool[_decisionCursor % pool.length];
    _decisionCursor += 1;
    _recentAttacks.insert(0, chosen);
    if (_recentAttacks.length > 3) _recentAttacks.removeLast();
    return chosen;
  }

  void _telegraph(String attack) {
    _pendingAttack = attack;
    _phaseTimer = switch (attack) {
      'memoryQuake' => .82,
      'shieldCharge' => .62,
      _ => .48,
    };
    unawaited(game.audio.playEnemyAttack('warden.telegraph.$attack'));
  }

  void _executeAttack(String attack) {
    final owner = parent;
    if (owner == null) return;
    unawaited(game.audio.playEnemyAttack('warden.$attack'));
    switch (attack) {
      case 'shieldSlam':
        unawaited(
          _addToOwner(
            owner,
            EnemyDamageVolumeComponent(
              position: position + Vector2(0, 28),
              size: Vector2(210, 44),
              sourceId: 'enemy.overflowWarden.shieldSlam',
              activeSeconds: .18,
              volumeColor: const Color(0x88FF4FD8),
            ),
          ),
        );
      case 'overflowGrenade':
        final direction = game.world.player.position - position;
        if (direction.length2 == 0) direction.x = 1;
        direction.normalize();
        unawaited(
          _addToOwner(
            owner,
            EnemyProjectileComponent(
              position: position + Vector2(direction.x * 34, -24),
              velocity: Vector2(direction.x * 230, -250),
              sourceId: 'enemy.overflowWarden.overflowGrenade',
              attackTier: AttackTier.enhanced,
              gravity: 640,
              remainingBounces: 1,
              projectileRadius: 11,
              assetSlug: 'overflow-warden',
            ),
          ),
        );
      case 'checksumFan':
        for (final angle in <double>[-.32, -.16, 0, .16, .32]) {
          final direction = game.world.player.position - position;
          if (direction.length2 == 0) direction.x = 1;
          direction
            ..normalize()
            ..rotate(angle);
          unawaited(
            _addToOwner(
              owner,
              EnemyProjectileComponent(
                position: position.clone(),
                velocity: direction * 270,
                sourceId: 'enemy.overflowWarden.checksumFan',
                attackTier: angle == 0
                    ? AttackTier.parryable
                    : AttackTier.normal,
                projectileRadius: angle == 0 ? 9 : 6,
              ),
            ),
          );
        }
      case 'memoryQuake':
        for (final offset in <double>[-300, -180, -60, 60, 180, 300]) {
          unawaited(
            _addToOwner(
              owner,
              EnemyDamageVolumeComponent(
                position: Vector2(position.x + offset, arenaFloorY - 30),
                size: Vector2(64, 60),
                sourceId: 'enemy.overflowWarden.memoryQuake',
                activeSeconds: .24,
                volumeColor: const Color(0x88FFD35A),
              ),
            ),
          );
        }
      case 'shieldCharge':
        final direction = (game.world.player.position.x - position.x).sign;
        final facing = direction == 0 ? 1.0 : direction.toDouble();
        unawaited(
          _addToOwner(
            owner,
            EnemyDamageVolumeComponent(
              position: position + Vector2(facing * 105, 8),
              size: Vector2(190, 74),
              sourceId: 'enemy.overflowWarden.shieldCharge',
              activeSeconds: .26,
              volumeColor: const Color(0x889D8CFF),
            ),
          ),
        );
    }
  }

  Future<void> _addToOwner(Component owner, Component child) async {
    await owner.add(child);
  }

  void _finishDefeat() {
    if (_resolved) return;
    _resolved = true;
    phase = OverflowWardenPhase.defeated;
    onPhaseChanged?.call(phase);
    game.world.spawnDataShards(position, count: 8, corrupted: true);
    onDefeated();
    removeFromParent();
  }

  void _syncVisual() {
    final visual = _visual;
    final frames = _frames;
    if (visual == null || frames == null) return;
    final frameIndex = switch (phase) {
      OverflowWardenPhase.dormant => 0,
      OverflowWardenPhase.intro => 2 + ((_clock * 6).floor() % 2),
      OverflowWardenPhase.shielded => _pendingAttack == null ? 0 : 4,
      OverflowWardenPhase.breached => _pendingAttack == null ? 1 : 5,
      OverflowWardenPhase.critical => _pendingAttack == null ? 3 : 6,
      OverflowWardenPhase.overflowing || OverflowWardenPhase.defeated => 7,
    };
    visual.sprite = frames[frameIndex];
    visual.position.setValues(
      size.x / 2,
      size.y / 2 + math.sin(_clock * 3.2) * 1.5,
    );
    final telegraphPulse = _pendingAttack == null
        ? 1.0
        : 1 + math.sin(_clock * 18).abs() * .07;
    visual.scale.setAll(telegraphPulse);
  }

  @override
  void render(Canvas canvas) {
    if (_visual == null) {
      final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(8, 12, size.x - 16, size.y - 14),
        const Radius.circular(8),
      );
      canvas.drawRRect(body, Paint()..color = const Color(0xFF7B264E));
      canvas.drawRect(
        Rect.fromLTWH(2, 28, 18, 48),
        Paint()..color = const Color(0xFFFFD35A),
      );
    }
    if (_pendingAttack != null) {
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        52 + math.sin(_clock * 20).abs() * 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD35A),
      );
    }
    super.render(canvas);
  }
}
