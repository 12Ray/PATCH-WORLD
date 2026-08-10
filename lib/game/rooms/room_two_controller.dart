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
  Vector2 _respawnPoint = Vector2(70, 988);
  late final BossSealGateComponent _bossGate;

  @override
  final Vector2 playerSpawn = Vector2(70, 988);

  @override
  final Vector2 worldSize = Vector2(2880, 1080);

  @override
  double get killPlaneY => 1160;

  int get defeatedCount => _defeatedCount;
  int get activatedTerminalCount => _defeatedCount;

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
      RoomBackdropComponent(RoomBackdropStyle.temporal, worldSize: worldSize),
    );
    _bossGate = BossSealGateComponent(
      position: Vector2(2490, 610),
      size: Vector2(28, 414),
      style: PlatformSurfaceStyle.temporal,
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 1080, boundary: true),
      _surface(2856, 0, 24, 1080, boundary: true),
      _surface(0, 1024, 330, 56),
      _surface(420, 1024, 400, 56),
      _surface(910, 1024, 420, 56),
      _surface(1420, 1024, 420, 56),
      _surface(1930, 1024, 950, 56),
      _surface(120, 930, 180, 22),
      _surface(300, 840, 170, 22),
      _surface(480, 750, 180, 22),
      _surface(650, 660, 180, 22),
      _surface(820, 570, 180, 22),
      _surface(990, 480, 180, 22),
      _surface(1160, 390, 180, 22),
      _surface(1330, 480, 180, 22),
      _surface(1500, 570, 180, 22),
      _surface(1670, 660, 180, 22),
      _surface(1840, 750, 180, 22),
      _surface(2010, 840, 180, 22),
      _surface(2190, 750, 180, 22),
      _surface(2340, 660, 170, 22),
      _surface(2520, 944, 336, 80),
      MovingPlatformComponent(
        start: Vector2(560, 900),
        end: Vector2(560, 690),
        size: Vector2(120, 22),
        periodSeconds: 4.0,
        style: PlatformSurfaceStyle.temporal,
      ),
      MovingPlatformComponent(
        start: Vector2(1050, 780),
        end: Vector2(1240, 690),
        size: Vector2(120, 22),
        periodSeconds: 3.2,
        style: PlatformSurfaceStyle.temporal,
      ),
      MovingPlatformComponent(
        start: Vector2(1770, 500),
        end: Vector2(1950, 410),
        size: Vector2(120, 22),
        periodSeconds: 3.6,
        style: PlatformSurfaceStyle.temporal,
      ),
      BreakablePlatformComponent(
        position: Vector2(1370, 760),
        size: Vector2(150, 22),
        style: PlatformSurfaceStyle.temporal,
      ),
      _bossGate,
    ]);
    await addAll(_surfaces);
    await addAll(<Component>[
      for (final pit in <(double, double)>[
        (330, 90),
        (820, 90),
        (1330, 90),
        (1840, 90),
      ])
        DamagePitComponent(
          position: Vector2(pit.$1, 1024),
          size: Vector2(pit.$2, 56),
          style: PlatformSurfaceStyle.temporal,
        ),
      RoomHazardComponent(
        position: Vector2(690, 648),
        size: Vector2(100, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.temporal-hall.clock-teeth',
      ),
      RoomHazardComponent(
        position: Vector2(1515, 558),
        size: Vector2(100, 12),
        style: RoomHazardStyle.spikes,
        sourceId: 'hazard.temporal-hall.rewind-teeth',
      ),
      PulsingLaserComponent(
        position: Vector2(940, 592),
        size: Vector2(14, 342),
        sourceId: 'hazard.temporal-hall.timeline-cut',
        activeSeconds: 1.1,
        inactiveSeconds: 1.3,
      ),
      PulsingLaserComponent(
        position: Vector2(1590, 592),
        size: Vector2(14, 342),
        sourceId: 'hazard.temporal-hall.clock-hand',
        activeSeconds: 1.3,
        inactiveSeconds: 1.1,
        phaseOffset: 1.2,
      ),
      CrusherHazardComponent(
        start: Vector2(2130, 380),
        end: Vector2(2130, 690),
        size: Vector2(90, 60),
        sourceId: 'hazard.temporal-hall.pendulum',
        periodSeconds: 4.2,
      ),
      JumpPadComponent(position: Vector2(930, 1012)),
      JumpPadComponent(position: Vector2(1960, 1012)),
      CheckpointBeaconComponent(
        position: Vector2(1010, 1024),
        index: 1,
        onActivated: _activateCheckpoint,
      ),
      CheckpointBeaconComponent(
        position: Vector2(2040, 1024),
        index: 2,
        onActivated: _activateCheckpoint,
      ),
    ]);
    await addAll(<PlatformerEnemyComponent>[
      _enemy(PlatformerEnemyArchetype.tickRunner, 350, 822),
      _enemy(PlatformerEnemyArchetype.echoBat, 880, 535),
      _enemy(PlatformerEnemyArchetype.delaySniper, 1250, 372),
      _enemy(PlatformerEnemyArchetype.rewindSkater, 1870, 732),
      _enemy(
        PlatformerEnemyArchetype.chronoJailer,
        2690,
        885,
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
      game.openRoomTwoPatchSelection,
    );
  }

  bool tryInteract(PlayerComponent player) => false;
}
