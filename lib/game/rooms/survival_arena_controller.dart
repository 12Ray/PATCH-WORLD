import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/phase_wall_component.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';
import 'package:patch_world/game/survival/wave_director.dart';

final class SurvivalArenaController extends Component
    with HasGameReference<PatchWorldGame> {
  final SurvivalWaveDirector _director = SurvivalWaveDirector();
  final PhaseLeakController _phaseLeak = PhaseLeakController();
  final Vector2 playerSpawn = Vector2(480, 270);
  final List<PhaseWallComponent> _phaseWalls = <PhaseWallComponent>[];
  double _spawnRemaining = 4;
  bool _spawning = false;
  int _spawnId = 0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.survival));
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
    final simulationDt = game.clock.simulationDt;
    game.survivalRun.update(simulationDt);
    _updatePhaseLeak(simulationDt);
    if (game.world.isReady && !_spawning && simulationDt > 0) {
      _spawnRemaining -= simulationDt;
      if (_spawnRemaining <= 0) {
        _spawnRemaining = 4;
        _spawning = true;
        unawaited(_spawnWave().whenComplete(() => _spawning = false));
      }
    }
    super.update(dt);
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
    final plan = _director.planForSecond(
      second: state.elapsedSeconds.floor(),
      integrityRatio:
          game.world.player.integrity / game.world.player.maxIntegrity,
      recentKillsPerSecond: state.kills / (state.elapsedSeconds + 1),
    );
    final activeEnemies = children
        .where(
          (child) => child is CrawlerComponent || child is SentinelComponent,
        )
        .length;
    if (activeEnemies >= 28) return;
    for (var index = 0; index < plan.crawlers.clamp(1, 5); index += 1) {
      await _spawnCrawler(_nextSpawn());
    }
    for (var index = 0; index < plan.sentinels.clamp(0, 2); index += 1) {
      await add(
        SentinelComponent(
          entityId: 'survival-sentinel-${_spawnId++}',
          position: _nextSpawn(),
          onDefeated: () => game.recordSurvivalKill(elite: plan.spawnElite),
        ),
      );
    }
  }

  Future<void> _spawnCrawler(Vector2 position) async {
    await add(
      CrawlerComponent(
        entityId: 'survival-crawler-${_spawnId++}',
        position: position,
        initialHealth: 2,
        healthMaximum: 2,
        onDefeated: game.recordSurvivalKill,
      ),
    );
  }

  Vector2 _nextSpawn() {
    final player = game.world.player;
    final point = _director.chooseSpawnPoint(
      width: 960,
      height: 540,
      playerX: player.position.x,
      playerY: player.position.y,
      velocityX: 0,
      velocityY: 0,
    );
    return Vector2(
      point.x.clamp(36, 924).toDouble(),
      point.y.clamp(36, 504).toDouble(),
    );
  }
}
