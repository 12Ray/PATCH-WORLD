import 'dart:async';
import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/text.dart';
import 'package:flutter/painting.dart';
import 'package:patch_world/game/components/enemies/composite_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';
import 'package:patch_world/game/components/enemies/phase_hound_component.dart';
import 'package:patch_world/game/components/enemies/optimizer_fragment_component.dart';
import 'package:patch_world/game/components/enemies/survival_anomaly_component.dart';
import 'package:patch_world/game/components/enemies/survival_nexus_boss_component.dart';
import 'package:patch_world/game/components/effects/temporal_storm_component.dart';
import 'package:patch_world/game/components/effects/volatile_cache_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/survival_terrain_component.dart';
import 'package:patch_world/game/components/environment/survival_region_objective_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';
import 'package:patch_world/game/survival/wave_director.dart';
import 'package:patch_world/game/survival/survival_balance.dart';
import 'package:patch_world/game/survival/survival_playtest_telemetry.dart';
import 'package:patch_world/game/survival/survival_phase_eleven.dart';
import 'package:patch_world/game/survival/survival_items.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

final class SurvivalArenaController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        PlatformerRoomCameraFollow {
  static const double phaseHoundSpawnInset = 60;
  static const double arenaWidth = SurvivalNexusLayout.worldWidth;
  static const double arenaHeight = SurvivalNexusLayout.worldHeight;

  static Vector2 clampSpawnPoint({
    required SurvivalSpawnPoint point,
    required double width,
    required double height,
    required double inset,
  }) => Vector2(
    point.x.clamp(inset, width - inset).toDouble(),
    point.y.clamp(inset, height - inset).toDouble(),
  );

