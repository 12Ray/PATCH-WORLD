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

  @override
  final Vector2 playerSpawn = Vector2(72, 448);

  @override
  final Vector2 worldSize = Vector2(2880, PatchWorldGame.logicalHeight);

  int get overflowCount => _defeatedCount;
  int get defeatedCount => _defeatedCount;
  bool get isCompleted => _completed;

  @override
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) {
    if (playerPosition.x >= 1920) return Vector2(2070, 448);
    if (playerPosition.x >= 960) return Vector2(1040, 448);
    return playerSpawn.clone();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(RoomBackdropStyle.damage, worldSize: worldSize),
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(2856, 0, 24, 540, boundary: true),
      _surface(0, 484, 430, 56),
      _surface(520, 484, 380, 56),
      _surface(990, 484, 440, 56),
      _surface(1520, 484, 420, 56),
      _surface(2030, 484, 850, 56),
      _surface(180, 410, 180, 22),
      _surface(370, 350, 150, 22),
      _surface(560, 400, 150, 22),
      _surface(745, 320, 150, 22),
      _surface(900, 420, 150, 20),
      _surface(1080, 370, 150, 22),
      _surface(1260, 300, 150, 22),
      _surface(1435, 390, 150, 22),
      _surface(1580, 330, 150, 22),
      _surface(1760, 250, 150, 22),
      _surface(1910, 410, 150, 22),
      _surface(2070, 370, 150, 22),
      _surface(2240, 300, 150, 22),
      _surface(2400, 390, 150, 22),
      _surface(2520, 430, 336, 54),
      _surface(690, 430, 54, 54),
      _surface(1480, 430, 40, 54),
      _surface(2290, 430, 54, 54),
    ]);
    await addAll(_surfaces);
    await addAll(<Component>[
      DamagePitComponent(position: Vector2(430, 484), size: Vector2(90, 56)),
      DamagePitComponent(position: Vector2(900, 484), size: Vector2(90, 56)),
      DamagePitComponent(position: Vector2(1430, 484), size: Vector2(90, 56)),
      DamagePitComponent(position: Vector2(1940, 484), size: Vector2(90, 56)),
      RoomHazardComponent(
        position: Vector2(1160, 358),
        size: Vector2(64, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.damage-lab.conduit-spikes',
      ),
      RoomHazardComponent(
        position: Vector2(1700, 300),
        size: Vector2(14, 150),
        style: RoomHazardStyle.laser,
        sourceId: 'hazard.damage-lab.test-laser',
      ),
      JumpPadComponent(position: Vector2(1560, 472)),
      JumpPadComponent(position: Vector2(2320, 418)),
      CheckpointBeaconComponent(position: Vector2(1040, 484), index: 1),
      CheckpointBeaconComponent(position: Vector2(2070, 484), index: 2),
    ]);
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.patchMite, 300, 466),
      _enemy(PlatformerEnemyArchetype.checksumHopper, 810, 302),
      _enemy(PlatformerEnemyArchetype.pulseTurret, 1335, 282),
      _enemy(PlatformerEnemyArchetype.repairLeech, 2110, 352),
      _enemy(
        PlatformerEnemyArchetype.overflowWarden,
        2670,
        399,
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

  void _onEnemyDefeated(PlatformerEnemyComponent enemy) {
    if (_completed) return;
    _defeatedCount += 1;
    game.runMetrics.recordOverflow();
    game.publishUiSnapshot(force: true);
    if (_defeatedCount == 4) {
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
