import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
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

  int get defeatedCount => _defeatedCount;

  @override
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.collision));
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(936, 0, 24, 540, boundary: true),
      _surface(0, 484, 240, 56),
      _surface(326, 484, 634, 56),
      _surface(120, 392, 130, 22),
      _surface(282, 318, 132, 22),
      _surface(458, 400, 128, 22),
      _surface(625, 326, 138, 22),
      _surface(788, 402, 148, 22),
      _surface(520, 250, 112, 20),
    ]);
    await addAll(_surfaces);
    await add(
      DamagePitComponent(
        position: Vector2(240, 484),
        size: Vector2(86, 56),
        style: PlatformSurfaceStyle.collision,
      ),
    );
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.vectorRam, 150, 374),
      _enemy(PlatformerEnemyArchetype.polarityDrone, 355, 225),
      _enemy(PlatformerEnemyArchetype.phaseMimic, 520, 382),
      _enemy(PlatformerEnemyArchetype.shardLobber, 690, 308),
      _enemy(
        PlatformerEnemyArchetype.kernelChimera,
        855,
        371,
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
