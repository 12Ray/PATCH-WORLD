import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class RoomTwoController extends Component
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
  int get activatedTerminalCount => _defeatedCount;

  @override
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) {
    if (playerPosition.x >= 1920) return Vector2(2040, 448);
    if (playerPosition.x >= 960) return Vector2(1010, 448);
    return playerSpawn.clone();
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(RoomBackdropStyle.temporal, worldSize: worldSize),
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(2856, 0, 24, 540, boundary: true),
      _surface(0, 484, 360, 56),
      _surface(450, 484, 400, 56),
      _surface(940, 484, 450, 56),
      _surface(1480, 484, 420, 56),
      _surface(1990, 484, 890, 56),
      _surface(150, 405, 170, 22),
      _surface(340, 330, 150, 22),
      _surface(520, 390, 150, 22),
      _surface(700, 300, 160, 22),
      _surface(850, 410, 130, 20),
      _surface(1040, 350, 150, 22),
      _surface(1210, 270, 160, 22),
      _surface(1380, 405, 140, 20),
      _surface(1540, 340, 160, 22),
      _surface(1740, 260, 150, 22),
      _surface(1890, 410, 140, 20),
      _surface(2070, 360, 150, 22),
      _surface(2240, 285, 160, 22),
      _surface(2410, 390, 145, 22),
      _surface(2540, 425, 316, 59),
      _surface(610, 430, 48, 54),
      _surface(1320, 430, 50, 54),
      _surface(2300, 430, 54, 54),
    ]);
    await addAll(_surfaces);
    await addAll(<Component>[
      for (final pit in <(double, double)>[
        (360, 90),
        (850, 90),
        (1390, 90),
        (1900, 90),
      ])
        DamagePitComponent(
          position: Vector2(pit.$1, 484),
          size: Vector2(pit.$2, 56),
          style: PlatformSurfaceStyle.temporal,
        ),
      RoomHazardComponent(
        position: Vector2(1120, 338),
        size: Vector2(56, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.temporal-hall.clock-teeth',
      ),
      RoomHazardComponent(
        position: Vector2(1810, 282),
        size: Vector2(14, 128),
        style: RoomHazardStyle.laser,
        sourceId: 'hazard.temporal-hall.timeline-cut',
      ),
      RoomHazardComponent(
        position: Vector2(2320, 307),
        size: Vector2(14, 123),
        style: RoomHazardStyle.laser,
        sourceId: 'hazard.temporal-hall.clock-hand',
      ),
      JumpPadComponent(position: Vector2(960, 472)),
      JumpPadComponent(position: Vector2(2035, 472)),
      CheckpointBeaconComponent(position: Vector2(1010, 484), index: 1),
      CheckpointBeaconComponent(position: Vector2(2040, 484), index: 2),
    ]);
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.tickRunner, 290, 466),
      _enemy(PlatformerEnemyArchetype.echoBat, 760, 235),
      _enemy(PlatformerEnemyArchetype.delaySniper, 1280, 252),
      _enemy(PlatformerEnemyArchetype.rewindSkater, 1640, 322),
      _enemy(
        PlatformerEnemyArchetype.chronoJailer,
        2690,
        360,
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
    style: PlatformSurfaceStyle.temporal,
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
      game.openRoomTwoPatchSelection,
    );
  }

  bool tryInteract(PlayerComponent player) => false;
}
