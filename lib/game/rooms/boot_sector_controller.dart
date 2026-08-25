import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/story_map_art_contract.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_map_terminal_component.dart';
import 'package:patch_world/game/components/environment/core_signature_gate_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
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

  static const Offset westSpawnCenter = Offset(180, 448);
  static const Offset eastSpawnCenter = Offset(710, 448);
  static const List<Rect> ordinaryStaticSurfaces = <Rect>[
    Rect.fromLTWH(0, 484, 960, 56),
    Rect.fromLTWH(300, 400, 150, 20),
    Rect.fromLTWH(520, 328, 150, 20),
  ];
  static const Map<String, Offset> mandatoryDoorFeet = <String, Offset>{
    'interaction.enterDamageLab': Offset(828, 484),
    'interaction.enterTemporalHall': Offset(150, 484),
    'interaction.enterCollisionArchive': Offset(300, 484),
    'interaction.enterOptimizerCore': Offset(690, 484),
  };

  final CampaignNodeEntry entry;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  CampaignDoorComponent? _damageLabDoor;
  final List<CampaignDoorComponent> _regionalDoors = <CampaignDoorComponent>[];
  CampaignDoorComponent? _optimizerDoor;
  CoreSignatureGateComponent? _optimizerGate;
  CampaignMapTerminalComponent? _mapTerminal;

  CoreSignatureGateComponent? get optimizerGate => _optimizerGate;

  @override
  Vector2 get playerSpawn => _vector(
    entry == CampaignNodeEntry.west ? westSpawnCenter : eastSpawnCenter,
  );

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
    final mapArtSpec = StoryMapArtCatalog.specFor(campaignNodeId);
    await add(
      StoryRoomLayersComponent(
        theme: mapArtSpec.theme,
        motif: mapArtSpec.motif,
        worldSize: worldSize,
      ),
    );
    _surfaces.addAll(<PlatformSurfaceComponent>[
      for (final bounds in ordinaryStaticSurfaces)
        PlatformSurfaceComponent(
          position: Vector2(bounds.left, bounds.top),
          size: Vector2(bounds.width, bounds.height),
          style: PlatformSurfaceStyle.damage,
          renderArtwork: true,
        ),
      PlatformSurfaceComponent(
        position: Vector2(0, 0),
        size: Vector2(24, 540),
        isBoundary: true,
        style: PlatformSurfaceStyle.damage,
        renderArtwork: false,
      ),
      PlatformSurfaceComponent(
        position: Vector2(936, 0),
        size: Vector2(24, 540),
        isBoundary: true,
        style: PlatformSurfaceStyle.damage,
        renderArtwork: false,
      ),
    ]);
    await addAll(_surfaces);
    final door = CampaignDoorComponent(
      position: _vector(mandatoryDoorFeet['interaction.enterDamageLab']!),
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
        position: _vector(mandatoryDoorFeet['interaction.enterTemporalHall']!),
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
    if (game.temporalHallProgress.patchApplied) {
      final collisionDoor = CampaignDoorComponent(
        position: _vector(
          mandatoryDoorFeet['interaction.enterCollisionArchive']!,
        ),
        labelLocalizationKey: 'interaction.enterCollisionArchive',
        onInteract: () => game.travelToCampaignNode(
          CampaignNodeId.collisionCompression,
          entry: CampaignNodeEntry.west,
        ),
      );
      _regionalDoors.add(collisionDoor);
      await add(collisionDoor);
    }
    final optimizerGate = CoreSignatureGateComponent(
      position: Vector2(690, 484),
      acquiredSignatures: game.campaignExploration.coreSignatures.length,
      requiredSignatures: 3,
      routeUnlocked: game.isOptimizerGateReady,
    );
    _optimizerGate = optimizerGate;
    await add(optimizerGate);
    if (optimizerGate.isUnlocked) {
      final optimizerDoor = CampaignDoorComponent(
        position: _vector(mandatoryDoorFeet['interaction.enterOptimizerCore']!),
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
        if (game.damageLabProgress.patchApplied) {
          game.campaignExploration.revealRegion(
            CampaignRegion.temporalHall,
            game.campaignWorld,
          );
        }
        if (game.temporalHallProgress.patchApplied) {
          game.campaignExploration.revealRegion(
            CampaignRegion.collisionArchive,
            game.campaignWorld,
          );
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

  static Vector2 _vector(Offset point) => Vector2(point.dx, point.dy);
}
