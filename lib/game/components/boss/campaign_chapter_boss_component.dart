import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_pattern_catalog.dart';
import 'package:patch_world/game/components/effects/enemy_damage_volume_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/core/health_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum CampaignChapterBossKind { chronoJailer, kernelChimera }

extension CampaignChapterBossKindSpec on CampaignChapterBossKind {
  String get assetSlug => switch (this) {
    CampaignChapterBossKind.chronoJailer => 'chrono-jailer',
    CampaignChapterBossKind.kernelChimera => 'kernel-chimera',
  };

  String get enemyLocalizationKey => switch (this) {
    CampaignChapterBossKind.chronoJailer => 'enemy.chronoJailer.name',
    CampaignChapterBossKind.kernelChimera => 'enemy.kernelChimera.name',
  };

  String get phasePrefix => switch (this) {
    CampaignChapterBossKind.chronoJailer => 'chrono_jailer',
    CampaignChapterBossKind.kernelChimera => 'kernel_chimera',
  };

  Color get accentColor => switch (this) {
    CampaignChapterBossKind.chronoJailer => const Color(0xFF9D8CFF),
    CampaignChapterBossKind.kernelChimera => const Color(0xFF36E1FF),
  };
}

enum CampaignChapterBossPhase {
  dormant,
  intro,
  phaseOne,
  phaseTwo,
  phaseThree,
  defeated,
}

/// Dedicated phased boss used by Temporal Hall and Collision Archive.
final class CampaignChapterBossComponent extends PositionComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget {
  CampaignChapterBossComponent({
    required super.position,
    required this.kind,
    required this.onDefeated,
    this.onPhaseChanged,
    this.arenaBounds,
  }) : healthState = HealthState(
         max: CampaignBossPhaseGateSpec.maxHealth,
         current: CampaignBossPhaseGateSpec.maxHealth,
         overflowMargin: 0,
       ),
       super(size: Vector2(78, 90), anchor: Anchor.center, priority: 17);

  final CampaignChapterBossKind kind;
  final HealthState healthState;
  final VoidCallback onDefeated;
  final void Function(CampaignChapterBossPhase phase)? onPhaseChanged;
  final Rect? arenaBounds;
  CampaignChapterBossPhase phase = CampaignChapterBossPhase.dormant;

  SpriteComponent? _visual;
  List<Sprite>? _frames;
  late final CampaignChapterBossPatternSet _patternSet =
      CampaignChapterBossPatternCatalog.forBossId(kind.name);
  final CampaignBossAttackCycle _attackCycle = CampaignBossAttackCycle();
  double _clock = 0;
  double _attackCooldown = .9;
  double _phaseTransitionRemaining = 0;
  double _defeatRemaining = 0;
  final List<String> _recentAttacks = <String>[];
  final Set<Component> _spawnedHazards = <Component>{};
  Vector2? _recordedAttackOrigin;
  Vector2? _recordedAttackTarget;
  Vector2? _splitEchoWorld;
  double? _activeDamageWindowCap;
  int _hazardEpoch = 0;
  int _decisionCursor = 0;
  final Set<String> _completedAttackIdsInCurrentPhase = <String>{};
  bool _phaseThresholdReached = false;
  bool _resolved = false;
  bool _defeatDispatched = false;

  @override
  String get entityId => 'boss.${kind.name}';
  int get health => healthState.current;
  int get maxHealth => healthState.max;
  bool get hasArtV3Visual => _frames?.length == 8;
  CampaignBossAttackVisualPhase get attackVisualPhase => _attackCycle.phase;
  String? get visualAttackId => _attackCycle.attack?.id;
  double get attackVisualSecondsRemaining => _attackCycle.remaining;
  bool get hasCompletedAttackInCurrentPhase =>
      _completedAttackIdsInCurrentPhase.isNotEmpty;
  Set<String> get completedAttackIdsInCurrentPhase =>
      Set<String>.unmodifiable(_completedAttackIdsInCurrentPhase);
  bool get hasCompletedRepresentativePatternsInCurrentPhase =>
      _completedAttackIdsInCurrentPhase.length >=
      CampaignBossPhaseGateSpec.requiredDistinctPatternsPerPhase;
  bool get isPhaseTransitioning => _phaseTransitionRemaining > 0;
  double get phaseTransitionSecondsRemaining => _phaseTransitionRemaining;
  int get spawnedHazardCount => _spawnedHazards.length;
  String get patternFingerprint => _patternSet.fingerprint;
  List<String> get activePhasePatternIds => isActive
      ? _patternSet.patternIdsForPhaseIndex(_activePhaseIndex)
      : const <String>[];
  Vector2? get attackEchoPosition => _splitEchoWorld?.clone();
  int get diagnosticVisualFrameIndex => _resolveVisualFrameIndex();
  bool get isActive => switch (phase) {
    CampaignChapterBossPhase.phaseOne ||
    CampaignChapterBossPhase.phaseTwo ||
    CampaignChapterBossPhase.phaseThree => true,
    _ => false,
  };