  final SurvivalWaveDirector _director = SurvivalWaveDirector();
  final PhaseLeakController _phaseLeak = PhaseLeakController();
  @override
  final Vector2 playerSpawn = SurvivalNexusLayout.center;
  @override
  final Vector2 worldSize = Vector2(arenaWidth, arenaHeight);
  @override
  final double killPlaneY = arenaHeight + 160;
  @override
  final List<Rect> solidBounds = <Rect>[
    Rect.fromLTWH(0, 0, arenaWidth, 28),
    Rect.fromLTWH(0, arenaHeight - 28, arenaWidth, 28),
    Rect.fromLTWH(0, 0, 28, arenaHeight),
    Rect.fromLTWH(arenaWidth - 28, 0, 28, arenaHeight),
  ];

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) => playerSpawn.clone();

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) => playerPosition.clone();

  @override
  double cameraZoomFor(Vector2 playerPosition) => .92;

  @override
  double get horizontalCameraDeadZone => 78;

  @override
  double get verticalCameraDeadZone => 46;

  @override
  double get cameraFollowResponsiveness => 4.8;
  final List<({String text, Color color})> _alertQueue =
      <({String text, Color color})>[];
  double _spawnRemaining = 1.6;
  bool _spawning = false;
  int _spawnId = 0;
  int _lastWaveSecond = 0;
  int _lastCelebratedMinute = 0;
  int _nextCacheSecond = 30;
  int _cachePositionIndex = 0;
  bool _alertActive = false;
  bool _phaseHoundTutorialShown = false;
  late SurvivalDifficultyStage _lastDifficultyStage;
  int _lastPhaseElevenSecond = 0;
  SurvivalRegionEventPlan? _activeRegionEvent;
  SurvivalRegionObjectiveComponent? _regionObjective;
  double _regionEventRemaining = 0;
  double _regionEventProgress = 0;
  int _regionEventKills = 0;
  bool _riskCacheCarrying = false;
  bool _phaseElevenTransitioning = false;
  SurvivalNexusBossComponent? _activeNexusBoss;
  final List<PhaseWallComponent> _bossArenaWalls = <PhaseWallComponent>[];

  int? get milestoneBossHealth {
    final nexusBoss = _activeNexusBoss;
    if (nexusBoss != null && !nexusBoss.isRemoving) {
      return nexusBoss.health.current;
    }
    for (final fragment in children.whereType<OptimizerFragmentComponent>()) {
      if (!fragment.isRemoving) return fragment.health.current;
    }
    for (final composite in children.whereType<CompositeComponent>()) {
      if (!composite.isRemoving) return composite.health.current;
    }
    return null;
  }

  int? get milestoneBossMaxHealth {
    final nexusBoss = _activeNexusBoss;
    if (nexusBoss != null && !nexusBoss.isRemoving) {
      return nexusBoss.health.max;
    }
    for (final fragment in children.whereType<OptimizerFragmentComponent>()) {
      if (!fragment.isRemoving) return fragment.health.max;
    }
    for (final composite in children.whereType<CompositeComponent>()) {
      if (!composite.isRemoving) return composite.health.max;
    }
    return null;
  }

  String? get milestoneBossLabel {
    final nexusBoss = _activeNexusBoss;
    if (nexusBoss != null && !nexusBoss.isRemoving) {
      return '${game.localization.text(nexusBoss.kind.localizationKey)} P${nexusBoss.phase}';
    }
    if (children.whereType<OptimizerFragmentComponent>().any(
      (fragment) => !fragment.isRemoving,
    )) {
      return 'OPTIMIZER FRAGMENT';
    }
    if (children.whereType<CompositeComponent>().any(
      (composite) => !composite.isRemoving,
    )) {
      return 'COMPOSITE';
    }
    return null;
  }

  SurvivalDifficultyStage get currentDifficultyStage =>
      SurvivalBalanceCurve.stageForSecond(
        game.survivalRun.elapsedSeconds.floor(),
      );

  SurvivalRegionEventKind? get activeRegionEventKind =>
      _activeRegionEvent?.kind;
  SurvivalNexusRegion? get activeRegionEventRegion =>
      _activeRegionEvent?.region;
  double get regionEventProgress => _regionEventProgress;
  SurvivalNexusBossKind? get activeNexusBossKind => _activeNexusBoss?.kind;
  int? get activeNexusBossPhase => _activeNexusBoss?.phase;
  int get bossArenaBarrierCount => _bossArenaWalls.length;
  List<String> get activeBossPatternIds =>
      _activeNexusBoss?.activePatternIds ?? const <String>[];

  String get survivalObjectiveLabel {
    final boss = _activeNexusBoss;
    if (boss != null && !boss.isRemoving) {
      return game.localization.text(
        'survivalObjective.boss',
        parameters: <String, Object>{
          'boss': game.localization.text(boss.kind.localizationKey),
          'phase': boss.phase,
          'current': boss.health.current,
          'max': boss.health.max,
        },
      );
    }
    final event = _activeRegionEvent;
    if (event != null) {
      return game.localization.text(
        event.kind.objectiveLocalizationKey,
        parameters: <String, Object>{
          'region': game.localization.text(event.region.localizationKey),
          'progress': (_regionEventProgress * 100).round(),
          'seconds': _regionEventRemaining.ceil(),
        },
      );
    }
    return game.localization.text(
      'objective.survivalExplore',
      parameters: <String, Object>{
        'time': game.survivalRun.elapsedSeconds.floor(),
        'kills': game.survivalRun.kills,
        'regions': game.survivalRun.visitedRegionCount,
        'events': game.survivalRun.regionEventsCompleted,
      },
    );
  }

  double get enemySpeedMultiplier => SurvivalBalanceCurve.profileForSecond(
    game.survivalRun.elapsedSeconds.floor(),
  ).enemySpeedMultiplier;

  bool get isPhaseWindowOpen =>
      game.survivalModifiers.phaseWallsLeak &&
      _phaseLeak.phase == PhaseLeakPhase.open;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _lastWaveSecond = game.survivalRun.elapsedSeconds.floor();
    _lastCelebratedMinute = _lastWaveSecond ~/ 60;
    _nextCacheSecond = _nextCacheAfter(_lastWaveSecond);
    _lastDifficultyStage = currentDifficultyStage;
    _lastPhaseElevenSecond = math.max(0, _lastWaveSecond - 1);
    await add(
      RoomBackdropComponent(RoomBackdropStyle.survival, worldSize: worldSize),
    );
    await game.world.tryAddCombatEffect(
      TemporalStormComponent(worldSize: worldSize),
      host: this,
    );
    await addAll(
      solidBounds.map(
        (rect) => WallComponent(
          position: Vector2(rect.left, rect.top),
          size: Vector2(rect.width, rect.height),
          color: const Color(0x7725304A),
        ),
      ),
    );
    await addAll(
      SurvivalNexusRegion.values.map(
        (region) => SurvivalRelayPadComponent(
          position: region.objectivePosition,
          relayId: '${region.id}Relay',
        ),
      ),
    );
    for (final offset in <Vector2>[
      Vector2(-420, -180),
      Vector2(-300, 210),
      Vector2(-500, 40),
      Vector2(420, 180),
      Vector2(300, -210),
      Vector2(500, -40),
    ]) {
      await _spawnCrawler(playerSpawn + offset);
    }
    if (PatchWorldGame.survivalQaEnemyArtDemo) {
      await _spawnAnomaly(
        SurvivalAnomalyKind.riftStalker,
        position: playerSpawn + Vector2(-140, -70),
      );
      await _spawnAnomaly(
        SurvivalAnomalyKind.arcWarden,
        position: playerSpawn + Vector2(0, -150),
      );
      await _spawnAnomaly(
        SurvivalAnomalyKind.mineLayer,
        position: playerSpawn + Vector2(140, 70),
      );
    } else {
      await _spawnAnomaly(
        SurvivalAnomalyKind.riftStalker,
        position: playerSpawn + Vector2(540, -260),
      );
    }
  }

  @override
  void update(double dt) {
    final simulationDt =
        game.clock.simulationDt * PatchWorldGame.survivalQaTimeScale;
    game.survivalRun.update(simulationDt);
    _updateRegionVisits();
    _updatePhaseElevenMilestones();
    _updateRegionEvent(simulationDt);
    _updateDifficultyStage();
    _updateSurvivalMilestone();
    _updateVolatileCache();
    _updatePhaseLeak(simulationDt);
    if (game.world.isReady && !_spawning && simulationDt > 0) {
      _spawnRemaining -= simulationDt;
      if (_spawnRemaining <= 0) {
        _spawnRemaining = _spawnIntervalForSecond(
          game.survivalRun.elapsedSeconds.floor(),
        );
        _spawning = true;
        unawaited(_spawnWave().whenComplete(() => _spawning = false));
      }
    }
    super.update(dt);
  }

  double _spawnIntervalForSecond(int second) {
    return SurvivalBalanceCurve.profileForSecond(second).spawnIntervalSeconds;
  }

  void _updateDifficultyStage() {
    final stage = currentDifficultyStage;
    if (stage == _lastDifficultyStage) return;
    _lastDifficultyStage = stage;
    game.recordSurvivalMilestone(SurvivalMeaningfulEvent.stageTransition);
    _showAlert(
      game.localization.text(
        'survivalAlert.stageShift',
        parameters: <String, Object>{
          'stage': game.localization.text(stage.localizationKey),
        },
      ),
      switch (stage) {
        SurvivalDifficultyStage.boot => const Color(0xFF45F3A6),
        SurvivalDifficultyStage.escalation => const Color(0xFF36E1FF),
        SurvivalDifficultyStage.crisis => const Color(0xFFFF4FD8),
        SurvivalDifficultyStage.endless => const Color(0xFFFFC857),
      },
    );
    game.publishUiSnapshot(force: true);
  }

  void _updateRegionVisits() {
    final region = SurvivalNexusRegionSpec.forPosition(
      game.world.player.position,
    );
    if (region == null || !game.survivalRun.recordRegionVisited(region)) {
      return;
    }
    _showAlert(
      game.localization.text(
        'survivalAlert.regionEntered',
        parameters: <String, Object>{
          'region': game.localization.text(region.localizationKey),
          'count': game.survivalRun.visitedRegionCount,
        },
      ),
      const Color(0xFF36E1FF),
    );
    game.publishUiSnapshot(force: true);
  }

  void _updatePhaseElevenMilestones() {
    final second = game.survivalRun.elapsedSeconds.floor();
    if (second <= _lastPhaseElevenSecond) return;
    final previous = _lastPhaseElevenSecond;
    _lastPhaseElevenSecond = second;
    final bosses = SurvivalPhaseElevenDirector.bossesBetween(
      previousSecond: previous,
      currentSecond: second,
    );
    if (bosses.isNotEmpty) {
      unawaited(_startNexusBoss(bosses.last));
      return;
    }
    if (_activeNexusBoss != null || _phaseElevenTransitioning) return;
    final events = SurvivalPhaseElevenDirector.eventsBetween(
      previousSecond: previous,
      currentSecond: second,
    );
    if (events.isNotEmpty && _activeRegionEvent == null) {
      unawaited(_startRegionEvent(events.last));
    }
  }

  Future<void> _startRegionEvent(SurvivalRegionEventPlan plan) async {
    if (isRemoving ||
        _activeRegionEvent != null ||
        _activeNexusBoss != null ||
        _phaseElevenTransitioning) {
      return;
    }
    _activeRegionEvent = plan;
    _regionEventRemaining = plan.durationSeconds;
    _regionEventProgress = 0;
    _regionEventKills = 0;
    _riskCacheCarrying = false;
    final marker = SurvivalRegionObjectiveComponent(
      position: plan.region.objectivePosition,
      region: plan.region,
      kind: plan.kind,
    );
    _regionObjective = marker;
    game.survivalRun.recordRegionEventStarted(plan.kind);
    await add(marker);
    _showAlert(
      game.localization.text(
        plan.kind.alertLocalizationKey,
        parameters: <String, Object>{
          'region': game.localization.text(plan.region.localizationKey),
          'seconds': plan.durationSeconds.round(),
        },
      ),
      switch (plan.kind) {
        SurvivalRegionEventKind.relayRepair => const Color(0xFF45F3A6),
        SurvivalRegionEventKind.escort => const Color(0xFF36E1FF),
        SurvivalRegionEventKind.riftSeal => const Color(0xFFFF4FD8),
        SurvivalRegionEventKind.riskCache => const Color(0xFFFFC857),
      },
    );
    if (plan.kind == SurvivalRegionEventKind.riftSeal) {
      await _spawnAnomaly(
        SurvivalAnomalyKind.riftStalker,
        position: marker.position + Vector2(-84, -28),
      );
      await _spawnAnomaly(
        SurvivalAnomalyKind.arcWarden,
        position: marker.position + Vector2(84, -28),
      );
      await _spawnCrawler(marker.position + Vector2(-64, 64));
      await _spawnCrawler(marker.position + Vector2(64, 64));
    }
    game.publishUiSnapshot(force: true);
  }

  void _updateRegionEvent(double dt) {
    final plan = _activeRegionEvent;
    final marker = _regionObjective;
    if (plan == null || marker == null || dt <= 0) return;
    if (_activeNexusBoss != null) return;
    _regionEventRemaining = math.max(0, _regionEventRemaining - dt);
    if (_regionEventRemaining <= 0) {
      unawaited(_failRegionEvent());
      return;
    }
    final player = game.world.player;
    switch (plan.kind) {
      case SurvivalRegionEventKind.relayRepair:
        if (player.position.distanceTo(marker.position) <= 68) {
          _regionEventProgress += dt / 5;
        } else {
          _regionEventProgress -= dt / 16;
        }
      case SurvivalRegionEventKind.escort:
        final target = plan.region.escortTarget;
        final pathLength = plan.region.objectivePosition.distanceTo(target);
        if (player.position.distanceTo(marker.position) <= 132) {
          final delta = target - marker.position;
          if (delta.length2 > 4) {
            marker.position += delta.normalized() * (72 * dt);
          }
        }
        _regionEventProgress =
            1 - marker.position.distanceTo(target) / pathLength;
      case SurvivalRegionEventKind.riftSeal:
        _regionEventProgress = _regionEventKills / 4;
      case SurvivalRegionEventKind.riskCache:
        if (!_riskCacheCarrying &&
            player.position.distanceTo(marker.position) <= 64) {
          _riskCacheCarrying = true;
          marker
            ..carrying = true
            ..position.setFrom(SurvivalNexusLayout.center);
          _regionEventProgress = .5;
          unawaited(
            _spawnAnomaly(
              SurvivalAnomalyKind.mineLayer,
              position: plan.region.objectivePosition + Vector2(-72, 32),
              elite: true,
            ),
          );
          unawaited(
            _spawnAnomaly(
              SurvivalAnomalyKind.riftStalker,
              position: plan.region.objectivePosition + Vector2(72, -32),
              elite: true,
            ),
          );
          _showAlert(
            game.localization.text('survivalAlert.event.cacheExtract'),
            const Color(0xFFFF6464),
          );
        } else if (_riskCacheCarrying) {
          final distance = player.position.distanceTo(marker.position);
          _regionEventProgress =
              .5 + .5 * (1 - (distance / 900).clamp(0, 1).toDouble());
          if (distance <= 72) _regionEventProgress = 1;
        }
    }
    _regionEventProgress = _regionEventProgress.clamp(0, 1).toDouble();
    marker.setProgress(_regionEventProgress);
    if (_regionEventProgress >= 1) unawaited(_completeRegionEvent());
  }

  void registerRegionEventKill() {
    if (_activeRegionEvent?.kind != SurvivalRegionEventKind.riftSeal) return;
    _regionEventKills = math.min(4, _regionEventKills + 1);
    _regionEventProgress = _regionEventKills / 4;
    _regionObjective?.setProgress(_regionEventProgress);
    if (_regionEventProgress >= 1) unawaited(_completeRegionEvent());
  }

  Future<void> _completeRegionEvent() async {
    final plan = _activeRegionEvent;
    final marker = _regionObjective;
    if (plan == null) return;
    _activeRegionEvent = null;
    _regionObjective = null;
    _regionEventProgress = 1;
    final reward = game.survivalRun.recordRegionEventCompleted(plan.kind);
    final rewardPosition =
        marker?.position.clone() ?? plan.region.objectivePosition;
    marker?.removeFromParent();
    game.world.spawnDataShards(
      rewardPosition,
      count: 5,
      alternatingCorruption: false,
    );
    game.world.player.restoreIntegrity(1);
    _showAlert(
      game.localization.text(
        'survivalAlert.eventComplete',
        parameters: <String, Object>{'reward': reward},
      ),
      const Color(0xFF45F3A6),
    );
    game.triggerImpactFeedback(intensity: 1.25);
    game.publishUiSnapshot(force: true);
    game.queueSurvivalItemReward(SurvivalItemRewardSource.regionEvent);
  }

  Future<void> _failRegionEvent() async {
    final plan = _activeRegionEvent;
    final marker = _regionObjective;
    if (plan == null) return;
    _activeRegionEvent = null;
    _regionObjective = null;
    game.survivalRun.recordRegionEventFailed(plan.kind);
    final failurePosition =
        marker?.position.clone() ?? plan.region.objectivePosition;
    marker?.removeFromParent();
    _showAlert(
      game.localization.text('survivalAlert.eventFailed'),
      const Color(0xFFFF6464),
    );
    await _spawnAnomaly(
      SurvivalAnomalyKind.riftStalker,
      position: failurePosition,
      elite: true,
    );
    game.publishUiSnapshot(force: true);
  }

  Future<void> _startNexusBoss(SurvivalBossMilestone milestone) async {
    if (isRemoving || _activeNexusBoss != null || _phaseElevenTransitioning) {
      return;
    }
    _phaseElevenTransitioning = true;
    if (_activeRegionEvent != null) await _failRegionEvent();
    for (final enemy
        in children
            .where(
              (child) =>
                  child is CrawlerComponent ||
                  child is SentinelComponent ||
                  child is PhaseHoundComponent ||
                  child is SurvivalAnomalyComponent ||
                  child is CompositeComponent ||
                  child is OptimizerFragmentComponent,
            )
            .toList(growable: false)) {
      enemy.removeFromParent();
    }
    final playerPosition = game.world.player.position;
    final center = Vector2(
      playerPosition.x.clamp(360, arenaWidth - 360).toDouble(),
      playerPosition.y.clamp(260, arenaHeight - 260).toDouble(),
    );
    _bossArenaWalls.addAll(<PhaseWallComponent>[
      PhaseWallComponent(
        position: center + Vector2(-310, -220),
        size: Vector2(620, 14),
      ),
      PhaseWallComponent(
        position: center + Vector2(-310, 206),
        size: Vector2(620, 14),
      ),
      PhaseWallComponent(
        position: center + Vector2(-310, -206),
        size: Vector2(14, 412),
      ),
      PhaseWallComponent(
        position: center + Vector2(296, -206),
        size: Vector2(14, 412),
      ),
    ]);
    await addAll(_bossArenaWalls);
    late final SurvivalNexusBossComponent boss;
    boss = SurvivalNexusBossComponent(
      entityId: 'survival-boss-${milestone.kind.id}-${_spawnId++}',
      kind: milestone.kind,
      position: center + Vector2(0, -120),
      arenaCenter: center,
      onPhaseChanged: (phase) => _onNexusBossPhaseChanged(boss, phase),
      onDefeated: () => unawaited(_completeNexusBoss(boss)),
    );
    _activeNexusBoss = boss;
    await add(boss);
    await add(
      SurvivalBossCutInComponent(
        title: game.localization.text(
          'survivalBoss.cutIn',
          parameters: <String, Object>{
            'boss': game.localization.text(milestone.kind.localizationKey),
          },
        ),
        accent: boss.accent,
      ),
    );
    game.survivalRun.recordSurvivalBossIntro();
    game.triggerImpactFeedback(intensity: 1.7);
    _phaseElevenTransitioning = false;
    game.publishUiSnapshot(force: true);
  }

  void _onNexusBossPhaseChanged(SurvivalNexusBossComponent boss, int phase) {
    game.survivalRun.recordSurvivalBossPhaseChanged();
    _showAlert(
      game.localization.text(
        'survivalAlert.bossPhase',
        parameters: <String, Object>{
          'boss': game.localization.text(boss.kind.localizationKey),
          'phase': phase,
        },
      ),
      boss.accent,
    );
    game.triggerImpactFeedback(intensity: 1.5);
    game.publishUiSnapshot(force: true);
  }

  Future<void> _completeNexusBoss(SurvivalNexusBossComponent boss) async {
    if (_activeNexusBoss != boss) return;
    _activeNexusBoss = null;
    final isFinal = boss.kind == SurvivalNexusBossKind.nexusCore;
    game.survivalRun.recordSurvivalBossDefeated(finalBoss: isFinal);
    game.recordSurvivalKillAt(
      boss.position,
      miniBoss: true,
      rewardMultiplier: isFinal ? 4 : 2,
    );
    game.world.spawnDataShards(
      boss.position,
      count: isFinal ? 18 : 10,
      alternatingCorruption: false,
    );
    for (final wall in _bossArenaWalls) {
      wall.removeFromParent();
    }
    _bossArenaWalls.clear();
    _showAlert(
      game.localization.text(
        isFinal
            ? 'survivalAlert.nexusBossDefeated'
            : 'survivalAlert.regionBossDefeated',
        parameters: <String, Object>{
          'boss': game.localization.text(boss.kind.localizationKey),
        },
      ),
      const Color(0xFF45F3A6),
    );
    game.triggerImpactFeedback(intensity: 1.8);
    game.publishUiSnapshot(force: true);
    game.queueSurvivalItemReward(
      isFinal
          ? SurvivalItemRewardSource.nexusBoss
          : SurvivalItemRewardSource.regionBoss,
    );
  }

  static int _nextCacheAfter(int second) {
    if (second < 30) return 30;
    return 30 + (((second - 30) ~/ 45) + 1) * 45;
  }

  void _updateVolatileCache() {
    final second = game.survivalRun.elapsedSeconds.floor();
    if (second < _nextCacheSecond) return;
    while (_nextCacheSecond <= second) {
      _nextCacheSecond += 45;
    }
    unawaited(_spawnVolatileCache());
  }

  Future<void> _spawnVolatileCache() async {
    if (isRemoving || children.whereType<VolatileCacheComponent>().isNotEmpty) {
      return;
    }
    final cachePosition = _nextCachePosition();
    game.survivalRun.recordHotCacheSpawned();
    _showAlert(
      game.localization.text(
        'survivalAlert.volatileCache',
        parameters: const <String, Object>{'seconds': 12},
      ),
      const Color(0xFFFFC857),
    );
    await add(
      VolatileCacheComponent(
        position: cachePosition,
        onCollected: _collectVolatileCache,
        onExpired: _expireVolatileCache,
      ),
    );
    game.publishUiSnapshot(force: true);
  }

  Vector2 _nextCachePosition() {
    if (PatchWorldGame.survivalQaCacheAtPlayer) {
      return game.world.player.position + Vector2(20, 0);
    }
    final candidates = <Vector2>[
      ...SurvivalNexusRegion.values.map((region) => region.objectivePosition),
      Vector2(SurvivalNexusLayout.centerX, 250),
      Vector2(SurvivalNexusLayout.centerX, arenaHeight - 250),
    ];
    final playerPosition = game.world.player.position;
    var selected = candidates[_cachePositionIndex % candidates.length];
    var bestDistance = selected.distanceToSquared(playerPosition);
    for (var offset = 1; offset < candidates.length; offset += 1) {
      final candidate =
          candidates[(_cachePositionIndex + offset) % candidates.length];
      final distance = candidate.distanceToSquared(playerPosition);
      if (distance > bestDistance) {
        selected = candidate;
        bestDistance = distance;
      }
    }
    _cachePositionIndex += 1;
    return selected.clone();
  }

  void _collectVolatileCache(Vector2 position) {
    if (isRemoving || game.mode != PatchWorldMode.survival) return;
    final reward = game.survivalRun.recordHotCacheCollected();
    game.world.spawnDataShards(
      position,
      count: 3,
      alternatingCorruption: false,
    );
    _showAlert(
      game.localization.text(
        'survivalAlert.cacheClaimed',
        parameters: <String, Object>{'reward': reward, 'data': 3},
      ),
      const Color(0xFF45F3A6),
    );
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  void _expireVolatileCache(Vector2 position) {
    if (isRemoving || game.mode != PatchWorldMode.survival) return;
    game.survivalRun.recordHotCacheExpired();
    _showAlert(
      game.localization.text('survivalAlert.cacheLost'),
      const Color(0xFFFF6464),
    );
    unawaited(_spawnCacheAmbush(position));
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnCacheAmbush(Vector2 position) async {
    final offsets = <Vector2>[Vector2(-46, 16), Vector2(46, -16)];
    for (final offset in offsets) {
      final spawn = position + offset;
      spawn.x = spawn.x.clamp(44, arenaWidth - 44).toDouble();
      spawn.y = spawn.y.clamp(44, arenaHeight - 44).toDouble();
      await _spawnCrawler(spawn);
    }
    final sentinelPosition = position + Vector2(0, 58);
    sentinelPosition.x = sentinelPosition.x
        .clamp(44, arenaWidth - 44)
        .toDouble();
    sentinelPosition.y = sentinelPosition.y
        .clamp(44, arenaHeight - 44)
        .toDouble();
    late final SentinelComponent sentinel;
    sentinel = SentinelComponent(
      entityId: 'survival-cache-sentinel-${_spawnId++}',
      position: sentinelPosition,
      onDefeated: () => game.recordSurvivalKillAt(sentinel.position),
    );
    await add(sentinel);
  }

  void _updateSurvivalMilestone() {
    final minute = game.survivalRun.elapsedSeconds.floor() ~/ 60;
    if (minute <= _lastCelebratedMinute) return;
    _lastCelebratedMinute = minute;
    if (minute >= 20) {
      game.recordSurvivalMilestone(SurvivalMeaningfulEvent.endlessTier);
    }
    final label = game.localization.text(
      minute >= 20 ? 'survivalAlert.endless' : 'survivalAlert.survived',
      parameters: <String, Object>{
        'tier': minute - 19,
        'seconds': minute * 60,
        'risk': game.survivalRun.riskMultiplier.toStringAsFixed(2),
      },
    );
    _showAlert(label, const Color(0xFF45F3A6));
  }

  void showComboMilestone(
    int combo, {
    required int flowMultiplier,
    required int dataReward,
  }) {
    if (combo != 5 && combo != 10 && combo % 20 != 0) return;
    _showAlert(
      game.localization.text(
        'survivalAlert.combo',
        parameters: <String, Object>{
          'combo': combo,
          'flow': flowMultiplier,
          'data': dataReward,
        },
      ),
      combo >= 20 ? const Color(0xFFFFC857) : const Color(0xFF36E1FF),
    );
  }

  void showPatchPowerDemo(String patchTitle) {
    _showAlert(
      game.localization.text(
        'survivalAlert.powerOnline',
        parameters: <String, Object>{'patch': patchTitle},
      ),
      const Color(0xFF45F3A6),
    );
  }

  void showCriticalFlow() {
    _showAlert(
      game.localization.text('survivalAlert.criticalFlow'),
      const Color(0xFFFFC857),
    );
  }

  void showFusionOnline(String fusionTitle) {
    _showAlert(
      game.localization.text(
        'survivalAlert.fusionOnline',
        parameters: <String, Object>{'fusion': fusionTitle},
      ),
      const Color(0xFFFFC857),
    );
  }

  void showWeaponBuildOnline(String buildTitle, {required int tier}) {
    _showAlert(
      game.localization.text(
        'survivalAlert.weaponBuildOnline',
        parameters: <String, Object>{'build': buildTitle, 'tier': tier},
      ),
      const Color(0xFFFFC857),
    );
  }

  void _updatePhaseLeak(double dt) {
    if (!game.survivalModifiers.phaseWallsLeak || dt <= 0) return;
    if (_phaseLeak.update(dt)) game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnWave() async {
    if (_activeNexusBoss != null || _phaseElevenTransitioning) return;
    final state = game.survivalRun;
    final second = state.elapsedSeconds.floor();
    final milestones = _director.milestonesBetween(
      previousSecond: _lastWaveSecond,
      currentSecond: second,
    );
    _lastWaveSecond = second;
    final plan = _director.planForSecond(
      second: second,
      integrityRatio:
          game.world.player.integrity / game.world.player.maxIntegrity,
      recentKillsPerSecond: state.recentKillsPerSecond(),
    );
    final profile = SurvivalBalanceCurve.profileForSecond(second);
    if (milestones.activateTemporalStorm) {
      game.recordSurvivalMilestone(SurvivalMeaningfulEvent.temporalStorm);
      _showAlert(
        game.localization.text(
          'survivalAlert.temporalStorm',
          parameters: const <String, Object>{'seconds': 300},
        ),
        const Color(0xFF36E1FF),
      );
    }
    if (milestones.spawnOptimizerFragment) {
      game.recordSurvivalMilestone(SurvivalMeaningfulEvent.optimizerFragment);
      await _spawnOptimizerFragment();
      return;
    }
    if (milestones.spawnComposite) {
      game.recordSurvivalMilestone(SurvivalMeaningfulEvent.composite);
      await _spawnComposite();
      return;
    }
    if (milestones.spawnElite) {
      game.recordSurvivalMilestone(SurvivalMeaningfulEvent.elite);
      await _spawnEliteSentinel();
    }

    final activeEnemies = children
        .where(
          (child) =>
              child is CrawlerComponent ||
              child is SentinelComponent ||
              child is PhaseHoundComponent ||
              child is SurvivalAnomalyComponent ||
              child is CompositeComponent ||
              child is OptimizerFragmentComponent,
        )
        .length;
    if (activeEnemies >= profile.activeEnemyCap) return;
    final activePhaseHounds = children
        .whereType<PhaseHoundComponent>()
        .where((hound) => !hound.isRemoving)
        .length;
    final activeAnomalies = children
        .whereType<SurvivalAnomalyComponent>()
        .where((enemy) => !enemy.isRemoving)
        .length;
    final allocation = SurvivalSpawnAllocation.forWave(
      profile: profile,
      activeEnemies: activeEnemies,
      requestedCrawlers: plan.crawlers,
      requestedSentinels: plan.sentinels,
      requestedPhaseHounds: plan.phaseHounds,
      activePhaseHounds: activePhaseHounds,
      activeAnomalies: activeAnomalies,
      anomalyEligible: second >= 45,
    );
    for (var index = 0; index < allocation.crawlers; index += 1) {
      await _spawnCrawler(_nextSpawn());
    }
    for (var index = 0; index < allocation.sentinels; index += 1) {
      late final SentinelComponent sentinel;
      sentinel = SentinelComponent(
        entityId: 'survival-sentinel-${_spawnId++}',
        position: _nextSpawn(),
        onDefeated: () => game.recordSurvivalKillAt(sentinel.position),
      );
      await add(sentinel);
    }
    for (var index = 0; index < allocation.phaseHounds; index += 1) {
      await _spawnPhaseHound();
    }
    if (allocation.spawnAnomaly) {
      final kind = switch ((second ~/ 45) % 3) {
        0 => SurvivalAnomalyKind.riftStalker,
        1 => SurvivalAnomalyKind.arcWarden,
        _ => SurvivalAnomalyKind.mineLayer,
      };
      await _spawnAnomaly(kind);
    }
  }

  Future<void> _spawnPhaseHound() async {
    if (!_phaseHoundTutorialShown) {
      _phaseHoundTutorialShown = true;
      _showAlert(
        game.localization.text('survivalAlert.phaseHound'),
        const Color(0xFF36E1FF),
      );
    }
    late final PhaseHoundComponent hound;
    hound = PhaseHoundComponent(
      entityId: 'survival-phase-hound-${_spawnId++}',
      position: _nextSpawn(inset: phaseHoundSpawnInset),
      onDefeated: () => game.recordSurvivalKillAt(hound.position),
      onPerfectDodge: () =>
          game.recordSurvivalPerfectDodge(game.world.player.position.clone()),
      onBreakDefeated: (perfectDodgeLinked) => game.recordSurvivalHoundBreak(
        hound.position,
        phaseExecution: perfectDodgeLinked,
      ),
    );
    await add(hound);
  }

  Future<void> _spawnEliteSentinel() async {
    _showAlert(
      game.localization.text(
        'survivalAlert.eliteError',
        parameters: <String, Object>{
          'seconds': game.survivalRun.elapsedSeconds.floor(),
        },
      ),
      const Color(0xFFFFC857),
    );
    late final SentinelComponent sentinel;
    sentinel = SentinelComponent(
      entityId: 'survival-elite-sentinel-${_spawnId++}',
      position: _nextSpawn(),
      isElite: true,
      healthMaximum: 5,
      fireInterval: 1.0,
      telegraphSeconds: 0.42,
      projectileSpeed: 165,
      onDefeated: () =>
          game.recordSurvivalKillAt(sentinel.position, elite: true),
    );
    await add(sentinel);
  }

  Future<void> _spawnComposite() async {
    _showAlert(
      game.localization.text(
        'survivalAlert.compositeBreach',
        parameters: <String, Object>{
          'seconds': game.survivalRun.elapsedSeconds.floor(),
        },
      ),
      const Color(0xFFFF4FD8),
    );
    late final CompositeComponent composite;
    composite = CompositeComponent(
      entityId: 'survival-composite-${_spawnId++}',
      position: _nextSpawn(),
      combinedHealth: 8,
      onDefeated: () =>
          game.recordSurvivalKillAt(composite.position, miniBoss: true),
    );
    await add(composite);
  }

  Future<void> _spawnOptimizerFragment() async {
    _showAlert(
      game.localization.text(
        'survivalAlert.optimizerFragment',
        parameters: const <String, Object>{'seconds': 450},
      ),
      const Color(0xFFFFC857),
    );
    late final OptimizerFragmentComponent fragment;
    fragment = OptimizerFragmentComponent(
      entityId: 'survival-optimizer-fragment-${_spawnId++}',
      position: _nextSpawn(),
      onDefeated: () =>
          game.recordSurvivalKillAt(fragment.position, miniBoss: true),
    );
    await add(fragment);
  }

  void _showAlert(String text, Color color) {
    _alertQueue.add((text: text, color: color));
    _displayNextAlert();
  }

  void _displayNextAlert() {
    if (_alertActive || _alertQueue.isEmpty || isRemoving) return;
    _alertActive = true;
    final alert = _alertQueue.removeAt(0);
    final label = TextComponent(
      text: alert.text,
      position: game.camera.viewfinder.position + Vector2(0, -166),
      anchor: Anchor.center,
      priority: 80,
      textRenderer: TextPaint(
        style: TextStyle(
          fontFamily: 'PatchWorldCJK',
          color: alert.color,
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.6,
        ),
      ),
    );
    add(label);
    add(
      TimerComponent(
        period: 1.4,
        removeOnFinish: true,
        onTick: () {
          if (label.isMounted) label.removeFromParent();
          _alertActive = false;
          _displayNextAlert();
        },
      ),
    );
  }

  Future<void> _spawnCrawler(Vector2 position) async {
    late final CrawlerComponent crawler;
    crawler = CrawlerComponent(
      entityId: 'survival-crawler-${_spawnId++}',
      position: position,
      initialHealth: 2,
      healthMaximum: 2,
      onDefeated: () => game.recordSurvivalKillAt(crawler.position),
    );
    await add(crawler);
  }

  Future<void> _spawnAnomaly(
    SurvivalAnomalyKind kind, {
    Vector2? position,
    bool elite = false,
  }) async {
    late final SurvivalAnomalyComponent anomaly;
    anomaly = SurvivalAnomalyComponent(
      entityId: 'survival-${kind.name}-${_spawnId++}',
      kind: kind,
      position: position ?? _nextSpawn(inset: 64),
      elite: elite,
      onDefeated: () => game.recordSurvivalKillAt(
        anomaly.position,
        elite: elite,
        rewardMultiplier: elite ? 2 : 1,
      ),
    );
    await add(anomaly);
  }

  Vector2 _nextSpawn({double inset = 36}) {
    final player = game.world.player;
    final point = _director.chooseEngagementSpawnPoint(
      width: arenaWidth,
      height: arenaHeight,
      playerX: player.position.x,
      playerY: player.position.y,
      inset: math.max(72, inset),
    );
    return clampSpawnPoint(
      point: point,
      width: arenaWidth,
      height: arenaHeight,
      inset: inset,
    );
  }
}
