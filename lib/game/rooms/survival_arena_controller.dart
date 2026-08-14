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
import 'package:patch_world/game/components/effects/temporal_storm_component.dart';
import 'package:patch_world/game/components/effects/volatile_cache_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';
import 'package:patch_world/game/survival/wave_director.dart';
import 'package:patch_world/game/survival/survival_playtest_telemetry.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

final class SurvivalArenaController extends Component
    with HasGameReference<PatchWorldGame> {
  static const double phaseHoundSpawnInset = 60;

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
  final Vector2 playerSpawn = Vector2(480, 270);
  final List<PhaseWallComponent> _phaseWalls = <PhaseWallComponent>[];
  final List<({String text, Color color})> _alertQueue =
      <({String text, Color color})>[];
  double _spawnRemaining = 4;
  bool _spawning = false;
  int _spawnId = 0;
  int _lastWaveSecond = 0;
  int _lastCelebratedMinute = 0;
  int _nextCacheSecond = 30;
  int _cachePositionIndex = 0;
  bool _alertActive = false;
  bool _phaseHoundTutorialShown = false;

  int? get milestoneBossHealth {
    for (final fragment in children.whereType<OptimizerFragmentComponent>()) {
      if (!fragment.isRemoving) return fragment.health.current;
    }
    for (final composite in children.whereType<CompositeComponent>()) {
      if (!composite.isRemoving) return composite.health.current;
    }
    return null;
  }

  int? get milestoneBossMaxHealth {
    for (final fragment in children.whereType<OptimizerFragmentComponent>()) {
      if (!fragment.isRemoving) return fragment.health.max;
    }
    for (final composite in children.whereType<CompositeComponent>()) {
      if (!composite.isRemoving) return composite.health.max;
    }
    return null;
  }

  String? get milestoneBossLabel {
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

  double get enemySpeedMultiplier {
    final second = game.survivalRun.elapsedSeconds;
    if (second < 300) return 1;
    final wave = 0.5 + 0.5 * math.sin((second - 300) * math.pi / 4);
    final endlessTier = second < 600 ? 0 : 1 + (second - 600) ~/ 60;
    return (0.85 + wave * 0.50 + endlessTier * 0.03).clamp(0.85, 1.55);
  }

  bool get isPhaseWindowOpen =>
      game.survivalModifiers.phaseWallsLeak &&
      _phaseLeak.phase == PhaseLeakPhase.open;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _lastWaveSecond = game.survivalRun.elapsedSeconds.floor();
    _lastCelebratedMinute = _lastWaveSecond ~/ 60;
    _nextCacheSecond = _nextCacheAfter(_lastWaveSecond);
    await add(RoomBackdropComponent(RoomBackdropStyle.survival));
    await add(TemporalStormComponent());
    await addAll(<WallComponent>[
      WallComponent(position: Vector2.zero(), size: Vector2(960, 24)),
      WallComponent(position: Vector2(0, 516), size: Vector2(960, 24)),
      WallComponent(position: Vector2.zero(), size: Vector2(24, 540)),
      WallComponent(position: Vector2(936, 0), size: Vector2(24, 540)),
    ]);
    _phaseWalls.addAll(<PhaseWallComponent>[
      PhaseWallComponent(position: Vector2(390, 132), size: Vector2(180, 14)),
      PhaseWallComponent(position: Vector2(390, 394), size: Vector2(180, 14)),
    ]);
    await addAll(_phaseWalls);
    await _spawnCrawler(Vector2(300, 190));
    await _spawnCrawler(Vector2(660, 350));
  }

  @override
  void update(double dt) {
    final simulationDt =
        game.clock.simulationDt * PatchWorldGame.survivalQaTimeScale;
    game.survivalRun.update(simulationDt);
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
    if (second < 60) return 4;
    if (second < 180) return 3.6;
    if (second < 300) return 3.2;
    if (second < 600) return 3.0;
    final endlessTier = 1 + (second - 600) ~/ 60;
    return math.max(1.8, 3.0 - endlessTier * 0.12);
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
      Vector2(150, 135),
      Vector2(810, 135),
      Vector2(150, 405),
      Vector2(810, 405),
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
      spawn.x = spawn.x.clamp(36, 924).toDouble();
      spawn.y = spawn.y.clamp(36, 504).toDouble();
      await _spawnCrawler(spawn);
    }
    final sentinelPosition = position + Vector2(0, 58);
    sentinelPosition.x = sentinelPosition.x.clamp(36, 924).toDouble();
    sentinelPosition.y = sentinelPosition.y.clamp(36, 504).toDouble();
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
    if (minute >= 10) {
      game.recordSurvivalMilestone(SurvivalMeaningfulEvent.endlessTier);
    }
    final label = game.localization.text(
      minute >= 10 ? 'survivalAlert.endless' : 'survivalAlert.survived',
      parameters: <String, Object>{
        'tier': minute - 9,
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

  void _updatePhaseLeak(double dt) {
    if (!game.survivalModifiers.phaseWallsLeak || dt <= 0) return;
    if (_phaseLeak.update(dt)) unawaited(_syncPhaseWalls());
  }

  Future<void> _syncPhaseWalls() async {
    final solid = _phaseLeak.phase != PhaseLeakPhase.open;
    for (final wall in _phaseWalls) {
      await wall.setSolid(solid);
      if (_phaseLeak.phase == PhaseLeakPhase.warning) {
        wall.paint.color = const Color(0xCCFFC857);
      }
    }
  }

  Future<void> _spawnWave() async {
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
              child is CompositeComponent ||
              child is OptimizerFragmentComponent,
        )
        .length;
    final activeCap = math.min(48, 28 + plan.endlessTier * 4);
    if (activeEnemies >= activeCap) return;
    final crawlerCap = math.min(9, 5 + plan.endlessTier);
    final sentinelCap = math.min(4, 2 + plan.endlessTier ~/ 2);
    for (
      var index = 0;
      index < plan.crawlers.clamp(1, crawlerCap);
      index += 1
    ) {
      await _spawnCrawler(_nextSpawn());
    }
    for (
      var index = 0;
      index < plan.sentinels.clamp(0, sentinelCap);
      index += 1
    ) {
      late final SentinelComponent sentinel;
      sentinel = SentinelComponent(
        entityId: 'survival-sentinel-${_spawnId++}',
        position: _nextSpawn(),
        onDefeated: () => game.recordSurvivalKillAt(sentinel.position),
      );
      await add(sentinel);
    }
    final phaseHoundCap = plan.endlessTier >= 3
        ? 3
        : state.elapsedSeconds < 300
        ? 1
        : 2;
    final activePhaseHounds = children
        .whereType<PhaseHoundComponent>()
        .where((hound) => !hound.isRemoving)
        .length;
    final availablePhaseHoundSlots = math.max(
      0,
      phaseHoundCap - activePhaseHounds,
    );
    for (
      var index = 0;
      index < plan.phaseHounds.clamp(0, availablePhaseHoundSlots);
      index += 1
    ) {
      await _spawnPhaseHound();
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
      position: Vector2(480, 104),
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

  Vector2 _nextSpawn({double inset = 36}) {
    final player = game.world.player;
    final point = _director.chooseSpawnPoint(
      width: 960,
      height: 540,
      playerX: player.position.x,
      playerY: player.position.y,
      velocityX: 0,
      velocityY: 0,
    );
    return clampSpawnPoint(point: point, width: 960, height: 540, inset: inset);
  }
}