  String get phaseId => switch (phase) {
    CampaignChapterBossPhase.dormant => '${kind.phasePrefix}_dormant',
    CampaignChapterBossPhase.intro => '${kind.phasePrefix}_intro',
    CampaignChapterBossPhase.phaseOne => '${kind.phasePrefix}_phase1',
    CampaignChapterBossPhase.phaseTwo => '${kind.phasePrefix}_phase2',
    CampaignChapterBossPhase.phaseThree => '${kind.phasePrefix}_phase3',
    CampaignChapterBossPhase.defeated => '${kind.phasePrefix}_defeated',
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
        text: game.localization.text(kind.enemyLocalizationKey),
        position: Vector2(size.x / 2, -18),
        anchor: Anchor.bottomCenter,
        textRenderer: TextPaint(
          style: TextStyle(
            fontFamily: 'PatchWorldCJK',
            color: kind.accentColor,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ),
    );
    unawaited(_loadVisual());
  }

  Future<void> _loadVisual() async {
    try {
      final image = await game.images.load(
        'sprites/art_v3/enemies/${kind.assetSlug}.png',
      );
      if (isRemoving) return;
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
        size: Vector2.all(144),
        position: size / 2,
        anchor: Anchor.center,
        priority: 2,
      )..paint.filterQuality = FilterQuality.none;
      _visual = visual;
      await add(visual);
    } catch (_) {
      // Procedural rendering remains available if an optional strip fails.
    }
  }

  void beginIntro() {
    if (phase != CampaignChapterBossPhase.dormant) return;
    phase = CampaignChapterBossPhase.intro;
    onPhaseChanged?.call(phase);
    game.publishUiSnapshot(force: true);
  }

  void activate() {
    if (phase != CampaignChapterBossPhase.intro) return;
    phase = CampaignChapterBossPhase.phaseOne;
    _attackCooldown = .6;
    _completedAttackIdsInCurrentPhase.clear();
    _phaseThresholdReached = false;
    _phaseTransitionRemaining = 0;
    onPhaseChanged?.call(phase);
    game.publishUiSnapshot(force: true);
  }

  @override
  void receiveDamage(int amount) {
    if (!isActive || amount <= 0 || isPhaseTransitioning) return;
    final healthFloor = CampaignBossPhaseGateSpec.healthFloorForPhaseIndex(
      _activePhaseIndex,
    );
    final acceptedDamage = math.min(
      amount,
      math.max(0, healthState.current - healthFloor),
    );
    if (acceptedDamage > 0) healthState.applyDamage(acceptedDamage);
    if (healthState.current > healthFloor) return;
    _phaseThresholdReached = true;
    _tryAdvancePhaseGate();
  }

  @override
  void receiveHealing(int amount) {
    if (!isActive || amount <= 0 || isPhaseTransitioning) return;
    healthState.applyHealing(amount);
    final healthFloor = CampaignBossPhaseGateSpec.healthFloorForPhaseIndex(
      _activePhaseIndex,
    );
    if (healthState.current > healthFloor) _phaseThresholdReached = false;
  }

  void _beginDefeat() {
    if (_resolved) return;
    _resolved = true;
    if (!healthState.isDefeated) {
      healthState.applyDamage(healthState.current);
    }
    phase = CampaignChapterBossPhase.defeated;
    _phaseTransitionRemaining = 0;
    _completedAttackIdsInCurrentPhase.clear();
    _phaseThresholdReached = false;
    onPhaseChanged?.call(phase);
    _attackCycle.reset();
    _recordedAttackOrigin = null;
    _recordedAttackTarget = null;
    _splitEchoWorld = null;
    _removeSpawnedHazards();
    _defeatRemaining = 1.1;
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  int get _activePhaseIndex => switch (phase) {
    CampaignChapterBossPhase.phaseOne => 0,
    CampaignChapterBossPhase.phaseTwo => 1,
    CampaignChapterBossPhase.phaseThree => 2,
    _ => throw StateError('$phase is not an active boss phase.'),
  };

  void _tryAdvancePhaseGate() {
    if (!_phaseThresholdReached ||
        !hasCompletedRepresentativePatternsInCurrentPhase) {
      return;
    }
    switch (phase) {
      case CampaignChapterBossPhase.phaseOne:
        _beginPhaseTransition(CampaignChapterBossPhase.phaseTwo);
      case CampaignChapterBossPhase.phaseTwo:
        _beginPhaseTransition(CampaignChapterBossPhase.phaseThree);
      case CampaignChapterBossPhase.phaseThree:
        _beginDefeat();
      case CampaignChapterBossPhase.dormant ||
          CampaignChapterBossPhase.intro ||
          CampaignChapterBossPhase.defeated:
        return;
    }
  }

  void _beginPhaseTransition(CampaignChapterBossPhase nextPhase) {
    phase = nextPhase;
    _phaseTransitionRemaining =
        CampaignBossPhaseGateSpec.transitionQuietSeconds;
    _completedAttackIdsInCurrentPhase.clear();
    _phaseThresholdReached = false;
    _attackCooldown = 0;
    _attackCycle.reset();
    _clearAttackDiagnostics();
    _removeSpawnedHazards();
    scale.setAll(1.12);
    onPhaseChanged?.call(phase);
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  @override
  void update(double dt) {
    final sampledEnemyDt = isMounted ? game.clock.enemyDt : dt;
    final enemyDt = sampledEnemyDt > 0 && sampledEnemyDt.isFinite
        ? sampledEnemyDt
        : 0.0;
    _clock += enemyDt;
    if (phase == CampaignChapterBossPhase.defeated) {
      final sampledPresentationDt = isMounted ? game.clock.realDt : dt;
      final presentationDt =
          sampledPresentationDt > 0 && sampledPresentationDt.isFinite
          ? sampledPresentationDt
          : 0.0;
      _defeatRemaining = math.max(0, _defeatRemaining - presentationDt);
      final progress = 1 - _defeatRemaining / 1.1;
      scale.setAll(1 + math.sin(progress * math.pi * 7).abs() * .13);
      angle = math.sin(progress * math.pi * 9) * .04;
      if (_defeatRemaining <= 0) _finishDefeat();
      _syncVisual();
      super.update(dt);
      return;
    }
    if (!isActive) {
      _syncVisual();
      super.update(dt);
      return;
    }
    if (_phaseTransitionRemaining > 0) {
      final sampledTransitionDt = isMounted ? game.clock.realDt : dt;
      final transitionDt =
          sampledTransitionDt > 0 && sampledTransitionDt.isFinite
          ? sampledTransitionDt
          : 0.0;
      _phaseTransitionRemaining = math.max(
        0,
        _phaseTransitionRemaining - transitionDt,
      );
      final transitionProgress =
          _phaseTransitionRemaining /
          CampaignBossPhaseGateSpec.transitionQuietSeconds;
      scale.setAll(1 + transitionProgress * .12);
      if (_phaseTransitionRemaining <= 0) scale.setAll(1);
      _syncVisual();
      super.update(dt);
      return;
    }
    if (enemyDt > 0) {
      if (_attackCycle.isIdle) {
        _attackCooldown = math.max(0, _attackCooldown - enemyDt);
      }
      final advancingAttack = _attackCycle.attack;
      final events = _attackCycle.advance(enemyDt);
      if (advancingAttack != null) {
        final hasLiveExecutionWindow = campaignBossHasLiveExecutionWindow(
          events,
          _attackCycle.phase,
        );
        for (final event in events) {
          switch (event) {
            case CampaignBossAttackCycleEvent.execute:
              if (hasLiveExecutionWindow) {
                _activeDamageWindowCap = _attackCycle.remaining;
                try {
                  _executeAttack(advancingAttack.id);
                } finally {
                  _activeDamageWindowCap = null;
                }
              }
            case CampaignBossAttackCycleEvent.activeEnded:
              _finishAttackMotion(advancingAttack.id);
            case CampaignBossAttackCycleEvent.recovered:
              _clearAttackDiagnostics();
              _completedAttackIdsInCurrentPhase.add(advancingAttack.id);
              _tryAdvancePhaseGate();
              if (!isPhaseTransitioning && isActive) {
                _attackCooldown = switch (phase) {
                  CampaignChapterBossPhase.phaseThree => .85,
                  CampaignChapterBossPhase.phaseTwo => 1.05,
                  _ => 1.30,
                };
              }
          }
        }
      }
      if (isActive &&
          !isPhaseTransitioning &&
          _attackCycle.isIdle &&
          _attackCooldown <= 0) {
        _telegraph(_chooseAttack());
      }
    }
    _syncVisual();
    super.update(dt);
  }

  CampaignChapterBossAttackSpec _chooseAttack() {
    final distance = game.world.player.position.distanceTo(position);
    final phasePatterns = _patternSet.patternIdsForPhaseIndex(
      _activePhaseIndex,
    );
    if (!hasCompletedRepresentativePatternsInCurrentPhase) {
      for (final patternId in phasePatterns) {
        if (_completedAttackIdsInCurrentPhase.contains(patternId)) continue;
        _rememberAttackChoice(patternId);
        return _patternSet.byId(patternId);
      }
    }
    final spatialCandidates = switch (kind) {
      CampaignChapterBossKind.chronoJailer => <String>[
        if (distance < 210) 'rewindCharge',
        if (distance >= 130) 'clockFan',
        if (phase != CampaignChapterBossPhase.phaseOne) 'timeCage',
        if (phase == CampaignChapterBossPhase.phaseThree) 'hourglassMine',
        'clockSweep',
      ],
      CampaignChapterBossKind.kernelChimera => <String>[
        if (distance < 220) 'mergeSlam',
        if (distance >= 120) 'splitKernel',
        if (phase != CampaignChapterBossPhase.phaseOne) 'polarityCross',
        if (phase == CampaignChapterBossPhase.phaseThree) 'vectorCage',
        'gravityShard',
      ],
    }.where(phasePatterns.contains).toList(growable: true);
    for (final patternId in phasePatterns) {
      if (spatialCandidates.length >= 2) break;
      if (!spatialCandidates.contains(patternId)) {
        spatialCandidates.add(patternId);
      }
    }
    final unseenCandidates = spatialCandidates
        .where((id) => !_completedAttackIdsInCurrentPhase.contains(id))
        .toList(growable: false);
    final selectionCandidates = unseenCandidates.isEmpty
        ? spatialCandidates
        : unseenCandidates;
    final filtered = selectionCandidates
        .where((id) => !_recentAttacks.take(2).contains(id))
        .toList(growable: false);
    final pool = filtered.isEmpty ? selectionCandidates : filtered;
    final chosen = pool[_decisionCursor % pool.length];
    _rememberAttackChoice(chosen);
    return _patternSet.byId(chosen);
  }

  void _rememberAttackChoice(String attackId) {
    _decisionCursor += 1;
    _recentAttacks.insert(0, attackId);
    if (_recentAttacks.length > 3) _recentAttacks.removeLast();
  }

  void _telegraph(CampaignChapterBossAttackSpec attack) {
    if (!_attackCycle.start(attack)) return;
    _recordedAttackOrigin = position.clone();
    _recordedAttackTarget = game.world.player.position.clone();
    _splitEchoWorld = null;
    unawaited(
      game.audio.playEnemyAttack('${kind.name}.telegraph.${attack.id}'),
    );
  }

  void _executeAttack(String attack) {
    final owner = parent;
    if (owner == null || isRemoving) return;
    unawaited(game.audio.playEnemyAttack('${kind.name}.$attack'));
    switch (attack) {
      case 'rewindCharge':
        _executeRewindCharge(owner);
      case 'mergeSlam':
        _executeMergeSlam(owner);
      case 'clockSweep':
        _executeClockSweep(owner);
      case 'clockFan':
        _executeClockFan(owner);
      case 'splitKernel':
        _executeSplitKernel(owner);
      case 'polarityCross':
        _executePolarityCross(owner);
      case 'timeCage':
        _executeTimeCage(owner);
      case 'vectorCage':
        _executeVectorCage(owner);
      case 'hourglassMine':
        _executeHourglassMine(owner);
      case 'gravityShard':
        _executeGravityShard(owner);
    }
  }

  void _executeRewindCharge(Component owner) {
    final origin = _attackOrigin;
    final target = _attackTarget;
    final horizontal = target.x - origin.x;
    final facing = horizontal == 0 ? 1.0 : horizontal.sign.toDouble();
    final destination = _clampArenaPosition(
      target + Vector2(-facing * 116, -18),
    );
    _spawnDamageSegment(
      owner,
      origin,
      destination,
      thickness: 56,
      sourceId: 'enemy.chronoJailer.rewindCharge',
      activeSeconds: .28,
    );
    position.setFrom(destination);
    _splitEchoWorld = origin;
  }

  void _executeMergeSlam(Component owner) {
    final target = _attackTarget;
    final slamPosition = _clampArenaPosition(target + Vector2(0, -112));
    position.setFrom(slamPosition);
    _spawnDamageVolume(
      owner,
      position: target + Vector2(0, -42),
      size: Vector2(86, 178),
      sourceId: 'enemy.kernelChimera.mergeSlam.core',
      activeSeconds: .32,
    );
    for (final direction in <double>[-1, 1]) {
      _spawnDamageVolume(
        owner,
        position: target + Vector2(direction * 116, 34),
        size: Vector2(190, 28),
        sourceId: 'enemy.kernelChimera.mergeSlam.wave',
        activeSeconds: .28,
      );
    }
  }

  void _executeClockSweep(Component owner) {
    final center = _attackOrigin + Vector2(0, 16);
    final aim = _normalizedDirection(center, _attackTarget);
    final baseAngle = math.atan2(aim.y, aim.x);
    for (final offset in <double>[0, math.pi * 2 / 3, math.pi * 4 / 3]) {
      final direction = Vector2(1, 0)..rotate(baseAngle + offset);
      _spawnDamageSegment(
        owner,
        center + direction * 16,
        center + direction * 178,
        thickness: offset == 0 ? 34 : 25,
        sourceId: 'enemy.chronoJailer.clockSweep',
        activeSeconds: .30,
      );
    }
  }

  void _executeClockFan(Component owner) {
    final source = _attackOrigin;
    final aim = _normalizedDirection(source, _attackTarget);
    for (final angle in <double>[-.38, -.19, 0, .19, .38]) {
      final direction = aim.clone()..rotate(angle);
      _spawnProjectile(
        owner,
        position: source,
        velocity: direction * 280,
        sourceId: 'enemy.chronoJailer.clockFan',
        attackTier: angle == 0 ? AttackTier.parryable : AttackTier.normal,
        radius: angle == 0 ? 9 : 6,
      );
    }
  }

  void _executeTimeCage(Component owner) {
    final target = _attackTarget;
    final openRight = _attackOrigin.x <= target.x;
    for (final entry in <({Vector2 offset, Vector2 size})>[
      (offset: Vector2(openRight ? -104 : 104, 0), size: Vector2(30, 164)),
      (offset: Vector2(0, -102), size: Vector2(180, 28)),
      (offset: Vector2(0, 102), size: Vector2(180, 28)),
    ]) {
      _spawnDamageVolume(
        owner,
        position: target + entry.offset,
        size: entry.size,
        sourceId: 'enemy.chronoJailer.timeCage',
        activeSeconds: .30,
      );
    }
  }

  void _executeHourglassMine(Component owner) {
    final source = _attackOrigin;
    final target = _attackTarget;
    final facing = target.x >= source.x ? 1.0 : -1.0;
    for (final side in <double>[-1, 1]) {
      final crossingSpeed = 225 - side * facing * 42;
      _spawnProjectile(
        owner,
        position: source + Vector2(side * 36, -18),
        velocity: Vector2(facing * crossingSpeed, -275 + side * 32),
        sourceId: 'enemy.chronoJailer.hourglassMine',
        attackTier: side < 0 ? AttackTier.enhanced : AttackTier.parryable,
        radius: 10,
        gravity: 640,
        remainingBounces: 1,
      );
    }
    position.setFrom(_clampArenaPosition(source + Vector2(-facing * 48, -12)));
  }

  void _executeSplitKernel(Component owner) {
    final target = _attackTarget;
    final left = _clampArenaPosition(target + Vector2(-132, -28));
    final right = _clampArenaPosition(target + Vector2(132, -28));
    position.setFrom(left);
    _splitEchoWorld = right;
    for (final source in <Vector2>[left, right]) {
      final aim = _normalizedDirection(source, target);
      for (final angle in <double>[-.24, 0, .24]) {
        final direction = aim.clone()..rotate(angle);
        _spawnProjectile(
          owner,
          position: source,
          velocity: direction * 305,
          sourceId: 'enemy.kernelChimera.splitKernel',
          attackTier: angle == 0 ? AttackTier.parryable : AttackTier.normal,
          radius: angle == 0 ? 9 : 6,
        );
      }
    }
  }

  void _executePolarityCross(Component owner) {
    final target = _attackTarget;
    final left = _clampArenaPosition(target + Vector2(-82, -10));
    final right = _clampArenaPosition(target + Vector2(82, 10));
    position.setFrom(right);
    _splitEchoWorld = left;
    for (final source in <Vector2>[left, right]) {
      for (var index = 0; index < 4; index += 1) {
        final direction = Vector2(1, 0)..rotate(index * math.pi / 2);
        final pointsInward = source.x < target.x
            ? direction.x > .5
            : direction.x < -.5;
        _spawnProjectile(
          owner,
          position: source,
          velocity: direction * 288,
          sourceId: 'enemy.kernelChimera.polarityCross',
          attackTier: pointsInward ? AttackTier.parryable : AttackTier.normal,
          radius: pointsInward ? 9 : 6,
        );
      }
    }
  }

  void _executeVectorCage(Component owner) {
    final target = _attackTarget;
    final top = target + Vector2(0, -112);
    final right = target + Vector2(112, 0);
    final bottom = target + Vector2(0, 112);
    final left = target + Vector2(-112, 0);
    position.setFrom(_clampArenaPosition(target + Vector2(126, 72)));
    for (final edge in <({Vector2 start, Vector2 end})>[
      (start: top, end: right),
      (start: right, end: bottom),
      (start: bottom, end: left),
    ]) {
      _spawnDamageSegment(
        owner,
        edge.start,
        edge.end,
        thickness: 25,
        sourceId: 'enemy.kernelChimera.vectorCage',
        activeSeconds: .32,
      );
    }
  }

  void _executeGravityShard(Component owner) {
    final target = _attackTarget;
    final left = _clampArenaPosition(target + Vector2(-126, -12));
    final right = _clampArenaPosition(target + Vector2(126, -12));
    position.setFrom(right);
    _splitEchoWorld = left;
    for (final source in <Vector2>[left, right]) {
      final inward = source.x < target.x ? 1.0 : -1.0;
      for (final verticalOffset in <double>[-32, 22]) {
        _spawnProjectile(
          owner,
          position: source + Vector2(0, verticalOffset),
          velocity: Vector2(inward * 205, -285 - verticalOffset * .7),
          sourceId: 'enemy.kernelChimera.gravityShard',
          attackTier: verticalOffset < 0
              ? AttackTier.enhanced
              : AttackTier.parryable,
          radius: 10,
          gravity: 650,
          remainingBounces: 1,
        );
      }
    }
  }

  Vector2 get _attackOrigin =>
      _recordedAttackOrigin?.clone() ?? position.clone();

  Vector2 get _attackTarget =>
      _recordedAttackTarget?.clone() ?? game.world.player.position.clone();

  Vector2 _normalizedDirection(Vector2 from, Vector2 to) {
    final direction = to - from;
    if (direction.length2 == 0) direction.x = 1;
    direction.normalize();
    return direction;
  }

  Vector2 _clampArenaPosition(Vector2 desired) {
    final room = game.world.activeRoom;
    if (room == null || room is! PlatformerRoomGeometry) return desired;
    final geometry = room as PlatformerRoomGeometry;
    final authoredArena = arenaBounds;
    if (authoredArena != null) {
      return clampPositionToArena(
        desired,
        arenaBounds: authoredArena,
        bossSize: size,
        killPlaneY: geometry.killPlaneY,
      );
    }
    const minimumX = 64.0;
    const minimumY = 64.0;
    final maximumX = math.max(minimumX, geometry.worldSize.x - minimumX);
    final maximumY = math.max(
      minimumY,
      math.min(geometry.worldSize.y - 70, geometry.killPlaneY - 70),
    );
    return Vector2(
      desired.x.clamp(minimumX, maximumX).toDouble(),
      desired.y.clamp(minimumY, maximumY).toDouble(),
    );
  }

  /// Keeps teleport, split, and charge destinations inside the authored seals.
  static Vector2 clampPositionToArena(
    Vector2 desired, {
    required Rect arenaBounds,
    required Vector2 bossSize,
    required double killPlaneY,
  }) {
    final minimumX = arenaBounds.left + bossSize.x / 2;
    final minimumY = arenaBounds.top + bossSize.y / 2;
    final maximumX = math.max(minimumX, arenaBounds.right - bossSize.x / 2);
    final maximumY = math.max(
      minimumY,
      math.min(arenaBounds.bottom - bossSize.y / 2, killPlaneY - 70),
    );
    return Vector2(
      desired.x.clamp(minimumX, maximumX).toDouble(),
      desired.y.clamp(minimumY, maximumY).toDouble(),
    );
  }

  void _spawnDamageSegment(
    Component owner,
    Vector2 start,
    Vector2 end, {
    required double thickness,
    required String sourceId,
    required double activeSeconds,
  }) {
    final cappedSeconds = math.min(
      activeSeconds,
      _activeDamageWindowCap ?? activeSeconds,
    );
    if (cappedSeconds <= 0) return;
    final delta = end - start;
    if (delta.length2 == 0) return;
    final volume = EnemyDamageVolumeComponent(
      position: (start + end) / 2,
      size: Vector2(delta.length, thickness),
      sourceId: sourceId,
      activeSeconds: cappedSeconds,
      volumeColor: kind.accentColor.withAlpha(120),
    )..angle = math.atan2(delta.y, delta.x);
    unawaited(_addToOwner(owner, volume));
  }

  void _spawnDamageVolume(
    Component owner, {
    required Vector2 position,
    required Vector2 size,
    required String sourceId,
    required double activeSeconds,
  }) {
    final cappedSeconds = math.min(
      activeSeconds,
      _activeDamageWindowCap ?? activeSeconds,
    );
    if (cappedSeconds <= 0) return;
    unawaited(
      _addToOwner(
        owner,
        EnemyDamageVolumeComponent(
          position: position,
          size: size,
          sourceId: sourceId,
          activeSeconds: cappedSeconds,
          volumeColor: kind.accentColor.withAlpha(120),
        ),
      ),
    );
  }

  void _spawnProjectile(
    Component owner, {
    required Vector2 position,
    required Vector2 velocity,
    required String sourceId,
    required AttackTier attackTier,
    required double radius,
    double gravity = 0,
    int remainingBounces = 0,
  }) {
    unawaited(
      _addToOwner(
        owner,
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: velocity,
          sourceId: sourceId,
          attackTier: attackTier,
          gravity: gravity,
          remainingBounces: remainingBounces,
          projectileRadius: radius,
          assetSlug: kind.assetSlug,
        ),
      ),
    );
  }

  void _finishAttackMotion(String attack) {
    if (switch (attack) {
      'rewindCharge' ||
      'mergeSlam' ||
      'hourglassMine' ||
      'splitKernel' ||
      'polarityCross' ||
      'vectorCage' ||
      'gravityShard' => true,
      _ => false,
    }) {
      final origin = _recordedAttackOrigin;
      if (origin != null && !isRemoving) position.setFrom(origin);
    }
    _splitEchoWorld = null;
  }

  void _clearAttackDiagnostics() {
    _recordedAttackOrigin = null;
    _recordedAttackTarget = null;
    _splitEchoWorld = null;
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
    _spawnedHazards.add(child);
    unawaited(child.removed.then((_) => _spawnedHazards.remove(child)));
  }

  void _removeSpawnedHazards() {
    _hazardEpoch += 1;
    for (final hazard in _spawnedHazards.toList(growable: false)) {
      if (!hazard.isRemoving) hazard.removeFromParent();
    }
    _spawnedHazards.clear();
  }

  void _finishDefeat() {
    if (_defeatDispatched || isRemoving) return;
    _defeatDispatched = true;
    game.world.spawnDataShards(position, count: 8, corrupted: false);
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
      size.y / 2 + math.sin(_clock * 2.2) * .35,
    );
    final phaseProgress = _attackCycle.phaseProgress;
    final pulse = switch (_attackCycle.phase) {
      CampaignBossAttackVisualPhase.idle => 1.0,
      CampaignBossAttackVisualPhase.telegraph =>
        1 + math.sin(phaseProgress * math.pi / 2) * .07,
      CampaignBossAttackVisualPhase.active => 1.08,
      CampaignBossAttackVisualPhase.recovery => 1 + (1 - phaseProgress) * .025,
    };
    visual.scale.setAll(pulse);
  }

  int _resolveVisualFrameIndex() {
    if (phase == CampaignChapterBossPhase.dormant) return 0;
    if (phase == CampaignChapterBossPhase.intro) {
      return 2 + ((_clock * 6).floor() % 2);
    }
    if (phase == CampaignChapterBossPhase.defeated) return 7;
    final attackFrame = resolveCampaignBossAttackFrame(
      _attackCycle.phase,
      _attackCycle.phaseProgress,
    );
    if (attackFrame >= 0) return attackFrame;
    return switch (phase) {
      CampaignChapterBossPhase.phaseOne => 0,
      CampaignChapterBossPhase.phaseTwo => 1,
      CampaignChapterBossPhase.phaseThree => 3,
      _ => 0,
    };
  }

  @override
  void render(Canvas canvas) {
    if (_visual == null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(7, 10, size.x - 14, size.y - 12),
          const Radius.circular(9),
        ),
        Paint()..color = kind.accentColor.withAlpha(170),
      );
    }
    switch (_attackCycle.phase) {
      case CampaignBossAttackVisualPhase.idle:
        break;
      case CampaignBossAttackVisualPhase.telegraph:
        _renderPatternTelegraph(canvas);
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          52 + _attackCycle.phaseProgress * 7,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..color = kind.accentColor,
        );
      case CampaignBossAttackVisualPhase.active:
        canvas.drawArc(
          Rect.fromCircle(center: Offset(size.x / 2, size.y / 2), radius: 58),
          -math.pi / 2,
          math.pi * 1.55,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round
            ..color = kind.accentColor,
        );
        final origin = _recordedAttackOrigin;
        if (origin != null && origin.distanceTo(position) > 8) {
          canvas.drawLine(
            _localOffset(origin),
            Offset(size.x / 2, size.y / 2),
            Paint()
              ..strokeWidth = 3
              ..color = kind.accentColor.withAlpha(110),
          );
        }
      case CampaignBossAttackVisualPhase.recovery:
        canvas.drawCircle(
          Offset(size.x / 2, size.y / 2),
          48,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = kind.accentColor.withAlpha(95),
        );
    }
    final echo = _splitEchoWorld;
    if (echo != null) {
      _renderAttackEcho(canvas, echo);
    }
    super.render(canvas);
  }

  void _renderAttackEcho(Canvas canvas, Vector2 echo) {
    final center = _localOffset(echo);
    final attack = _attackCycle.attack?.id;
    final echoColor = kind.accentColor.withAlpha(145);
    canvas.drawLine(
      Offset(size.x / 2, size.y / 2),
      center,
      Paint()
        ..strokeWidth = attack == 'rewindCharge' ? 3 : 2
        ..color = echoColor.withAlpha(90),
    );
    if (attack == 'rewindCharge') {
      for (var ring = 0; ring < 3; ring += 1) {
        canvas.drawCircle(
          center,
          24 + ring * 9,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 - ring * .6
            ..color = echoColor.withAlpha(145 - ring * 32),
        );
      }
      return;
    }
    final body = Rect.fromCenter(center: center, width: 58, height: 72);
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(12)),
      Paint()..color = echoColor.withAlpha(38),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(12)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = echoColor,
    );
    canvas.drawCircle(center, 10, Paint()..color = echoColor.withAlpha(120));
    if (attack == 'polarityCross' || attack == 'gravityShard') {
      canvas.drawLine(
        center - const Offset(25, 0),
        center + const Offset(25, 0),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFFFF4FD8).withAlpha(155),
      );
      canvas.drawLine(
        center - const Offset(0, 25),
        center + const Offset(0, 25),
        Paint()
          ..strokeWidth = 3
          ..color = const Color(0xFF36E1FF).withAlpha(155),
      );
    }
  }

  void _renderPatternTelegraph(Canvas canvas) {
    final attack = _attackCycle.attack?.id;
    final target = _recordedAttackTarget;
    if (attack == null || target == null) return;
    final center = Offset(size.x / 2, size.y / 2);
    final targetOffset = _localOffset(target);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = kind.accentColor.withAlpha(155);
    switch (attack) {
      case 'rewindCharge':
        canvas.drawLine(center, targetOffset, paint..strokeWidth = 8);
        canvas.drawCircle(center, 24, paint..strokeWidth = 2.5);
      case 'clockFan':
        final aim = _normalizedDirection(position, target);
        for (final angle in <double>[-.38, 0, .38]) {
          final direction = aim.clone()..rotate(angle);
          canvas.drawLine(
            center,
            center + Offset(direction.x, direction.y) * 190,
            paint,
          );
        }
      case 'timeCage':
        final openRight = (_recordedAttackOrigin?.x ?? position.x) <= target.x;
        canvas.drawLine(
          targetOffset + const Offset(-104, -102),
          targetOffset + const Offset(104, -102),
          paint..strokeWidth = 5,
        );
        canvas.drawLine(
          targetOffset + const Offset(-104, 102),
          targetOffset + const Offset(104, 102),
          paint,
        );
        final wallX = openRight ? -104.0 : 104.0;
        canvas.drawLine(
          targetOffset + Offset(wallX, -102),
          targetOffset + Offset(wallX, 102),
          paint,
        );
      case 'hourglassMine':
        canvas.drawArc(
          Rect.fromCenter(center: center, width: 260, height: 190),
          math.pi * .12,
          math.pi * .76,
          false,
          paint,
        );
        canvas.drawArc(
          Rect.fromCenter(center: center, width: 260, height: 190),
          math.pi * .88,
          math.pi * .76,
          false,
          paint,
        );
      case 'clockSweep':
        final aim = _normalizedDirection(position, target);
        final baseAngle = math.atan2(aim.y, aim.x);
        for (final offset in <double>[0, math.pi * 2 / 3, math.pi * 4 / 3]) {
          final direction = Vector2(1, 0)..rotate(baseAngle + offset);
          canvas.drawLine(
            center,
            center + Offset(direction.x, direction.y) * 178,
            paint,
          );
        }
      case 'mergeSlam':
        canvas.drawRect(
          Rect.fromCenter(center: targetOffset, width: 86, height: 178),
          paint..strokeWidth = 5,
        );
        canvas.drawLine(
          targetOffset + const Offset(-210, 48),
          targetOffset + const Offset(210, 48),
          paint,
        );
      case 'splitKernel':
        for (final side in <double>[-1, 1]) {
          canvas.drawCircle(
            targetOffset + Offset(side * 132, -28),
            34,
            paint..strokeWidth = 4,
          );
        }
        canvas.drawLine(
          targetOffset + const Offset(-132, -28),
          targetOffset + const Offset(132, -28),
          paint..strokeWidth = 2.5,
        );
      case 'polarityCross':
        for (final side in <double>[-1, 1]) {
          final polarityCenter = targetOffset + Offset(side * 82, side * 10);
          canvas.drawLine(
            polarityCenter - const Offset(62, 0),
            polarityCenter + const Offset(62, 0),
            paint,
          );
          canvas.drawLine(
            polarityCenter - const Offset(0, 62),
            polarityCenter + const Offset(0, 62),
            paint,
          );
        }
      case 'vectorCage':
        final path = Path()
          ..moveTo(targetOffset.dx, targetOffset.dy - 112)
          ..lineTo(targetOffset.dx + 112, targetOffset.dy)
          ..lineTo(targetOffset.dx, targetOffset.dy + 112)
          ..lineTo(targetOffset.dx - 112, targetOffset.dy);
        canvas.drawPath(path, paint..strokeWidth = 5);
      case 'gravityShard':
        for (final side in <double>[-1, 1]) {
          canvas.drawArc(
            Rect.fromCenter(
              center: targetOffset + Offset(side * 68, 24),
              width: 190,
              height: 170,
            ),
            side < 0 ? math.pi * 1.08 : math.pi * .16,
            math.pi * .76,
            false,
            paint,
          );
        }
    }
  }

  Offset _localOffset(Vector2 worldPosition) => Offset(
    size.x / 2 + worldPosition.x - position.x,
    size.y / 2 + worldPosition.y - position.y,
  );

  @override
  void onRemove() {
    _removeSpawnedHazards();
    super.onRemove();
  }
}
