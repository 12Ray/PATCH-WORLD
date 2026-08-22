import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_map_terminal_component.dart';
import 'package:patch_world/game/components/environment/core_signature_gate_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class BootSectorController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        CampaignNodeRoom {
  BootSectorController({this.entry = CampaignNodeEntry.west});

  final CampaignNodeEntry entry;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  CampaignDoorComponent? _damageLabDoor;
  final List<CampaignDoorComponent> _regionalDoors = <CampaignDoorComponent>[];
  CampaignDoorComponent? _optimizerDoor;
  CoreSignatureGateComponent? _optimizerGate;
  CampaignMapTerminalComponent? _mapTerminal;

  CoreSignatureGateComponent? get optimizerGate => _optimizerGate;

  @override
  Vector2 get playerSpawn =>
      entry == CampaignNodeEntry.west ? Vector2(180, 448) : Vector2(710, 448);

  @override
  CampaignNodeId get campaignNodeId => CampaignNodeId.bootSector;

  @override
  final Vector2 worldSize = Vector2(960, 540);

  @override
  double get killPlaneY => 620;

  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) => playerSpawn.clone();

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) => Vector2(480, 270);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(_BootSectorBackdrop(size: worldSize));
    _surfaces.addAll(<PlatformSurfaceComponent>[
      PlatformSurfaceComponent(
        position: Vector2(0, 484),
        size: Vector2(960, 56),
        style: PlatformSurfaceStyle.damage,
      ),
      PlatformSurfaceComponent(
        position: Vector2(0, 0),
        size: Vector2(24, 540),
        isBoundary: true,
        style: PlatformSurfaceStyle.damage,
      ),
      PlatformSurfaceComponent(
        position: Vector2(936, 0),
        size: Vector2(24, 540),
        isBoundary: true,
        style: PlatformSurfaceStyle.damage,
      ),
      PlatformSurfaceComponent(
        position: Vector2(300, 400),
        size: Vector2(150, 20),
        style: PlatformSurfaceStyle.damage,
      ),
      PlatformSurfaceComponent(
        position: Vector2(520, 328),
        size: Vector2(150, 20),
        style: PlatformSurfaceStyle.damage,
      ),
    ]);
    await addAll(_surfaces);
    final door = CampaignDoorComponent(
      position: Vector2(828, 484),
      labelLocalizationKey: 'interaction.enterDamageLab',
      onInteract: () => game.travelToCampaignNode(
        CampaignNodeId.damageWorkshop,
        entry: CampaignNodeEntry.west,
      ),
    );
    _damageLabDoor = door;
    await add(door);
    if (game.damageLabProgress.patchApplied) {
      final temporalDoor = CampaignDoorComponent(
        position: Vector2(150, 484),
        labelLocalizationKey: 'interaction.enterTemporalHall',
        accentColor: const Color(0xFF9D8CFF),
        onInteract: () => game.travelToCampaignNode(
          CampaignNodeId.temporalAscent,
          entry: CampaignNodeEntry.west,
        ),
      );
      _regionalDoors.addAll(<CampaignDoorComponent>[temporalDoor]);
      await addAll(_regionalDoors);
    }
    final optimizerGate = CoreSignatureGateComponent(
      position: Vector2(690, 484),
      acquiredSignatures: game.campaignExploration.coreSignatures.length,
      requiredSignatures: 3,
    );
    _optimizerGate = optimizerGate;
    await add(optimizerGate);
    if (optimizerGate.isUnlocked) {
      final optimizerDoor = CampaignDoorComponent(
        position: Vector2(690, 484),
        labelLocalizationKey: 'interaction.enterOptimizerCore',
        accentColor: const Color(0xFFFFD35A),
        onInteract: () => game.travelToCampaignNode(
          CampaignNodeId.optimizerCore,
          entry: CampaignNodeEntry.west,
        ),
      );
      _optimizerDoor = optimizerDoor;
      await add(optimizerDoor);
    }
    final mapTerminal = CampaignMapTerminalComponent(
      position: Vector2(480, 484),
      onInteract: () {
        game.campaignExploration.revealRegion(
          CampaignRegion.damageLab,
          game.campaignWorld,
        );
        if (game.temporalHallProgress.bossDefeated) {
          game.campaignExploration
            ..revealRegion(CampaignRegion.temporalHall, game.campaignWorld)
            ..revealRegion(CampaignRegion.collisionArchive, game.campaignWorld);
        }
        game.openCampaignMap();
      },
    );
    _mapTerminal = mapTerminal;
    await add(mapTerminal);
  }

  bool tryInteract(PlayerComponent player) {
    if (_mapTerminal?.tryUse(player) ?? false) return true;
    if (_damageLabDoor?.tryEnter(player) ?? false) return true;
    for (final door in _regionalDoors) {
      if (door.tryEnter(player)) return true;
    }
    return _optimizerDoor?.tryEnter(player) ?? false;
  }
}

final class _BootSectorBackdrop extends PositionComponent {
  _BootSectorBackdrop({required super.size}) : super(priority: -85);

  @override
  void render(Canvas canvas) {
    final bounds = Offset.zero & Size(size.x, size.y);
    canvas.drawRect(bounds, Paint()..color = const Color(0xFF080D1B));
    canvas.drawCircle(
      const Offset(480, 230),
      170,
      Paint()..color = const Color(0x1827C7D9),
    );
    final circuitPaint = Paint()
      ..color = const Color(0x5536E1FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (var index = 0; index < 6; index += 1) {
      final y = 92.0 + index * 58;
      canvas.drawLine(Offset(40, y), Offset(920, y), circuitPaint);
      canvas.drawCircle(Offset(160 + index * 120, y), 5, circuitPaint);
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(350, 120, 260, 160),
        const Radius.circular(18),
      ),
      Paint()
        ..color = const Color(0x44265A78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
    );
    super.render(canvas);
  }
}
