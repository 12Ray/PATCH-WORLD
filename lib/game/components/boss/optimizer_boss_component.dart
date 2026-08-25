import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
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

enum OptimizerAttackPattern {
  analysisRing,
  analysisCross,
  analysisSweep,
  predictionTrail,
  predictionPincer,
  predictionSpiral,
  perfectChecksum,
  perfectPressure,
  perfectCross,
}

extension OptimizerAttackPatternSpec on OptimizerAttackPattern {
  OptimizerPhase get phase => switch (this) {
    OptimizerAttackPattern.analysisRing ||
    OptimizerAttackPattern.analysisCross ||
    OptimizerAttackPattern.analysisSweep => OptimizerPhase.analyze,
    OptimizerAttackPattern.predictionTrail ||
    OptimizerAttackPattern.predictionPincer ||
    OptimizerAttackPattern.predictionSpiral => OptimizerPhase.predict,
    OptimizerAttackPattern.perfectChecksum ||
    OptimizerAttackPattern.perfectPressure ||
    OptimizerAttackPattern.perfectCross => OptimizerPhase.perfect,
  };

  String get sourceId => 'boss.optimizer.$name';
}

/// Fixed-order phase decks make captures and tests reproducible while also
/// guaranteeing that every phase demonstrates all three patterns before one
/// can repeat.
final class OptimizerAttackDeck {
  static const Map<OptimizerPhase, List<OptimizerAttackPattern>> patterns =
      <OptimizerPhase, List<OptimizerAttackPattern>>{
        OptimizerPhase.analyze: <OptimizerAttackPattern>[
          OptimizerAttackPattern.analysisRing,
          OptimizerAttackPattern.analysisCross,
          OptimizerAttackPattern.analysisSweep,
        ],
        OptimizerPhase.predict: <OptimizerAttackPattern>[
          OptimizerAttackPattern.predictionTrail,
          OptimizerAttackPattern.predictionPincer,
          OptimizerAttackPattern.predictionSpiral,
        ],
        OptimizerPhase.perfect: <OptimizerAttackPattern>[
          OptimizerAttackPattern.perfectChecksum,
          OptimizerAttackPattern.perfectPressure,
          OptimizerAttackPattern.perfectCross,
        ],
      };

  final Map<OptimizerPhase, int> _cursors = <OptimizerPhase, int>{};

  OptimizerAttackPattern next(OptimizerPhase phase) {
    final deck = patterns[phase];
    if (deck == null) {
      throw StateError('${phase.name} has no live Optimizer attack deck.');
    }
    final cursor = _cursors[phase] ?? 0;
    _cursors[phase] = cursor + 1;
    return deck[cursor % deck.length];
  }

  void reset(OptimizerPhase phase) => _cursors[phase] = 0;
}

/// Phase transition gate shared by the runtime boss and deterministic tests.
/// A large opening hit can reach the current phase's health floor, but it
/// cannot erase the two authored patterns that teach the phase vocabulary.
final class OptimizerPatternGate {
  static const int requiredUniquePatterns = 2;

  final Map<OptimizerPhase, Set<OptimizerAttackPattern>> _resolved =
      <OptimizerPhase, Set<OptimizerAttackPattern>>{};

  void recordResolved(OptimizerAttackPattern pattern) {
    _resolved
        .putIfAbsent(pattern.phase, () => <OptimizerAttackPattern>{})
        .add(pattern);
  }

  int resolvedCount(OptimizerPhase phase) => _resolved[phase]?.length ?? 0;

  bool allowsTransition(OptimizerPhase phase) =>
      resolvedCount(phase) >= requiredUniquePatterns;
}

