import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/campaign/story_map_art_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/ranged_route_switch_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

final class DamageLabSecretController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        CampaignNodeRoom {
  DamageLabSecretController({required this.nodeId, required this.progress})
    : assert(_supportedNodes.contains(nodeId));

  static const Set<CampaignNodeId> _supportedNodes = <CampaignNodeId>{
    CampaignNodeId.damageDashCache,
    CampaignNodeId.damageUpperArchive,
    CampaignNodeId.damageTurretControl,
  };
  static const double _floorY = 484;

  final CampaignNodeId nodeId;
  final DamageLabFloorState progress;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  CampaignDoorComponent? _returnDoor;
  ItemPedestalComponent? _reward;
  PlatformSurfaceComponent? _gunGateUpper;
  PlatformSurfaceComponent? _gunGateLower;

  @override
  CampaignNodeId get campaignNodeId => nodeId;

  PlayerWeapon get requiredWeapon => switch (nodeId) {
    CampaignNodeId.damageDashCache => PlayerWeapon.sword,
    CampaignNodeId.damageUpperArchive => PlayerWeapon.gauntlet,
    CampaignNodeId.damageTurretControl => PlayerWeapon.gun,
    _ => throw StateError('Unsupported secret node: $nodeId'),
  };

  RunItemId get rewardItem => switch (nodeId) {
    CampaignNodeId.damageDashCache => RunItemId.dashBuffer,
    CampaignNodeId.damageUpperArchive => RunItemId.airStack,
    CampaignNodeId.damageTurretControl => RunItemId.targetingDaemon,
    _ => throw StateError('Unsupported secret node: $nodeId'),
  };

  StoryMapArtSpec get mapArtSpec => StoryMapArtCatalog.specFor(nodeId);

  StoryRoomVisualMotif get visualMotif => mapArtSpec.motif;

  bool get rewardClaimed =>
      progress.claimedSecretRewardIds.contains(nodeId.name);
  bool get isGunGateOpen => _gunGateUpper == null && _gunGateLower == null;

  TraversalSegment get challengeSegment => switch (nodeId) {
    CampaignNodeId.damageDashCache => const TraversalSegment(
      id: 'damage.secret.sword-dash-gap',
      rise: 0,
      gap: 180,
      landingWidth: 500,
      requiredForCompletion: false,
      requirement: TraversalAbilityRequirement.swordDash,
    ),
    CampaignNodeId.damageUpperArchive => const TraversalSegment(
      id: 'damage.secret.gauntlet-upper-shaft',
      rise: 160,
      gap: 0,
      landingWidth: 260,
      requiredForCompletion: false,
      requirement: TraversalAbilityRequirement.gauntletDoubleJump,
    ),
    CampaignNodeId.damageTurretControl => const TraversalSegment(
      id: 'damage.secret.gun-window-switch',
      rise: 0,
      gap: 0,
      landingWidth: 500,
      requiredForCompletion: false,
      requirement: TraversalAbilityRequirement.gunRangedSwitch,
    ),
    _ => throw StateError('Unsupported secret node: $nodeId'),
  };

  @override
  Vector2 get playerSpawn => Vector2(150, 448);

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
    await add(
      StoryRoomLayersComponent(
        theme: mapArtSpec.theme,
        motif: visualMotif,
        worldSize: worldSize,
      ),
    );
    _buildGeometry();
    await addAll(_surfaces);
    if (nodeId == CampaignNodeId.damageDashCache) {
      await add(
        DamagePitComponent(
          position: Vector2(280, _floorY),
          size: Vector2(180, 56),
        ),
      );
    }
    if (nodeId == CampaignNodeId.damageTurretControl && !rewardClaimed) {
      final routeSwitch = RangedRouteSwitchComponent(
        position: Vector2(530, 350),
        onActivated: _openGunGate,
      );
      await add(routeSwitch);
    }
    final returnDoor = CampaignDoorComponent(
      position: Vector2(70, _floorY),
      labelLocalizationKey: 'interaction.returnAssembly',
      accentColor: const Color(0xFF9D8CFF),
      onInteract: () => game.travelToCampaignNode(
        CampaignNodeId.damageAssembly,
        entry: CampaignNodeEntry.east,
      ),
    );
    _returnDoor = returnDoor;
    await add(returnDoor);
    if (!rewardClaimed) await _spawnReward();
  }

  void _buildGeometry() {
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(936, 0, 24, 540, boundary: true),
      ...switch (nodeId) {
        CampaignNodeId.damageDashCache => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 280, 56),
          _surface(460, _floorY, 500, 56),
        ],
        CampaignNodeId.damageUpperArchive => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 960, 56),
          _surface(610, 324, 260, 22),
        ],
        CampaignNodeId.damageTurretControl => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 960, 56),
          if (!rewardClaimed) ..._buildGunGate(),
        ],
        _ => <PlatformSurfaceComponent>[],
      },
    ]);
  }

  List<PlatformSurfaceComponent> _buildGunGate() {
    final upper = _surface(400, 0, 30, 330, boundary: true);
    final lower = _surface(400, 370, 30, 114, boundary: true);
    _gunGateUpper = upper;
    _gunGateLower = lower;
    return <PlatformSurfaceComponent>[upper, lower];
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
    style: PlatformSurfaceStyle.damage,
    renderArtwork: !boundary,
  );

  Future<void> _spawnReward() async {
    final position = switch (nodeId) {
      CampaignNodeId.damageDashCache => Vector2(790, _floorY - 6),
      CampaignNodeId.damageUpperArchive => Vector2(750, 318),
      CampaignNodeId.damageTurretControl => Vector2(790, _floorY - 6),
      _ => throw StateError('Unsupported secret node: $nodeId'),
    };
    final pedestal = ItemPedestalComponent(
      position: position,
      item: rewardItem,
      onCollected: (_) {
        progress.claimedSecretRewardIds.add(nodeId.name);
        if (rewardItem == RunItemId.airStack) {
          game.world.player.increaseMaximumIntegrity(1);
        }
        _reward = null;
      },
    );
    _reward = pedestal;
    await add(pedestal);
  }

  void _openGunGate() {
    for (final gate in <PlatformSurfaceComponent?>[
      _gunGateUpper,
      _gunGateLower,
    ]) {
      if (gate == null) continue;
      _surfaces.remove(gate);
      gate.removeFromParent();
    }
    _gunGateUpper = null;
    _gunGateLower = null;
    game.triggerImpactFeedback();
  }

  bool tryInteract(PlayerComponent player) {
    if (_returnDoor?.tryEnter(player) ?? false) return true;
    return _reward?.tryCollect(player) ?? false;
  }
}
