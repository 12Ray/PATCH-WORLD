import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class RoomOneController extends Component
    with HasGameReference<PatchWorldGame>
    implements PlatformerRoomGeometry {
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  int _defeatedCount = 0;
  bool _completed = false;
  Vector2 _respawnPoint = Vector2(72, 988);
  late final BossSealGateComponent _bossGate;

  @override
  final Vector2 playerSpawn = Vector2(72, 988);

  @override
  final Vector2 worldSize = Vector2(2880, 1080);

  @override
  double get killPlaneY => 1160;

  int get overflowCount => _defeatedCount;
  int get defeatedCount => _defeatedCount;
  bool get isCompleted => _completed;

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
      RoomBackdropComponent(RoomBackdropStyle.damage, worldSize: worldSize),
    );
    _bossGate = BossSealGateComponent(
      position: Vector2(2480, 700),
      size: Vector2(28, 324),
      style: PlatformSurfaceStyle.damage,
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 1080, boundary: true),
      _surface(2856, 0, 24, 1080, boundary: true),
      _surface(0, 1024, 390, 56),
      _surface(480, 1024, 420, 56),
      _surface(990, 1024, 430, 56),
      _surface(1510, 1024, 410, 56),
      _surface(2010, 1024, 870, 56),
      _surface(110, 934, 220, 22),
      _surface(300, 850, 210, 22),
      _surface(500, 772, 190, 22),
      _surface(700, 694, 185, 22),
      _surface(885, 614, 180, 22),
      _surface(1060, 536, 180, 22),
      _surface(1225, 456, 190, 22),
      _surface(1390, 376, 170, 22),
      _surface(1540, 456, 190, 22),
      _surface(1700, 536, 190, 22),
      _surface(1860, 616, 180, 22),
      _surface(2020, 696, 200, 22),
      _surface(2200, 776, 180, 22),
      _surface(2320, 856, 180, 22),
      _surface(2520, 944, 336, 80),
      ConveyorPlatformComponent(
        position: Vector2(560, 930),
        size: Vector2(250, 24),
        direction: 1,
      ),
      ConveyorPlatformComponent(
        position: Vector2(1580, 850),
        size: Vector2(260, 24),
        direction: -1,
      ),
      MovingPlatformComponent(
        start: Vector2(940, 830),
        end: Vector2(940, 680),
        size: Vector2(120, 22),
        periodSeconds: 3.4,
      ),
      MovingPlatformComponent(
        start: Vector2(1910, 870),
        end: Vector2(2050, 790),
        size: Vector2(130, 22),
        periodSeconds: 3.8,
      ),
      _bossGate,
    ]);
    await addAll(_surfaces);
    await addAll(<Component>[
      for (final pit in <(double, double)>[
        (390, 90),
        (900, 90),
        (1420, 90),
        (1920, 90),
      ])
        DamagePitComponent(
          position: Vector2(pit.$1, 1024),
          size: Vector2(pit.$2, 56),
        ),
      RoomHazardComponent(
        position: Vector2(735, 682),
        size: Vector2(90, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.damage-lab.conduit-spikes',
      ),
      RoomHazardComponent(
        position: Vector2(1715, 524),
        size: Vector2(90, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.damage-lab.overflow-spikes',
      ),
      PulsingLaserComponent(
        position: Vector2(1310, 478),
        size: Vector2(14, 290),
        sourceId: 'hazard.damage-lab.test-laser',
      ),
      PulsingLaserComponent(
        position: Vector2(2180, 790),
        size: Vector2(14, 234),
        sourceId: 'hazard.damage-lab.linked-laser',
        phaseOffset: 1.2,
      ),
      JumpPadComponent(position: Vector2(1015, 1012)),
      JumpPadComponent(position: Vector2(2050, 1012)),
      CheckpointBeaconComponent(
        position: Vector2(1050, 1024),
        index: 1,
        onActivated: _activateCheckpoint,
      ),
      CheckpointBeaconComponent(
        position: Vector2(2070, 1024),
        index: 2,
        onActivated: _activateCheckpoint,
      ),
    ]);
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.patchMite, 330, 832),
      _enemy(PlatformerEnemyArchetype.checksumHopper, 790, 676),
      _enemy(PlatformerEnemyArchetype.pulseTurret, 1320, 438),
      _enemy(PlatformerEnemyArchetype.repairLeech, 2120, 678),
      _enemy(
        PlatformerEnemyArchetype.overflowWarden,
        2690,
        910,
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
      const Duration(milliseconds: 500),
      game.openRoomOnePatchSelection,
    );
  }
}
