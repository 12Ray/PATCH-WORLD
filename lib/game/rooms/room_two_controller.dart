import 'dart:async';
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
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

  int get defeatedCount => _defeatedCount;
  int get activatedTerminalCount => _defeatedCount;

  @override
  Iterable<Rect> get solidBounds => _surfaces.map((surface) => surface.bounds);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(RoomBackdropStyle.temporal));
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(936, 0, 24, 540, boundary: true),
      _surface(0, 484, 350, 56),
      _surface(438, 484, 522, 56),
      _surface(138, 400, 150, 22),
      _surface(326, 330, 138, 22),
      _surface(505, 386, 140, 22),
      _surface(680, 306, 138, 22),
      _surface(824, 394, 112, 22),
    ]);
    await addAll(_surfaces);
    await add(
      DamagePitComponent(
        position: Vector2(350, 484),
        size: Vector2(88, 56),
        style: PlatformSurfaceStyle.temporal,
      ),
    );
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.tickRunner, 145, 466),
      _enemy(PlatformerEnemyArchetype.echoBat, 270, 250),
      _enemy(PlatformerEnemyArchetype.delaySniper, 392, 312),
      _enemy(PlatformerEnemyArchetype.rewindSkater, 575, 368),
      _enemy(
        PlatformerEnemyArchetype.chronoJailer,
        770,
        210,
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
