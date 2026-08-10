import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
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

  int get overflowCount => _defeatedCount;
  int get defeatedCount => _defeatedCount;
  bool get isCompleted => _completed;

  @override
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.damage));
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(936, 0, 24, 540, boundary: true),
      _surface(0, 484, 278, 56),
      _surface(392, 484, 568, 56),
      _surface(168, 404, 142, 22),
      _surface(330, 338, 128, 22),
      _surface(506, 405, 142, 22),
      _surface(666, 326, 130, 22),
      _surface(804, 410, 132, 22),
    ]);
    await addAll(_surfaces);
    await add(
      DamagePitComponent(position: Vector2(278, 484), size: Vector2(114, 56)),
    );
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.patchMite, 210, 466),
      _enemy(PlatformerEnemyArchetype.checksumHopper, 230, 386),
      _enemy(PlatformerEnemyArchetype.pulseTurret, 390, 320),
      _enemy(PlatformerEnemyArchetype.repairLeech, 570, 387),
      _enemy(
        PlatformerEnemyArchetype.overflowWarden,
        858,
        379,
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
