import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class RoomThreeController extends Component
    with HasGameReference<PatchWorldGame>
    implements PlatformerRoomGeometry {
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  int _defeatedCount = 0;
  bool _completed = false;
  Vector2 _respawnPoint = Vector2(70, 988);
  late final BossSealGateComponent _bossGate;

  @override
  final Vector2 playerSpawn = Vector2(70, 988);

  @override
  final Vector2 worldSize = Vector2(2880, 1080);

  @override
  double get killPlaneY => 1160;

  int get defeatedCount => _defeatedCount;

  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) => _respawnPoint.clone();

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(RoomBackdropStyle.collision, worldSize: worldSize),
    );
    _bossGate = BossSealGateComponent(
      position: Vector2(2480, 560),
      size: Vector2(28, 464),
      style: PlatformSurfaceStyle.collision,
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 1080, boundary: true),
      _surface(2856, 0, 24, 1080, boundary: true),
      _surface(0, 1024, 370, 56),
      _surface(460, 1024, 420, 56),
      _surface(970, 1024, 420, 56),
      _surface(1480, 1024, 400, 56),
      _surface(1970, 1024, 910, 56),
      _surface(100, 930, 190, 22),
      _surface(280, 840, 180, 22),
      _surface(470, 750, 180, 22),
      _surface(650, 660, 190, 22),
      _surface(830, 570, 180, 22),
      _surface(1010, 480, 190, 22),
      _surface(1190, 390, 190, 22),
      _surface(1370, 480, 190, 22),
      _surface(1540, 570, 190, 22),
      _surface(1720, 660, 190, 22),
      _surface(1900, 750, 190, 22),
      _surface(2080, 660, 180, 22),
      _surface(2250, 570, 180, 22),
      _surface(2380, 750, 130, 22),
      _surface(2520, 944, 336, 80),
      MovingPlatformComponent(
        start: Vector2(530, 900),
        end: Vector2(530, 650),
        size: Vector2(120, 22),
        periodSeconds: 3.5,
        style: PlatformSurfaceStyle.collision,
      ),
      MovingPlatformComponent(
        start: Vector2(920, 780),
        end: Vector2(1090, 690),
        size: Vector2(120, 22),
        periodSeconds: 3.0,
        style: PlatformSurfaceStyle.collision,
      ),
      MovingPlatformComponent(
        start: Vector2(1780, 480),
        end: Vector2(1780, 720),
        size: Vector2(120, 22),
        periodSeconds: 3.8,
        style: PlatformSurfaceStyle.collision,
      ),
      BreakablePlatformComponent(
        position: Vector2(1260, 760),
        size: Vector2(150, 22),
        style: PlatformSurfaceStyle.collision,
        breakDelay: .55,
      ),
      BreakablePlatformComponent(
        position: Vector2(2160, 840),
        size: Vector2(140, 22),
        style: PlatformSurfaceStyle.collision,
        breakDelay: .65,
      ),
      _bossGate,
    ]);
    await addAll(_surfaces);
    await addAll(<Component>[
      for (final pit in <(double, double)>[
        (370, 90),
        (880, 90),
        (1390, 90),
        (1880, 90),
      ])
        DamagePitComponent(
          position: Vector2(pit.$1, 1024),
          size: Vector2(pit.$2, 56),
          style: PlatformSurfaceStyle.collision,
        ),
      RoomHazardComponent(
        position: Vector2(700, 648),
        size: Vector2(100, 12),
        style: RoomHazardStyle.spikes,
        surfaceStyle: PlatformSurfaceStyle.collision,
        sourceId: 'hazard.collision-archive.compression-teeth',
      ),
      RoomHazardComponent(
        position: Vector2(1735, 648),
        size: Vector2(100, 12),
        style: RoomHazardStyle.spikes,
        surfaceStyle: PlatformSurfaceStyle.collision,
        sourceId: 'hazard.collision-archive.polarity-teeth',
      ),
      PulsingLaserComponent(
        position: Vector2(1120, 502),
        size: Vector2(14, 342),
        sourceId: 'hazard.collision-archive.vector-slice',
        style: PlatformSurfaceStyle.collision,
      ),
      PulsingLaserComponent(
        position: Vector2(2050, 680),
        size: Vector2(14, 344),
        sourceId: 'hazard.collision-archive.merge-beam',
        style: PlatformSurfaceStyle.collision,
        phaseOffset: 1.2,
      ),
      CrusherHazardComponent(
        start: Vector2(1460, 440),
        end: Vector2(1460, 720),
        size: Vector2(100, 70),
        sourceId: 'hazard.collision-archive.magnetic-crusher',
        style: PlatformSurfaceStyle.collision,
      ),
      CrusherHazardComponent(
        start: Vector2(2290, 400),
        end: Vector2(2290, 680),
        size: Vector2(90, 60),
        sourceId: 'hazard.collision-archive.polarity-crusher',
        style: PlatformSurfaceStyle.collision,
        periodSeconds: 3.4,
      ),
      JumpPadComponent(
        position: Vector2(990, 1012),
        style: PlatformSurfaceStyle.collision,
      ),
      JumpPadComponent(
        position: Vector2(1990, 1012),
        style: PlatformSurfaceStyle.collision,
      ),
      CheckpointBeaconComponent(
        position: Vector2(1030, 1024),
        index: 1,
        style: PlatformSurfaceStyle.collision,
        onActivated: _activateCheckpoint,
      ),
      CheckpointBeaconComponent(
        position: Vector2(2050, 1024),
        index: 2,
        style: PlatformSurfaceStyle.collision,
        onActivated: _activateCheckpoint,
      ),
    ]);
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.vectorRam, 330, 822),
      _enemy(PlatformerEnemyArchetype.polarityDrone, 880, 535),
      _enemy(PlatformerEnemyArchetype.phaseMimic, 1280, 372),
      _enemy(PlatformerEnemyArchetype.shardLobber, 2110, 642),
      _enemy(
        PlatformerEnemyArchetype.kernelChimera,
        2690,
        900,
        startsDormant: true,
      ),
    ]);
  }

  PlatformSurfaceComponent _surface(
    double x,
    double y,
    double width,
    double height, {
    bool boundary = false,
  }) => PlatformSurfaceComponent(
    position: Vector2(x, y),
    size: Vector2(width, height),
    isBoundary: boundary,
    style: PlatformSurfaceStyle.collision,
  );

  PlatformerEnemyComponent _enemy(
    PlatformerEnemyArchetype archetype,
    double x,
    double y, {
    bool startsDormant = false,
  }) => PlatformerEnemyComponent(
    archetype: archetype,
    position: Vector2(x, y),
    onDefeated: _onEnemyDefeated,
    startsDormant: startsDormant,
  );

  void _activateCheckpoint(int index, Vector2 respawnPoint) {
    _respawnPoint = respawnPoint;
  }

  void _onEnemyDefeated(PlatformerEnemyComponent enemy) {
    if (_completed) return;
    _defeatedCount += 1;
    game.runMetrics.recordOverflow();
    game.publishUiSnapshot(force: true);
    if (_defeatedCount == 4) {
      _bossGate.unlock();
      for (final candidate in children.whereType<PlatformerEnemyComponent>()) {
        if (candidate.archetype.isMidBoss) candidate.activateEncounter();
      }
      return;
    }
    if (_defeatedCount < 5) return;
    _completed = true;
    Future<void>.delayed(
      const Duration(milliseconds: 550),
      game.openRoomThreePatchSelection,
    );
  }

  bool tryMerge(CrawlerComponent first, CrawlerComponent second) => false;
  bool tryInteract(PlayerComponent player) => false;
}
