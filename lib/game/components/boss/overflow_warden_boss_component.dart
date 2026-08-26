import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/boss/overflow_warden_attack_pattern.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_action_timeline.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
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
    this.arenaBounds,
  }) : healthState = HealthState(max: 18, current: 12, overflowMargin: 6),
       super(size: Vector2(76, 88), anchor: Anchor.center, priority: 17);

  static const List<int> _phaseHealthCeilings = <int>[18, 21, 24];
  static const double _phaseTransitionSeconds = .75;
  static const int requiredDistinctAttacksPerPhase = 2;
  static const double _shieldChargeDistance = 320;
  static const double _shieldChargeSeconds = .28;

  final HealthState healthState;
  final VoidCallback onDefeated;
  final void Function(OverflowWardenPhase phase)? onPhaseChanged;
  final double arenaFloorY;
  final Rect? arenaBounds;
  OverflowWardenPhase phase = OverflowWardenPhase.dormant;

  SpriteComponent? _visual;
  List<Sprite>? _frames;
  double _clock = 0;
  double _attackCooldown = 1.1;
  double _phaseTimer = 0;
  double _phaseTransitionRemaining = 0;
  double _defeatTimer = 0;
  EnemyActionTimeline? _attackAction;
  final List<String> _recentAttacks = <String>[];
  final Vector2 _lockedAttackTarget = Vector2.zero();
  double _lockedAttackFacing = 1;
  int _decisionCursor = 0;
  int _hazardEpoch = 0;
  final Set<Component> _spawnedHazards = <Component>{};
  final OverflowWardenPhaseAttackGate _phaseAttackGate =
      OverflowWardenPhaseAttackGate(
        requiredDistinctAttacks: requiredDistinctAttacksPerPhase,
      );
  Vector2? _chargeStart;
  Vector2? _chargeEnd;
  double _chargeElapsed = 0;
  bool _phaseThresholdReached = false;
  bool _resolved = false;

  @override
  String get entityId => 'platformer.overflowWardenBoss';
  int get health => healthState.current;
  int get maximumOverflowHealth => healthState.overflowThreshold;
  bool get hasArtV3Visual => _frames?.length == 8;
  String? get activeAttackId => _attackAction?.id;
  EnemyActionPhase? get attackPhase => _attackAction?.phase;
  bool get hasCompletedAttackInCurrentPhase => _phaseAttackGate.isReady;
  int get completedDistinctAttackCountInCurrentPhase =>
      _phaseAttackGate.completedDistinctAttackCount;
  bool get isShieldCharging => _chargeEnd != null;
  bool get isPhaseTransitioning => _phaseTransitionRemaining > 0;
  double get phaseTransitionSecondsRemaining => _phaseTransitionRemaining;
  int get spawnedHazardCount => _spawnedHazards.length;
  int get diagnosticVisualFrameIndex => _resolveVisualFrameIndex();
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
    _phaseAttackGate.reset();
    _phaseThresholdReached = false;
    _phaseTransitionRemaining = 0;
    onPhaseChanged?.call(phase);
    game.publishUiSnapshot(force: true);
  }

  @override
  void receiveDamage(int amount) {
    if (!isActive || amount <= 0 || isPhaseTransitioning) return;
    final acceptedDamage = math.min(amount, math.max(0, health - 1));
    if (acceptedDamage > 0) healthState.applyDamage(acceptedDamage);
    if (health < _currentPhaseHealthCeiling) {
      _phaseThresholdReached = false;
    }
  }

  @override
  void receiveHealing(int amount) {
    if (!isActive || amount <= 0 || isPhaseTransitioning) return;
    final ceiling = _currentPhaseHealthCeiling;
    final acceptedHealing = math.min(amount, math.max(0, ceiling - health));
    if (acceptedHealing > 0) healthState.applyHealing(acceptedHealing);
    if (health < ceiling) return;
    _phaseThresholdReached = true;
    _tryAdvancePhaseGate();
  }

  /// Repair Leech support can restore the Warden up to one point below the
  /// anomaly threshold, but only a player-authored healing hit may cross it.
  /// This keeps the adds relevant without allowing them to auto-clear phases.
  void receiveSupportHealing(int amount) {
    if (!isActive || amount <= 0 || isPhaseTransitioning) return;
    final supportCeiling = _currentPhaseHealthCeiling - 1;
    final acceptedHealing = math.min(
      amount,
      math.max(0, supportCeiling - health),
    );
    if (acceptedHealing > 0) healthState.applyHealing(acceptedHealing);
  }

  int get _activePhaseIndex => switch (phase) {
    OverflowWardenPhase.shielded => 0,
    OverflowWardenPhase.breached => 1,
    OverflowWardenPhase.critical => 2,
    _ => throw StateError('$phase is not an active Warden phase.'),
  };

  int get _currentPhaseHealthCeiling => _phaseHealthCeilings[_activePhaseIndex];

  void _tryAdvancePhaseGate() {
    if (!_phaseThresholdReached || !hasCompletedAttackInCurrentPhase) return;
    switch (phase) {
      case OverflowWardenPhase.shielded:
        _beginPhaseTransition(OverflowWardenPhase.breached);
      case OverflowWardenPhase.breached:
        _beginPhaseTransition(OverflowWardenPhase.critical);
      case OverflowWardenPhase.critical:
        _beginOverflowDefeat();
      case OverflowWardenPhase.dormant ||
          OverflowWardenPhase.intro ||
          OverflowWardenPhase.overflowing ||
          OverflowWardenPhase.defeated:
        return;
    }
  }

  void _beginPhaseTransition(OverflowWardenPhase nextPhase) {
    phase = nextPhase;
    _phaseTransitionRemaining = _phaseTransitionSeconds;
    _phaseAttackGate.reset();
    _phaseThresholdReached = false;
    _attackCooldown = 0;
    _attackAction = null;
    _clearChargeMotion();
    _removeSpawnedHazards();
    scale.setAll(1.12);
    onPhaseChanged?.call(phase);
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  void _finishPhaseTransition() {
    _phaseTransitionRemaining = 0;
    scale.setAll(1);
    _attackCooldown = 0;
  }

  void _recordCompletedAttack(String attackId) {
    _phaseAttackGate.record(attackId);
    _tryAdvancePhaseGate();
    if (!isPhaseTransitioning && phase != OverflowWardenPhase.overflowing) {
      _attackCooldown = switch (phase) {
        OverflowWardenPhase.critical => .90,
        OverflowWardenPhase.breached => 1.10,
        _ => 1.30,
      };
    }
  }

  void _clearPhaseGate() {
    _phaseTransitionRemaining = 0;
    _phaseAttackGate.reset();
    _phaseThresholdReached = false;
    _clearChargeMotion();
  }

  void _beginOverflowDefeat() {
    if (_resolved) return;
    phase = OverflowWardenPhase.overflowing;
    _clearPhaseGate();
    onPhaseChanged?.call(phase);
    _attackAction = null;
    _removeSpawnedHazards();
    _defeatTimer = 1.35;
    game.triggerCombatSlowMotion();
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  void _updatePhaseTransition(double dt) {
    _phaseTransitionRemaining = math.max(0, _phaseTransitionRemaining - dt);
    final progress = _phaseTransitionRemaining / _phaseTransitionSeconds;
    scale.setAll(1 + progress * .12);
    if (_phaseTransitionRemaining <= 0) _finishPhaseTransition();
  }

  void _trackHazard(Component hazard) {
    _spawnedHazards.add(hazard);
    unawaited(hazard.removed.then((_) => _spawnedHazards.remove(hazard)));
  }

  void _removeSpawnedHazards() {
    _hazardEpoch += 1;
    for (final hazard in _spawnedHazards.toList(growable: false)) {
      if (!hazard.isRemoving) hazard.removeFromParent();
    }
    _spawnedHazards.clear();
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
    if (isPhaseTransitioning) {
      final transitionDt = isMounted ? game.clock.realDt : dt;
      _updatePhaseTransition(
        transitionDt > 0 && transitionDt.isFinite ? transitionDt : 0,
      );
      _syncVisual();
      super.update(dt);
      return;
    }
    if (!isActive) {
      _syncVisual();
      super.update(dt);
      return;
    }

    _advanceShieldCharge(simulationDt);
    _attackCooldown = math.max(0, _attackCooldown - simulationDt);
    final attackAction = _attackAction;
    if (attackAction != null) {
      final tick = attackAction.advance(simulationDt);
      if (tick.enteredActive) _executeAttack(attackAction.id);
      if (tick.completed) {
        _attackAction = null;
        _recordCompletedAttack(attackAction.id);
      }
    } else if (_attackCooldown <= 0) {
      _telegraph(_chooseAttack());
    }
    _syncVisual();
    super.update(dt);
  }

  String _chooseAttack() {
    final distance = game.world.player.position.distanceTo(position);
    final phaseDeck = OverflowWardenAttackCatalog.deckForPhase(
      _activePhaseIndex + 1,
    );
    final candidates =
        <String>[
              if (distance < 190) 'shieldSlam',
              if (distance >= 130) 'overflowGrenade',
              if (phase != OverflowWardenPhase.shielded) 'checksumFan',
              if (phase == OverflowWardenPhase.critical) 'memoryQuake',
              'shieldCharge',
            ]
            .where(phaseDeck.contains)
            .where((id) => !_recentAttacks.take(2).contains(id))
            .toList();
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
    _attackAction = OverflowWardenAttackCatalog.byId(attack).createTimeline();
    _lockedAttackTarget.setFrom(game.world.player.position);
    final horizontal = _lockedAttackTarget.x - position.x;
    if (horizontal.abs() > .01) {
      _lockedAttackFacing = horizontal.sign.toDouble();
    }
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
        final direction = _lockedAttackTarget - position;
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
          final direction = _lockedAttackTarget - position;
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
                assetSlug: 'overflow-warden',
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
        _startShieldCharge(owner);
    }
  }

  void _startShieldCharge(Component owner) {
    final start = position.clone();
    final targetX = _resolveShieldChargeEndX(start.x);
    final end = Vector2(targetX, start.y);
    _chargeStart = start;
    _chargeEnd = end;
    _chargeElapsed = 0;

    final distance = (end.x - start.x).abs();
    if (distance <= 0) {
      _clearChargeMotion();
      return;
    }
    unawaited(
      _addToOwner(
        owner,
        EnemyDamageVolumeComponent(
          position: Vector2((start.x + end.x) / 2, start.y + 8),
          size: Vector2(distance + size.x * .72, 74),
          sourceId: 'enemy.overflowWarden.shieldCharge',
          activeSeconds: _shieldChargeSeconds,
          volumeColor: const Color(0x889D8CFF),
        ),
      ),
    );
  }

  double _resolveShieldChargeEndX(double startX) {
    final authoredArena = arenaBounds;
    final room = isMounted ? game.world.activeRoom : null;
    final arenaWidth =
        authoredArena?.right ??
        (room is PlatformerRoomGeometry
            ? (room as PlatformerRoomGeometry).worldSize.x
            : startX + _shieldChargeDistance + size.x);
    return resolveOverflowWardenChargeEndX(
      startX: startX,
      facing: _lockedAttackFacing,
      arenaWidth: arenaWidth,
      bodyWidth: size.x,
      arenaLeft: authoredArena?.left ?? 0,
      arenaRight: authoredArena?.right,
      distance: _shieldChargeDistance,
    );
  }

  void _advanceShieldCharge(double dt) {
    final start = _chargeStart;
    final end = _chargeEnd;
    if (start == null || end == null || dt <= 0) return;
    _chargeElapsed = math.min(_shieldChargeSeconds, _chargeElapsed + dt);
    final linear = (_chargeElapsed / _shieldChargeSeconds).clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - linear, 3).toDouble();
    position.setFrom(start + (end - start) * eased);
    if (linear >= 1) _clearChargeMotion();
  }

  void _clearChargeMotion() {
    _chargeStart = null;
    _chargeEnd = null;
    _chargeElapsed = 0;
  }

  Future<void> _addToOwner(Component owner, Component child) async {
    final spawnEpoch = _hazardEpoch;
    if (_resolved || isRemoving || parent != owner || owner.isRemoving) return;
    await owner.add(child);
    if ((_resolved ||
            isRemoving ||
            parent != owner ||
            owner.isRemoving ||
            spawnEpoch != _hazardEpoch) &&
        child.parent == owner) {
      child.removeFromParent();
      return;
    }
    _trackHazard(child);
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
    final frameIndex = _resolveVisualFrameIndex();
    visual.sprite = frames[frameIndex];
    visual.position.setValues(
      size.x / 2,
      size.y / 2 + math.sin(_clock * 2.1) * .30,
    );
    // Telegraphs use the ring in render() rather than scaling the sprite.
    // Keeping a fixed silhouette prevents apparent boss-size jumps per attack.
    visual.scale.setAll(1);
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
    if (_attackAction?.phase == EnemyActionPhase.telegraph) {
      _renderAttackTelegraph(canvas, _attackAction!.id);
      canvas.drawCircle(
        Offset(size.x / 2, size.y / 2),
        52 + (_attackAction?.phaseProgress ?? 0) * 7,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = const Color(0xFFFFD35A),
      );
    }
    super.render(canvas);
  }

  void _renderAttackTelegraph(Canvas canvas, String attack) {
    final center = Offset(size.x / 2, size.y / 2);
    final tell = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0xCCFFD35A);
    switch (attack) {
      case 'shieldSlam':
        canvas.drawRect(
          Rect.fromCenter(
            center: center + const Offset(0, 28),
            width: 210,
            height: 44,
          ),
          tell,
        );
      case 'overflowGrenade':
        final path = Path()
          ..moveTo(center.dx, center.dy)
          ..quadraticBezierTo(
            center.dx + _lockedAttackFacing * 94,
            center.dy - 110,
            center.dx + _lockedAttackFacing * 188,
            center.dy + 38,
          );
        canvas.drawPath(path, tell);
      case 'checksumFan':
        final direction = _lockedAttackTarget - position;
        if (direction.length2 == 0) direction.x = _lockedAttackFacing;
        direction.normalize();
        for (final angle in <double>[-.32, -.16, 0, .16, .32]) {
          final ray = direction.clone()..rotate(angle);
          canvas.drawLine(
            center,
            center + Offset(ray.x, ray.y) * 190,
            tell..strokeWidth = angle == 0 ? 4 : 2,
          );
        }
      case 'memoryQuake':
        final floorY = size.y / 2 + arenaFloorY - position.y - 30;
        for (final offset in <double>[-300, -180, -60, 60, 180, 300]) {
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(size.x / 2 + offset, floorY),
              width: 64,
              height: 60,
            ),
            tell,
          );
        }
      case 'shieldCharge':
        final resolvedEndX = _resolveShieldChargeEndX(position.x);
        final signedTravel = resolvedEndX - position.x;
        canvas.drawRect(
          Rect.fromCenter(
            center: center + Offset(signedTravel / 2, 8),
            width: signedTravel.abs() + size.x * .72,
            height: 74,
          ),
          tell..strokeWidth = 5,
        );
    }
  }

  int _resolveVisualFrameIndex() {
    if (phase == OverflowWardenPhase.dormant) return 0;
    if (phase == OverflowWardenPhase.intro) {
      return 2 + ((_clock * 6).floor() % 2);
    }
    if (phase == OverflowWardenPhase.overflowing ||
        phase == OverflowWardenPhase.defeated) {
      return 7;
    }
    final idleFrame = switch (phase) {
      OverflowWardenPhase.shielded => 0,
      OverflowWardenPhase.breached => 1,
      OverflowWardenPhase.critical => 3,
      _ => 0,
    };
    return resolveOverflowWardenAttackFrame(
      actionPhase: _attackAction?.phase,
      phaseProgress: _attackAction?.phaseProgress ?? 0,
      idleFrame: idleFrame,
    );
  }
}
