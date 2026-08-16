import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/ranged_route_switch_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

/// Optional weapon-locked rooms branching from the second room of Temporal
/// Hall and Collision Archive. Rewards are run-persistent but never required
/// for the region boss or Optimizer gate.
final class RegionalSecretController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        CampaignNodeRoom {
  RegionalSecretController({required this.nodeId, required this.progress})
    : assert(_supportedNodes.contains(nodeId));

  static const double _floorY = 484;
  static const Set<CampaignNodeId> _supportedNodes = <CampaignNodeId>{
    CampaignNodeId.temporalDashRift,
    CampaignNodeId.temporalUpperLoop,
    CampaignNodeId.temporalRelayControl,
    CampaignNodeId.collisionVectorCache,
    CampaignNodeId.collisionUpperMatrix,
    CampaignNodeId.collisionPrismControl,
  };

  final CampaignNodeId nodeId;
  final CampaignFloorState progress;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  CampaignDoorComponent? _returnDoor;
  ItemPedestalComponent? _reward;
  PlatformSurfaceComponent? _gunGateUpper;
  PlatformSurfaceComponent? _gunGateLower;

  @override
  CampaignNodeId get campaignNodeId => nodeId;

  bool get isTemporal => switch (nodeId) {
    CampaignNodeId.temporalDashRift ||
    CampaignNodeId.temporalUpperLoop ||
    CampaignNodeId.temporalRelayControl => true,
    _ => false,
  };

  bool get isSwordRoute => requiredWeapon == PlayerWeapon.sword;
  bool get isGauntletRoute => requiredWeapon == PlayerWeapon.gauntlet;
  bool get isGunRoute => requiredWeapon == PlayerWeapon.gun;

  CampaignNodeId get returnNode => isTemporal
      ? CampaignNodeId.temporalFracture
      : CampaignNodeId.collisionFracture;

  PlayerWeapon get requiredWeapon => switch (nodeId) {
    CampaignNodeId.temporalDashRift ||
    CampaignNodeId.collisionVectorCache => PlayerWeapon.sword,
    CampaignNodeId.temporalUpperLoop ||
    CampaignNodeId.collisionUpperMatrix => PlayerWeapon.gauntlet,
    CampaignNodeId.temporalRelayControl ||
    CampaignNodeId.collisionPrismControl => PlayerWeapon.gun,
    _ => throw StateError('Unsupported regional secret node: $nodeId'),
  };

  RunItemId get rewardItem => switch (nodeId) {
    CampaignNodeId.temporalDashRift => RunItemId.chronalBuffer,
    CampaignNodeId.temporalUpperLoop => RunItemId.echoSpring,
    CampaignNodeId.temporalRelayControl => RunItemId.predictiveScope,
    CampaignNodeId.collisionVectorCache => RunItemId.vectorEdge,
    CampaignNodeId.collisionUpperMatrix => RunItemId.impactLattice,
    CampaignNodeId.collisionPrismControl => RunItemId.splitChamber,
    _ => throw StateError('Unsupported regional secret node: $nodeId'),
  };

  bool get rewardClaimed =>
      progress.claimedSecretRewardIds.contains(nodeId.name);
  bool get isGunGateOpen => _gunGateUpper == null && _gunGateLower == null;

  TraversalSegment get challengeSegment => switch (requiredWeapon) {
    PlayerWeapon.sword => TraversalSegment(
      id: '${nodeId.name}.dash-gap',
      rise: 0,
      gap: isTemporal ? 190 : 200,
      landingWidth: isTemporal ? 490 : 480,
      requiredForCompletion: false,
      requirement: TraversalAbilityRequirement.swordDash,
    ),
    PlayerWeapon.gauntlet => TraversalSegment(
      id: '${nodeId.name}.upper-shaft',
      rise: 160,
      gap: 0,
      landingWidth: 260,
      requiredForCompletion: false,
      requirement: TraversalAbilityRequirement.gauntletDoubleJump,
    ),
    PlayerWeapon.gun => TraversalSegment(
      id: '${nodeId.name}.ranged-switch',
      rise: 0,
      gap: 0,
      landingWidth: 500,
      requiredForCompletion: false,
      requirement: TraversalAbilityRequirement.gunRangedSwitch,
    ),
  };

  PlatformSurfaceStyle get surfaceStyle => isTemporal
      ? PlatformSurfaceStyle.temporal
      : PlatformSurfaceStyle.collision;

  RoomBackdropStyle get backdropStyle =>
      isTemporal ? RoomBackdropStyle.temporal : RoomBackdropStyle.collision;

  Color get accentColor =>
      isTemporal ? const Color(0xFF9D8CFF) : const Color(0xFF36E1FF);

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
    await add(RoomBackdropComponent(backdropStyle, worldSize: worldSize));
    _buildGeometry();
    await addAll(_surfaces);
    if (isSwordRoute) {
      await add(
        DamagePitComponent(
          position: Vector2(280, _floorY),
          size: Vector2(isTemporal ? 190 : 200, 56),
          style: surfaceStyle,
        ),
      );
    }
    if (isGunRoute && !rewardClaimed) {
      await add(
        RangedRouteSwitchComponent(
          position: Vector2(535, 350),
          routeEntityId: 'environment.${nodeId.name}.rangedRouteSwitch',
          accentColor: accentColor,
          onActivated: _openGunGate,
        ),
      );
    }
    final returnDoor = CampaignDoorComponent(
      position: Vector2(70, _floorY),
      labelLocalizationKey: isTemporal
          ? 'interaction.returnTemporalFracture'
          : 'interaction.returnCollisionFracture',
      accentColor: accentColor,
      onInteract: () =>
          game.travelToCampaignNode(returnNode, entry: CampaignNodeEntry.east),
    );
    _returnDoor = returnDoor;
    await add(returnDoor);
    if (!rewardClaimed) await _spawnReward();
  }

  void _buildGeometry() {
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(0, 0, 24, 540, boundary: true),
      _surface(936, 0, 24, 540, boundary: true),
      if (isSwordRoute) ...<PlatformSurfaceComponent>[
        _surface(0, _floorY, 280, 56),
        _surface(isTemporal ? 470 : 480, _floorY, isTemporal ? 490 : 480, 56),
      ] else if (isGauntletRoute) ...<PlatformSurfaceComponent>[
        _surface(0, _floorY, 960, 56),
        _surface(610, 324, 260, 22),
      ] else ...<PlatformSurfaceComponent>[
        _surface(0, _floorY, 960, 56),
        if (!rewardClaimed) ..._buildGunGate(),
      ],
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
    style: surfaceStyle,
  );

  Future<void> _spawnReward() async {
    final position = isGauntletRoute
        ? Vector2(750, 318)
        : Vector2(790, _floorY - 6);
    final pedestal = ItemPedestalComponent(
      position: position,
      item: rewardItem,
      onCollected: (_) {
        progress.claimedSecretRewardIds.add(nodeId.name);
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