final class OptimizerBossComponent extends CircleComponent
    with CollisionCallbacks, HasGameReference<PatchWorldGame>
    implements CombatTarget, DuplicateSource {
  OptimizerBossComponent({
    required super.position,
    required this.onPerfectStateEntered,
    required this.onDefeated,
    this.onPhaseChanged,
    this.onCoreExposed,
    OptimizerPatternGate? patternGate,
    this.startsActive = true,
  }) : patternGate = patternGate ?? OptimizerPatternGate(),
       super(
         radius: 48,
         anchor: Anchor.center,
         paint: Paint()..color = const Color(0x00000000),
         priority: 18,
       );

  @override
  String get entityId => 'boss.optimizer';
  final void Function() onPerfectStateEntered;
  final void Function() onDefeated;
  final void Function(OptimizerPhase phase)? onPhaseChanged;
  final VoidCallback? onCoreExposed;
  final OptimizerPatternGate patternGate;
  final bool startsActive;
  final StabilityState stability = StabilityState();
  OptimizerPhase phase = OptimizerPhase.analyze;
  int health = 20;
  double _attackTimer = 1.2;
  int _attackIndex = 0;
  final OptimizerAttackDeck _attackDeck = OptimizerAttackDeck();
  final List<OptimizerAttackPattern> _recentPatterns =
      <OptimizerAttackPattern>[];
  OptimizerAttackPattern? _activePattern;
  bool _attackDispatching = false;
  bool _duplicateClaimed = false;
  EntitySpriteVisual? _visual;
  List<Sprite>? _analyzeFrames;
  List<Sprite>? _predictFrames;
  List<Sprite>? _perfectFrames;
  List<Sprite>? _overflowFrames;
  bool _artV3AnimationsLoaded = false;
  double _visualTime = 0;
  late bool _encounterActive = startsActive;
  Vector2? _homePosition;
  double _outroElapsed = 0;
  bool _coreExposureDispatched = false;
  bool _defeatDispatched = false;

  static const double collapseSeconds = 1.45;
  static const double outroSeconds = 3.35;
  static const double perfectOpeningGraceSeconds = 2.2;

  bool get hasArtV3Visual => _visual != null && _artV3AnimationsLoaded;
  bool get isEncounterActive => _encounterActive;
  bool get isOutroActive => phase == OptimizerPhase.overflow;
  bool get isCoreExposed =>
      phase == OptimizerPhase.overflow && _outroElapsed >= collapseSeconds;
  double get outroSecondsRemaining => math.max(0, outroSeconds - _outroElapsed);
  OptimizerAttackPattern? get activePattern => _activePattern;
  List<OptimizerAttackPattern> get recentPatterns =>
      List<OptimizerAttackPattern>.unmodifiable(_recentPatterns);
  int resolvedPatternCount(OptimizerPhase phase) =>
      patternGate.resolvedCount(phase);

  void activateEncounter() {
    _encounterActive = true;
    _attackTimer = 1.2;
  }

  @override
  Vector2 get duplicatePosition => position;
  @override
  DuplicateArchetype get duplicateArchetype => DuplicateArchetype.optimizer;
  @override
  bool claimDuplicate() {
    if (_duplicateClaimed ||
        phase == OptimizerPhase.perfect ||
        phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated) {
      return false;
    }
    _duplicateClaimed = true;
    return true;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _homePosition = position.clone();
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
    try {
      final artV3Analyze = await game.images.load(
        'sprites/art_v3/boss/optimizer-analyze.png',
      );
      final artV3Predict = await game.images.load(
        'sprites/art_v3/boss/optimizer-predict.png',
      );
      final artV3Perfect = await game.images.load(
        'sprites/art_v3/boss/optimizer-perfect.png',
      );
      final artV3Overflow = await game.images.load(
        'sprites/art_v3/boss/optimizer-overflow.png',
      );
      if (isRemoving) return;
      _analyzeFrames = _frames(artV3Analyze, 4);
      _predictFrames = _frames(artV3Predict, 4);
      _perfectFrames = _frames(artV3Perfect, 4);
      _overflowFrames = _frames(artV3Overflow, 4);
      _artV3AnimationsLoaded = true;
    } catch (_) {
      // Existing phase strips remain the isolated fallback for Art v3.
    }
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
        final frames = _analyzeFrames;
        if (frames != null) visual.setDefaultAnimation(frames, fps: 6);
      case OptimizerPhase.predict:
        final frames = _predictFrames;
        if (frames != null) visual.setDefaultAnimation(frames, fps: 8);
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
    if (phase == OptimizerPhase.overflow) {
      _advanceOutro(isMounted ? game.clock.realDt : dt);
      super.update(dt);
      return;
    }
    if (!_encounterActive) {
      super.update(dt);
      return;
    }
    if (phase == OptimizerPhase.defeated) {
      super.update(dt);
      return;
    }
    final enemyDt = game.clock.enemyDt;
    if (enemyDt > 0) {
      _updatePhaseMovement(enemyDt);
      _attackTimer -= enemyDt;
      if (_attackTimer <= 0) {
        _attackTimer = switch (phase) {
          OptimizerPhase.analyze => 1.48,
          OptimizerPhase.predict => 1.12,
          OptimizerPhase.perfect => 1.62,
          OptimizerPhase.overflow || OptimizerPhase.defeated => 99,
        };
        unawaited(_performNextAttack());
      }
    }
    super.update(dt);
  }

  Future<void> _performNextAttack() async {
    if (_attackDispatching ||
        !isMounted ||
        !_encounterActive ||
        phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated) {
      return;
    }
    _attackDispatching = true;
    _attackIndex += 1;
    final attackPhase = phase;
    final pattern = _attackDeck.next(attackPhase);
    _activePattern = pattern;
    _recentPatterns.add(pattern);
    if (_recentPatterns.length > 9) _recentPatterns.removeAt(0);
    try {
      final actionFrames = switch (attackPhase) {
        OptimizerPhase.analyze => _analyzeFrames,
        OptimizerPhase.predict => _predictFrames,
        OptimizerPhase.perfect => _perfectFrames,
        OptimizerPhase.overflow || OptimizerPhase.defeated => null,
      };
      if (actionFrames != null) _visual?.playOnce(actionFrames, fps: 10);
      _visual?.flash(
        attackPhase == OptimizerPhase.perfect
            ? const Color(0xFFF4F7FF)
            : const Color(0xFFFF4FD8),
        seconds: 0.16,
      );
      _visual?.squash(seconds: 0.24);
      unawaited(game.audio.playEnemyAttack(pattern.sourceId));
      switch (pattern) {
        case OptimizerAttackPattern.analysisRing:
          await _spawnRadialTelegraph(
            pattern,
            count: 8,
            speed: 158,
            rotation: math.pi / 8,
            parryEvery: 4,
          );
        case OptimizerAttackPattern.analysisCross:
          await _spawnStrikePattern(pattern, const <Offset>[
            Offset.zero,
            Offset(-112, 0),
            Offset(112, 0),
            Offset(0, -112),
          ], warningBase: .72);
        case OptimizerAttackPattern.analysisSweep:
          await _spawnStrikePattern(
            pattern,
            const <Offset>[
              Offset(-260, 0),
              Offset(-156, 0),
              Offset(-52, 0),
              Offset(52, 0),
              Offset(156, 0),
              Offset(260, 0),
            ],
            warningBase: .52,
            warningStep: .09,
            radius: 42,
          );
        case OptimizerAttackPattern.predictionTrail:
          final direction = _preferredPatternDirection();
          await _spawnStrikePattern(
            pattern,
            <Offset>[
              for (var index = 1; index <= 4; index += 1)
                Offset(direction.x, direction.y) * (68.0 * index),
            ],
            warningBase: .55,
            warningStep: .10,
            radius: 46,
          );
        case OptimizerAttackPattern.predictionPincer:
          await _spawnStrikePattern(
            pattern,
            const <Offset>[
              Offset(-150, 0),
              Offset(150, 0),
              Offset(-76, -96),
              Offset(76, -96),
              Offset.zero,
            ],
            warningBase: .68,
            warningStep: .07,
            radius: 44,
          );
        case OptimizerAttackPattern.predictionSpiral:
          await _spawnRadialTelegraph(
            pattern,
            count: 12,
            speed: 198,
            rotation: _attackIndex * .23,
            parryEvery: 3,
          );
        case OptimizerAttackPattern.perfectChecksum:
          await _spawnRadialTelegraph(
            pattern,
            count: 10,
            speed: 172,
            rotation: _attackIndex.isEven ? 0 : math.pi / 10,
            parryEvery: 2,
            warningSeconds: .64,
          );
        case OptimizerAttackPattern.perfectPressure:
          await _spawnStrikePattern(
            pattern,
            const <Offset>[
              Offset.zero,
              Offset(-128, -32),
              Offset(128, -32),
              Offset(-64, -128),
              Offset(64, -128),
            ],
            warningBase: .84,
            warningStep: .06,
            radius: 44,
          );
        case OptimizerAttackPattern.perfectCross:
          await _spawnStrikePattern(
            pattern,
            const <Offset>[
              Offset(-190, 0),
              Offset(190, 0),
              Offset(0, -190),
              Offset(-95, -95),
              Offset(95, -95),
            ],
            warningBase: .72,
            warningStep: .05,
            radius: 42,
          );
      }
    } finally {
      _attackDispatching = false;
    }
  }

  Future<void> _spawnRadialTelegraph(
    OptimizerAttackPattern pattern, {
    required int count,
    required double speed,
    required double rotation,
    required int parryEvery,
    double warningSeconds = .48,
  }) async {
    final host = parent;
    if (host == null) return;
    await game.world.tryAddCombatEffect(
      OptimizerVolleyTelegraphComponent(
        position: position.clone(),
        laneCount: count,
        warningSeconds: warningSeconds,
        onResolved: () => unawaited(
          _resolveRadialPattern(
            pattern,
            count: count,
            speed: speed,
            rotation: rotation,
            parryEvery: parryEvery,
          ),
        ),
      ),
      host: host,
    );
  }

  Future<void> _resolveRadialPattern(
    OptimizerAttackPattern pattern, {
    required int count,
    required double speed,
    required double rotation,
    required int parryEvery,
  }) async {
    await _spawnRadialVolley(
      pattern,
      count: count,
      speed: speed,
      rotation: rotation,
      parryEvery: parryEvery,
    );
    _recordPatternResolved(pattern);
  }

  Future<void> _spawnRadialVolley(
    OptimizerAttackPattern pattern, {
    required int count,
    required double speed,
    required double rotation,
    required int parryEvery,
  }) async {
    if (!isMounted || phase != pattern.phase || !_encounterActive) {
      return;
    }
    for (var i = 0; i < count; i += 1) {
      if (!game.world.canSpawnProjectile) break;
      final angle = math.pi * 2 * i / count + rotation;
      final parryable = parryEvery > 0 && i % parryEvery == 0;
      await parent?.add(
        EnemyProjectileComponent(
          position: position.clone(),
          velocity: Vector2(math.cos(angle), math.sin(angle)) * speed,
          sourceId: pattern.sourceId,
          attackTier: parryable ? AttackTier.parryable : AttackTier.normal,
          projectileRadius: parryable ? 9 : 7,
          projectileColor: switch (pattern.phase) {
            OptimizerPhase.analyze => const Color(0xFF36E1FF),
            OptimizerPhase.predict => const Color(0xFFFF4FD8),
            OptimizerPhase.perfect => const Color(0xFFF4F7FF),
            OptimizerPhase.overflow ||
            OptimizerPhase.defeated => const Color(0xFFFFD35A),
          },
          // Combat v2 has no Optimizer projectile sheet. A null slug is the
          // truthful contract and deliberately selects the tier-aware fallback.
          assetSlug: null,
        ),
      );
    }
  }

  Future<void> _spawnStrikePattern(
    OptimizerAttackPattern pattern,
    List<Offset> offsets, {
    required double warningBase,
    double warningStep = 0,
    double radius = 48,
  }) async {
    final host = parent;
    if (host == null || phase != pattern.phase) return;
    final target = game.world.player.position.clone();
    var addedStrike = false;
    for (var index = 0; index < offsets.length; index += 1) {
      final offset = offsets[index];
      final strikePosition = Vector2(
        (target.x + offset.dx).clamp(70, 1850).toDouble(),
        (target.y + offset.dy).clamp(80, 1004).toDouble(),
      );
      addedStrike |= await game.world.tryAddCombatEffect(
        PredictionStrikeComponent(
          position: strikePosition,
          warningSeconds: warningBase + warningStep * index,
          sourceId: pattern.sourceId,
          dangerColor: pattern.phase == OptimizerPhase.perfect
              ? const Color(0xFFFFD35A)
              : const Color(0xFFFF4FD8),
          strikeRadius: radius,
        ),
        host: host,
      );
    }
    if (!addedStrike || phase != pattern.phase) return;
    final finalWarning = warningBase + warningStep * (offsets.length - 1);
    await host.add(
      _OptimizerPatternResolutionTimer(
        duration: finalWarning,
        onResolved: () => _recordPatternResolved(pattern),
      ),
    );
  }

  void _recordPatternResolved(OptimizerAttackPattern pattern) {
    if (phase != pattern.phase || !_encounterActive) return;
    patternGate.recordResolved(pattern);
    _advanceHealthPhaseIfReady();
  }

  Vector2 _preferredPatternDirection() {
    final preferred = game.patternTracker.snapshot.preferredDirection;
    return switch (preferred) {
      DirectionBucket.up => Vector2(0, -1),
      DirectionBucket.down => Vector2(0, 1),
      DirectionBucket.left => Vector2(-1, 0),
      DirectionBucket.right => Vector2(1, 0),
      null => _attackIndex.isEven ? Vector2(1, 0) : Vector2(-1, 0),
    };
  }

  void _updatePhaseMovement(double dt) {
    final home = _homePosition;
    if (home == null) return;
    final player = game.world.player.position;
    final target = switch (phase) {
      OptimizerPhase.analyze => Vector2(
        home.x + math.sin(_visualTime * .72) * 118,
        home.y + 84 + math.sin(_visualTime * 1.1) * 20,
      ),
      OptimizerPhase.predict => Vector2(
        home.x * .62 + player.x * .38 + math.sin(_visualTime * 1.7) * 52,
        home.y + 100 + math.cos(_visualTime * 1.3) * 34,
      ),
      OptimizerPhase.perfect => Vector2(
        home.x + math.sin(_visualTime * 1.15) * 86,
        home.y + 120 + math.cos(_visualTime * .92) * 22,
      ),
      OptimizerPhase.overflow || OptimizerPhase.defeated => home.clone(),
    };
    target
      ..x = target.x.clamp(650, 1270).toDouble()
      ..y = target.y.clamp(360, 490).toDouble();
    final blend = 1 - math.exp(-dt * 2.4);
    position += (target - position) * blend;
  }

  void _advanceOutro(double dt) {
    if (dt <= 0 || _defeatDispatched) return;
    _outroElapsed = math.min(outroSeconds, _outroElapsed + dt);
    final collapseProgress = (_outroElapsed / collapseSeconds).clamp(0, 1);
    angle = math.sin(_outroElapsed * 16) * .08 * (1 - collapseProgress * .45);
    scale.setAll(1 + math.sin(_outroElapsed * 13).abs() * .12);
    if (!_coreExposureDispatched && _outroElapsed >= collapseSeconds) {
      _coreExposureDispatched = true;
      _visual?.setAnimationPlaying(false);
      _visual?.setStateTint(const Color(0xFFFFF3B0));
      onCoreExposed?.call();
    }
    if (_outroElapsed < outroSeconds) return;
    _defeatDispatched = true;
    phase = OptimizerPhase.defeated;
    onPhaseChanged?.call(phase);
    onDefeated();
    if (isMounted) removeFromParent();
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
    if (!_encounterActive ||
        amount <= 0 ||
        phase == OptimizerPhase.perfect ||
        phase == OptimizerPhase.overflow ||
        phase == OptimizerPhase.defeated) {
      return;
    }
    final phaseFloor = phase == OptimizerPhase.analyze ? 13 : 6;
    health = math.max(phaseFloor, health - amount);
    _visual?.flash(const Color(0xFFFFFFFF), seconds: 0.10);
    _advanceHealthPhaseIfReady();
  }

  void _advanceHealthPhaseIfReady() {
    if (phase == OptimizerPhase.analyze &&
        health <= 13 &&
        patternGate.allowsTransition(OptimizerPhase.analyze)) {
      phase = OptimizerPhase.predict;
      _attackDeck.reset(phase);
      _attackTimer = 1.35;
      _applyPhaseAnimation();
      onPhaseChanged?.call(phase);
      return;
    }
    if (phase == OptimizerPhase.predict &&
        health <= 6 &&
        patternGate.allowsTransition(OptimizerPhase.predict)) {
      phase = OptimizerPhase.perfect;
      stability.resetPerfectPhase();
      _attackDeck.reset(phase);
      _attackTimer = perfectOpeningGraceSeconds;
      _visual?.setStateTint(const Color(0xFFFFFFFF));
      _applyPhaseAnimation();
      onPhaseChanged?.call(phase);
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
    _encounterActive = false;
    _outroElapsed = 0;
    _coreExposureDispatched = false;
    _activePattern = null;
    _visual?.setStateTint(const Color(0xFFFF4FD8));
    _visual?.squash(seconds: 0.30);
    _applyPhaseAnimation();
    onPhaseChanged?.call(phase);
  }

  void resetFailedLegacyAttempt() {
    if (phase == OptimizerPhase.perfect) {
      stability.resetPerfectPhase();
      scale.setAll(1);
      _visual?.setStateTint(const Color(0xFFFFFFFF));
      _attackTimer = math.max(_attackTimer, 1.6);
    }
  }
}

final class _OptimizerPatternResolutionTimer extends Component
    with HasGameReference<PatchWorldGame> {
  _OptimizerPatternResolutionTimer({
    required double duration,
    required this.onResolved,
  }) : _remaining = duration;

  final VoidCallback onResolved;
  double _remaining;
  bool _resolved = false;

  @override
  void update(double dt) {
    final enemyDt = game.clock.enemyDt;
    if (!_resolved && enemyDt > 0) {
      _remaining -= enemyDt;
      if (_remaining <= 0) {
        _resolved = true;
        onResolved();
        removeFromParent();
      }
    }
    super.update(dt);
  }
}
