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

  @override
  final Vector2 playerSpawn = Vector2(70, 448);

  @override
  final Vector2 worldSize = Vector2(2880, PatchWorldGame.logicalHeight);

  int get defeatedCount => _defeatedCount;

  @override
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) {
    if (playerPosition.x >= 1920) return Vector2(2050, 448);
    if (playerPosition.x >= 960) return Vector2(1030, 448);
    return playerSpawn.clone();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(RoomBackdropStyle.collision, worldSize: worldSize),
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(2856, 0, 24, 540, boundary: true),
      _surface(0, 484, 390, 56),
      _surface(480, 484, 430, 56),
      _surface(1000, 484, 430, 56),
      _surface(1520, 484, 400, 56),
      _surface(2010, 484, 870, 56),
      _surface(130, 390, 150, 22),
      _surface(300, 315, 150, 22),
      _surface(500, 400, 150, 22),
      _surface(660, 330, 150, 22),
      _surface(820, 250, 150, 22),
      _surface(920, 410, 130, 20),
      _surface(1080, 350, 150, 22),
      _surface(1240, 275, 150, 22),
      _surface(1400, 395, 150, 22),
      _surface(1580, 310, 150, 22),
      _surface(1740, 230, 150, 22),
      _surface(1910, 410, 140, 20),
      _surface(2080, 350, 150, 22),
      _surface(2260, 270, 150, 22),
      _surface(2415, 380, 145, 22),
      _surface(2540, 425, 316, 59),
      _surface(560, 430, 58, 54),
      _surface(1160, 430, 60, 54),
      _surface(1810, 430, 58, 54),
      _surface(2320, 430, 60, 54),
    ]);
    await addAll(_surfaces);
    await addAll(<Component>[
      for (final pit in <(double, double)>[
        (390, 90),
        (910, 90),
        (1430, 90),
        (1920, 90),
      ])
        DamagePitComponent(
          position: Vector2(pit.$1, 484),
          size: Vector2(pit.$2, 56),
          style: PlatformSurfaceStyle.collision,
        ),
      RoomHazardComponent(
        position: Vector2(710, 318),
        size: Vector2(64, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.collision-archive.compression-teeth',
      ),
      RoomHazardComponent(
        position: Vector2(1300, 297),
        size: Vector2(14, 133),
        style: RoomHazardStyle.laser,
        sourceId: 'hazard.collision-archive.vector-slice',
      ),
      RoomHazardComponent(
        position: Vector2(2180, 362),
        size: Vector2(14, 68),
        style: RoomHazardStyle.laser,
        sourceId: 'hazard.collision-archive.merge-beam',
      ),
      JumpPadComponent(position: Vector2(505, 472)),
      JumpPadComponent(position: Vector2(1535, 472)),
      JumpPadComponent(position: Vector2(2040, 472)),
      CheckpointBeaconComponent(position: Vector2(1030, 484), index: 1),
      CheckpointBeaconComponent(position: Vector2(2050, 484), index: 2),
    ]);
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.vectorRam, 220, 372),
      _enemy(PlatformerEnemyArchetype.polarityDrone, 780, 230),
      _enemy(PlatformerEnemyArchetype.phaseMimic, 1300, 257),
      _enemy(PlatformerEnemyArchetype.shardLobber, 2120, 332),
      _enemy(
        PlatformerEnemyArchetype.kernelChimera,
        2690,
        394,
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
      const Duration(milliseconds: 550),
      game.openRoomThreePatchSelection,
    );
  }

  bool tryMerge(CrawlerComponent first, CrawlerComponent second) => false;
  bool tryInteract(PlayerComponent player) => false;
}
