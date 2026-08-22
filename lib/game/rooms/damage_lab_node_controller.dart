import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_service_components.dart';
import 'package:patch_world/game/components/environment/patch_exit_terminal_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/qa_record_terminal_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/terrain_pulse_node_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_room_status.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

/// One independently loaded room in the connected Damage Lab region.
///
/// Run progress lives in [DamageLabFloorState], allowing players to backtrack,
/// restart, and revisit cleared rooms without rebuilding defeated encounters.
final class DamageLabNodeController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        PlatformerRoomCameraLead,
        PlatformerRoomCameraFollow,
        CampaignNodeRoom,
        DamageLabRoomStatus {
  DamageLabNodeController({
    required this.nodeId,
    required this.entry,
    required this.progress,
  }) : assert(_supportedNodes.contains(nodeId));

  static const Set<CampaignNodeId> _supportedNodes = <CampaignNodeId>{
    CampaignNodeId.damageWorkshop,
    CampaignNodeId.damageAssembly,
    CampaignNodeId.damageOverflow,
    CampaignNodeId.overflowWarden,
  };
  static const double _floorY = 484;
  static const double _expandedRoomWidth = 1920;
  static const double _expandedRoomHeight = 1080;
  static const String _workshopEnvironmentAsset =
      'assets/images/rooms/damage-lab-environment-v3.webp';
  static const String _assemblyEnvironmentAsset =
      'assets/images/rooms/damage-lab-maintenance-v1.webp';
  static const String _overflowEnvironmentAsset =
      'assets/images/rooms/damage-lab-hazard-v1.webp';

  /// Collision geometry traced from the authored 1920x1080 Damage Lab v3
  /// backdrop. Broad central landings form the universal west-to-east route;
  /// upper and lower bands add optional vertical exploration while keeping
  /// the three starting weapons equally capable of reaching the exit.
  static const List<Rect> _workshopBackdropPlatformBounds = <Rect>[
    // Universal central route and the right boundary.
    Rect.fromLTWH(210, 510, 740, 28),
    Rect.fromLTWH(950, 545, 96, 28),
    Rect.fromLTWH(1032, 580, 96, 28),
    Rect.fromLTWH(1128, 545, 96, 28),
    Rect.fromLTWH(1210, 510, 686, 28),
    Rect.fromLTWH(1896, 0, 24, 1080),
    // Upper archive route.
    Rect.fromLTWH(620, 420, 175, 24),
    Rect.fromLTWH(455, 330, 130, 24),
    Rect.fromLTWH(285, 245, 110, 24),
    Rect.fromLTWH(430, 190, 140, 24),
    Rect.fromLTWH(590, 140, 850, 28),
    Rect.fromLTWH(785, 300, 92, 24),
    Rect.fromLTWH(900, 245, 86, 24),
    Rect.fromLTWH(1020, 305, 110, 24),
    Rect.fromLTWH(1150, 360, 110, 24),
    Rect.fromLTWH(1500, 215, 170, 24),
    Rect.fromLTWH(1650, 300, 160, 24),
    Rect.fromLTWH(1730, 385, 166, 24),
    Rect.fromLTWH(1650, 430, 180, 24),
    // Lower maintenance route west of the corruption channel.
    Rect.fromLTWH(420, 600, 140, 24),
    Rect.fromLTWH(280, 690, 140, 24),
    Rect.fromLTWH(140, 780, 140, 24),
    Rect.fromLTWH(80, 870, 140, 24),
    Rect.fromLTWH(260, 930, 140, 24),
    Rect.fromLTWH(40, 990, 700, 90),
    // Central descent and data-channel island.
    Rect.fromLTWH(860, 620, 110, 24),
    Rect.fromLTWH(780, 650, 160, 24),
    Rect.fromLTWH(850, 740, 160, 24),
    Rect.fromLTWH(920, 830, 160, 24),
    Rect.fromLTWH(980, 930, 150, 24),
    Rect.fromLTWH(1060, 990, 100, 24),
    Rect.fromLTWH(980, 1040, 150, 40),
    // Eastern descent to the sealed pre-boss machinery.
    Rect.fromLTWH(1420, 600, 170, 24),
    Rect.fromLTWH(1510, 690, 170, 24),
    Rect.fromLTWH(1450, 780, 180, 24),
    Rect.fromLTWH(1330, 870, 190, 24),
    Rect.fromLTWH(1380, 950, 180, 24),
    Rect.fromLTWH(1280, 1015, 616, 65),
  ];

  /// ROOM 1-2: a weapon-neutral maintenance arch climbs from the west airlock
  /// across the central shaft and descends to the east airlock. The high
  /// gantries and bottom service channel are optional exploration loops.
  static const List<Rect> _assemblyBackdropPlatformBounds = <Rect>[
    // Mid-band airlocks and required ascent/descent route.
    Rect.fromLTWH(40, 565, 500, 30),
    Rect.fromLTWH(500, 490, 180, 24),
    Rect.fromLTWH(660, 415, 260, 28),
    Rect.fromLTWH(900, 490, 180, 24),
    Rect.fromLTWH(1040, 565, 840, 30),
    // Upper lift-control loop.
    Rect.fromLTWH(40, 290, 520, 28),
    Rect.fromLTWH(470, 410, 150, 24),
    Rect.fromLTWH(620, 335, 140, 24),
    Rect.fromLTWH(770, 270, 150, 24),
    Rect.fromLTWH(920, 220, 150, 24),
    Rect.fromLTWH(1070, 270, 150, 24),
    Rect.fromLTWH(1220, 335, 140, 24),
    Rect.fromLTWH(1360, 410, 150, 24),
    Rect.fromLTWH(1510, 290, 370, 28),
    // Lower coolant-service loop and recovery islands.
    Rect.fromLTWH(40, 805, 610, 28),
    Rect.fromLTWH(820, 790, 320, 28),
    Rect.fromLTWH(650, 875, 150, 24),
    Rect.fromLTWH(800, 945, 170, 24),
    Rect.fromLTWH(970, 1005, 170, 24),
    Rect.fromLTWH(1140, 945, 170, 24),
    Rect.fromLTWH(1310, 875, 150, 24),
    Rect.fromLTWH(1460, 805, 420, 28),
    Rect.fromLTWH(40, 1020, 520, 60),
    Rect.fromLTWH(1360, 1020, 520, 60),
    // World boundary authored independently from the artwork.
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  /// ROOM 1-3: the middle laboratory floor is the mandatory boss approach.
  /// The high control gallery and corrupted containment trench are optional,
  /// keeping hazards and weapon rewards away from the universal route.
  static const List<Rect> _overflowBackdropPlatformBounds = <Rect>[
    // Weapon-neutral laboratory floor and pre-boss approach.
    Rect.fromLTWH(40, 650, 500, 30),
    Rect.fromLTWH(540, 650, 850, 30),
    Rect.fromLTWH(1390, 650, 490, 30),
    // Upper observation and control route.
    Rect.fromLTWH(40, 205, 650, 28),
    Rect.fromLTWH(240, 545, 170, 24),
    Rect.fromLTWH(430, 470, 160, 24),
    Rect.fromLTWH(610, 395, 150, 24),
    Rect.fromLTWH(780, 320, 150, 24),
    Rect.fromLTWH(950, 245, 170, 24),
    Rect.fromLTWH(1120, 205, 760, 28),
    Rect.fromLTWH(1300, 395, 170, 24),
    Rect.fromLTWH(1480, 470, 170, 24),
    // Lower containment route with safe islands above the corruption trench.
    Rect.fromLTWH(40, 900, 450, 28),
    Rect.fromLTWH(540, 865, 360, 28),
    Rect.fromLTWH(980, 900, 360, 28),
    Rect.fromLTWH(1450, 850, 430, 28),
    Rect.fromLTWH(460, 1020, 140, 24),
    Rect.fromLTWH(720, 1020, 140, 24),
    Rect.fromLTWH(980, 1020, 140, 24),
    Rect.fromLTWH(1240, 1020, 140, 24),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  final CampaignNodeId nodeId;
  final CampaignNodeEntry entry;
  final DamageLabFloorState progress;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  final Map<PlatformerEnemyComponent, int> _enemyEncounterIds =
      <PlatformerEnemyComponent, int>{};
  final Set<PlatformerEnemyComponent> _defeatedEnemies =
      <PlatformerEnemyComponent>{};
  final List<QaRecordTerminalComponent> _recordTerminals =
      <QaRecordTerminalComponent>[];

  CampaignDoorComponent? _backDoor;
  CampaignDoorComponent? _forwardDoor;
  CampaignDoorComponent? _secretDoor;
  CampaignDoorComponent? _maintenanceShortcutDoor;
  final List<CampaignDoorComponent> _branchDoors = <CampaignDoorComponent>[];
  CampaignCheckpointComponent? _checkpoint;
  CampaignRepairStationComponent? _repairStation;
  LoadoutEventTerminalComponent? _loadoutEvent;
  TerrainPulseNodeComponent? _terrainPulseNode;
  OverflowWardenBossComponent? _boss;
  ItemPedestalComponent? _questReward;
  ItemPedestalComponent? _bossReward;
  PatchExitTerminalComponent? _exitTerminal;
  BossNameCardComponent? _bossBanner;
  BossArenaPresentationComponent? _bossArenaPresentation;
  final List<BossSealGateComponent> _bossSeals = <BossSealGateComponent>[];
  bool _bossEncounterStarted = false;
  bool _patchSelectionOpened = false;
  double _bossIntroRemaining = 0;
  int _defeatedCount = 0;

  int get encounterId => switch (nodeId) {
    CampaignNodeId.damageWorkshop => 0,
    CampaignNodeId.damageAssembly => 1,
    CampaignNodeId.damageOverflow => 2,
    CampaignNodeId.overflowWarden => 3,
    _ => throw StateError('Unsupported Damage Lab node: $nodeId'),
  };

  @override
  CampaignNodeId get campaignNodeId => nodeId;

  bool get usesBackdropAlignedGeometry => switch (nodeId) {
    CampaignNodeId.damageWorkshop ||
    CampaignNodeId.damageAssembly ||
    CampaignNodeId.damageOverflow => true,
    _ => false,
  };

  List<Rect> get backdropAlignedPlatformBounds =>
      List<Rect>.unmodifiable(switch (nodeId) {
        CampaignNodeId.damageWorkshop => _workshopBackdropPlatformBounds,
        CampaignNodeId.damageAssembly => _assemblyBackdropPlatformBounds,
        CampaignNodeId.damageOverflow => _overflowBackdropPlatformBounds,
        _ => const <Rect>[],
      });

  String? get environmentAsset => switch (nodeId) {
    CampaignNodeId.damageWorkshop => _workshopEnvironmentAsset,
    CampaignNodeId.damageAssembly => _assemblyEnvironmentAsset,
    CampaignNodeId.damageOverflow => _overflowEnvironmentAsset,
    _ => null,
  };

  @override
  Vector2 get playerSpawn => switch (nodeId) {
    CampaignNodeId.damageWorkshop =>
      entry == CampaignNodeEntry.west ? Vector2(310, 474) : Vector2(1810, 474),
    CampaignNodeId.damageAssembly =>
      entry == CampaignNodeEntry.west ? Vector2(140, 529) : Vector2(1780, 529),
    CampaignNodeId.damageOverflow =>
      entry == CampaignNodeEntry.west ? Vector2(140, 614) : Vector2(1780, 614),
    _ =>
      entry == CampaignNodeEntry.west ? Vector2(166, 448) : Vector2(794, 448),
  };

  @override
  late final Vector2 worldSize = Vector2(
    usesBackdropAlignedGeometry ? _expandedRoomWidth : 960,
    usesBackdropAlignedGeometry ? _expandedRoomHeight : 540,
  );

  @override
  double get killPlaneY => usesBackdropAlignedGeometry ? 1160 : 620;

  @override
  int get currentCellNumber => encounterId + 1;

  @override
  int get clearedEncounterCount => progress.clearedEncounterCount;

  @override
  int get qaRecordCount => progress.collectedRecordCount;

  @override
  bool get isCompleted => progress.bossDefeated;

  @override
  int? get bossHealth => _bossEncounterStarted ? _boss?.health : null;

  @override
  int? get bossMaxHealth =>
      _bossEncounterStarted ? _boss?.maximumOverflowHealth : null;

  @override
  String? get bossPhaseKey => _bossEncounterStarted ? _boss?.phaseId : null;

  int get defeatedCount => _defeatedCount;
  bool get isBossIntroActive => _bossIntroRemaining > 0;
  OverflowWardenBossComponent? get boss => _boss;
  BossArenaPresentationComponent? get bossArenaPresentation =>
      _bossArenaPresentation;
  List<BossSealGateComponent> get bossSeals =>
      List<BossSealGateComponent>.unmodifiable(_bossSeals);

  List<(PlatformerEnemyArchetype, double, double)> get combatEncounterSpecs =>
      switch (nodeId) {
        CampaignNodeId.damageWorkshop =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.patchMite, 760, 474),
            (PlatformerEnemyArchetype.checksumHopper, 1390, 474),
          ],
        CampaignNodeId.damageAssembly =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.patchMite, 350, 529),
            (PlatformerEnemyArchetype.pulseTurret, 500, 529),
            (PlatformerEnemyArchetype.checksumHopper, 800, 379),
            (PlatformerEnemyArchetype.repairLeech, 1500, 529),
          ],
        CampaignNodeId.damageOverflow =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.pulseTurret, 600, 614),
            (PlatformerEnemyArchetype.repairLeech, 930, 614),
            (PlatformerEnemyArchetype.checksumHopper, 1200, 614),
            (PlatformerEnemyArchetype.patchMite, 1500, 614),
          ],
        _ => const <(PlatformerEnemyArchetype, double, double)>[],
      };

  List<TraversalSegment> get requiredTraversalSegments => switch (nodeId) {
    CampaignNodeId.damageWorkshop => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.workshop.central-dip-a',
        rise: 35,
        gap: 0,
        landingWidth: 96,
      ),
      TraversalSegment(
        id: 'damage.workshop.central-dip-b',
        rise: 35,
        gap: 0,
        landingWidth: 96,
      ),
      TraversalSegment(
        id: 'damage.workshop.central-climb-a',
        rise: 35,
        gap: 0,
        landingWidth: 96,
      ),
      TraversalSegment(
        id: 'damage.workshop.central-climb-b',
        rise: 35,
        gap: 0,
        landingWidth: 686,
      ),
    ],
    CampaignNodeId.damageAssembly => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.assembly.ascent-a',
        rise: 75,
        gap: 0,
        landingWidth: 180,
      ),
      TraversalSegment(
        id: 'damage.assembly.ascent-b',
        rise: 75,
        gap: 0,
        landingWidth: 260,
      ),
      TraversalSegment(
        id: 'damage.assembly.descent-a',
        rise: 75,
        gap: 0,
        landingWidth: 180,
      ),
      TraversalSegment(
        id: 'damage.assembly.descent-b',
        rise: 75,
        gap: 0,
        landingWidth: 840,
      ),
    ],
    CampaignNodeId.damageOverflow => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.overflow.west-laboratory',
        rise: 0,
        gap: 0,
        landingWidth: 500,
      ),
      TraversalSegment(
        id: 'damage.overflow.test-arena',
        rise: 0,
        gap: 0,
        landingWidth: 850,
      ),
      TraversalSegment(
        id: 'damage.overflow.preboss-airlock',
        rise: 0,
        gap: 0,
        landingWidth: 490,
      ),
    ],
    CampaignNodeId.overflowWarden => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.warden.arena-floor',
        rise: 0,
        gap: 0,
        landingWidth: 960,
      ),
    ],
    _ => const <TraversalSegment>[],
  };

  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) {
    final checkpoint = _checkpoint;
    if (checkpoint != null && checkpoint.isActive) {
      return Vector2(checkpoint.position.x, checkpoint.position.y - 36);
    }
    return playerSpawn.clone();
  }

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) {
    if (isBossIntroActive) return Vector2(585, 250);
    final boss = _boss;
    if (_bossEncounterStarted && boss != null && boss.isActive) {
      return Vector2(playerPosition.x * .58 + boss.position.x * .42, 270);
    }
    return usesBackdropAlignedGeometry
        ? Vector2(playerPosition.x, playerPosition.y - 68)
        : Vector2(480, 270);
  }

  @override
  double cameraZoomFor(Vector2 playerPosition) {
    if (isBossIntroActive) return 1.32;
    if (_bossEncounterStarted && (_boss?.isActive ?? false)) return 1.08;
    return usesBackdropAlignedGeometry ? .92 : 1;
  }

  @override
  double get horizontalCameraLead => usesBackdropAlignedGeometry ? 96 : 0;

  @override
  double get horizontalCameraDeadZone => usesBackdropAlignedGeometry ? 112 : 0;

  @override
  double get verticalCameraDeadZone => usesBackdropAlignedGeometry ? 58 : 0;

  @override
  double get cameraFollowResponsiveness =>
      usesBackdropAlignedGeometry ? 5.2 : 1000;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(
        RoomBackdropStyle.damage,
        worldSize: worldSize,
        environmentAsset: environmentAsset,
      ),
    );
    _buildGeometry();
    await addAll(_surfaces);
    await _addRoomFeatures();
    await _addTerrainPulseRoute();
    await _addServiceRoomFeatures();
    if (nodeId == CampaignNodeId.damageWorkshop ||
        nodeId == CampaignNodeId.damageAssembly) {
      final checkpointPosition = nodeId == CampaignNodeId.damageWorkshop
          ? Vector2(330, 510)
          : Vector2(1510, 565);
      final checkpoint = CampaignCheckpointComponent(
        position: checkpointPosition,
        isActive: game.campaignExploration.checkpointNodeId == campaignNodeId,
        onActivated: () => game.activateCampaignCheckpoint(campaignNodeId),
      );
      _checkpoint = checkpoint;
      await add(checkpoint);
    }
    if (nodeId == CampaignNodeId.overflowWarden) {
      await _addBossEncounter();
    } else {
      await _addCombatEncounter();
      await _addQaRecord();
      if (nodeId == CampaignNodeId.damageOverflow &&
          progress.questComplete &&
          !progress.questRewardClaimed) {
        await _spawnQuestReward();
      }
    }
    await _spawnAvailableDoors();
  }

  void _buildGeometry() {
    _surfaces.addAll(<PlatformSurfaceComponent>[
      _surface(
        0,
        0,
        24,
        usesBackdropAlignedGeometry ? _expandedRoomHeight : 540,
        boundary: true,
      ),
      if (!usesBackdropAlignedGeometry)
        _surface(936, 0, 24, 540, boundary: true),
      ...switch (nodeId) {
        CampaignNodeId.damageWorkshop ||
        CampaignNodeId.damageAssembly ||
        CampaignNodeId.damageOverflow =>
          backdropAlignedPlatformBounds
              .map(
                (bounds) => _surface(
                  bounds.left,
                  bounds.top,
                  bounds.width,
                  bounds.height,
                  boundary: bounds.left == 1896,
                  renderArtwork: false,
                ),
              )
              .toList(growable: false),
        CampaignNodeId.overflowWarden => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 960, 56),
          _surface(150, 396, 160, 20),
          _surface(650, 396, 160, 20),
        ],
        _ => <PlatformSurfaceComponent>[],
      },
    ]);
  }

  PlatformSurfaceComponent _surface(
    double x,
    double y,
    double width,
    double height, {
    bool boundary = false,
    bool renderArtwork = true,
  }) => PlatformSurfaceComponent(
    position: Vector2(x, y),
    size: Vector2(width, height),
    isBoundary: boundary,
    style: PlatformSurfaceStyle.damage,
    renderArtwork: renderArtwork,
  );

  Future<void> _addRoomFeatures() async {
    final features = <Component>[];
    switch (nodeId) {
      case CampaignNodeId.damageWorkshop:
        // The authored backdrop already contains the Workshop's terrain and
        // hazard language. Falling between its traced platforms uses the room
        // kill plane instead of drawing a second, conflicting set of assets.
        break;
      case CampaignNodeId.damageAssembly:
        features.addAll(<Component>[
          JumpPadComponent(position: Vector2(490, 553)),
          JumpPadComponent(position: Vector2(1375, 553)),
        ]);
      case CampaignNodeId.damageOverflow:
        features.addAll(<Component>[
          PulsingLaserComponent(
            position: Vector2(860, 390),
            size: Vector2(12, 260),
            sourceId: 'hazard.damage-lab.overflow.laser-west',
            phaseOffset: 0,
          ),
          PulsingLaserComponent(
            position: Vector2(1040, 390),
            size: Vector2(12, 260),
            sourceId: 'hazard.damage-lab.overflow.laser-center',
            phaseOffset: .8,
          ),
          PulsingLaserComponent(
            position: Vector2(1220, 390),
            size: Vector2(12, 260),
            sourceId: 'hazard.damage-lab.overflow.laser-east',
            phaseOffset: 1.6,
          ),
          RoomHazardComponent(
            position: Vector2(600, 1040),
            size: Vector2(120, 20),
            style: RoomHazardStyle.spikes,
            sourceId: 'hazard.damage-lab.overflow.trench-west',
          ),
          RoomHazardComponent(
            position: Vector2(860, 1040),
            size: Vector2(120, 20),
            style: RoomHazardStyle.spikes,
            sourceId: 'hazard.damage-lab.overflow.trench-center',
          ),
          RoomHazardComponent(
            position: Vector2(1120, 1040),
            size: Vector2(120, 20),
            style: RoomHazardStyle.spikes,
            sourceId: 'hazard.damage-lab.overflow.trench-east',
          ),
        ]);
      case CampaignNodeId.overflowWarden:
        break;
      default:
        break;
    }
    await addAll(features);
  }

  Future<void> _addCombatEncounter() async {
    if (progress.clearedEncounterIds.contains(encounterId)) return;
    for (final spec in combatEncounterSpecs) {
      late final PlatformerEnemyComponent enemy;
      enemy = PlatformerEnemyComponent(
        archetype: spec.$1,
        position: Vector2(spec.$2, spec.$3),
        onDefeated: _onEnemyDefeated,
      );
      _enemyEncounterIds[enemy] = encounterId;
      await add(enemy);
    }
  }

  Future<void> _addTerrainPulseRoute() async {
    if (nodeId != CampaignNodeId.damageAssembly) return;
    const routeId = 'terrain.damage-assembly.upper-bypass';
    final bridge = TerrainPulseBridgeComponent(
      position: Vector2(1110, 408),
      size: Vector2(190, 20),
      style: PlatformSurfaceStyle.damage,
    );
    final node = TerrainPulseNodeComponent(
      position: Vector2(1010, 553),
      nodeId: routeId,
      onActivated: bridge.activate,
      accentColor: const Color(0xFF36E1FF),
    );
    _surfaces.add(bridge);
    _terrainPulseNode = node;
    await addAll(<Component>[bridge, node]);
    if (game.campaignExploration.activatedTerrainNodeIds.contains(routeId)) {
      node.restoreActivated();
    }
  }

  Future<void> _addServiceRoomFeatures() async {
    if (nodeId == CampaignNodeId.damageWorkshop) {
      final station = CampaignRepairStationComponent(
        position: Vector2(560, 510),
        used: progress.repairStationUsed,
        onUsed: () => progress.repairStationUsed = true,
        accentColor: const Color(0xFF36E1FF),
      );
      _repairStation = station;
      await add(station);
    }
    if (nodeId == CampaignNodeId.damageOverflow) {
      final terminal = LoadoutEventTerminalComponent(
        position: Vector2(1500, 900),
        resolved: progress.loadoutEventResolved,
        rewardFor: (weapon) => switch (weapon) {
          PlayerWeapon.sword => RunItemId.vectorEdge,
          PlayerWeapon.gauntlet => RunItemId.impactLattice,
          PlayerWeapon.gun => RunItemId.splitChamber,
        },
        onResolved: () => progress.loadoutEventResolved = true,
        accentColor: const Color(0xFFFF4FD8),
      );
      _loadoutEvent = terminal;
      await add(terminal);
    }
  }

  Future<void> _addQaRecord() async {
    if (progress.collectedRecordIds.contains(encounterId)) return;
    final x = switch (nodeId) {
      CampaignNodeId.damageWorkshop => 1580.0,
      CampaignNodeId.damageAssembly => 980.0,
      CampaignNodeId.damageOverflow => 1510.0,
      _ => 480.0,
    };
    final y = switch (nodeId) {
      CampaignNodeId.damageWorkshop => 504.0,
      CampaignNodeId.damageAssembly => 784.0,
      CampaignNodeId.damageOverflow => 644.0,
      _ => _floorY - 6,
    };
    final terminal = QaRecordTerminalComponent(
      position: Vector2(x, y),
      recordId: encounterId,
      onCollected: _onRecordCollected,
    );
    _recordTerminals.add(terminal);
    await add(terminal);
  }

  Future<void> _addBossEncounter() async {
    final arenaPresentation = BossArenaPresentationComponent(
      size: worldSize.clone(),
      accentColor: const Color(0xFFFFD35A),
      initiallyCleared: progress.bossDefeated,
    );
    _bossArenaPresentation = arenaPresentation;
    await add(arenaPresentation);
    if (!progress.bossDefeated) {
      final seals = <BossSealGateComponent>[
        BossSealGateComponent(
          position: Vector2(96, 172),
          size: Vector2(18, 312),
          style: PlatformSurfaceStyle.damage,
        ),
        BossSealGateComponent(
          position: Vector2(846, 172),
          size: Vector2(18, 312),
          style: PlatformSurfaceStyle.damage,
        ),
      ];
      _bossSeals.addAll(seals);
      _surfaces.addAll(seals);
      await addAll(seals);
      final boss = OverflowWardenBossComponent(
        position: Vector2(620, _floorY - 56),
        arenaFloorY: _floorY,
        onDefeated: _onBossDefeated,
        onPhaseChanged: _onBossPhaseChanged,
      );
      _boss = boss;
      await add(boss);
      return;
    }
    if (!progress.bossRewardClaimed) await _spawnBossReward();
    await _spawnExitTerminal();
  }

  Future<void> _spawnAvailableDoors() async {
    if (nodeId != CampaignNodeId.overflowWarden || progress.bossDefeated) {
      await _spawnBackDoor();
    }
    if (nodeId != CampaignNodeId.overflowWarden &&
        progress.clearedEncounterIds.contains(encounterId)) {
      await _spawnForwardDoor();
    }
    if (nodeId == CampaignNodeId.damageAssembly &&
        progress.clearedEncounterIds.contains(encounterId)) {
      await _spawnSecretDoor();
    }
    if ((nodeId == CampaignNodeId.damageWorkshop ||
            nodeId == CampaignNodeId.damageOverflow) &&
        game.campaignExploration.unlockedShortcutIds.contains(
          CampaignWorldGraph.damageMaintenanceShortcutId,
        )) {
      await _spawnMaintenanceShortcutDoor();
    }
    if (nodeId == CampaignNodeId.overflowWarden &&
        progress.bossDefeated &&
        progress.patchApplied) {
      await _spawnRegionBranchDoors();
    }
  }

  Future<void> _spawnBackDoor() async {
    if (_backDoor != null) return;
    final target = switch (nodeId) {
      CampaignNodeId.damageWorkshop => CampaignNodeId.bootSector,
      CampaignNodeId.damageAssembly => CampaignNodeId.damageWorkshop,
      CampaignNodeId.damageOverflow => CampaignNodeId.damageAssembly,
      CampaignNodeId.overflowWarden => CampaignNodeId.damageOverflow,
      _ => throw StateError('Unsupported Damage Lab node: $nodeId'),
    };
    final key = nodeId == CampaignNodeId.damageWorkshop
        ? 'interaction.returnBootSector'
        : 'interaction.previousRoom';
    final door = CampaignDoorComponent(
      position: switch (nodeId) {
        CampaignNodeId.damageWorkshop => Vector2(105, 510),
        CampaignNodeId.damageAssembly => Vector2(105, 565),
        CampaignNodeId.damageOverflow => Vector2(105, 650),
        _ => Vector2(70, _floorY),
      },
      labelLocalizationKey: key,
      accentColor: const Color(0xFF9D8CFF),
      onInteract: () =>
          game.travelToCampaignNode(target, entry: CampaignNodeEntry.east),
    );
    _backDoor = door;
    await add(door);
  }

  Future<void> _spawnForwardDoor() async {
    if (_forwardDoor != null || nodeId == CampaignNodeId.overflowWarden) {
      return;
    }
    final target = switch (nodeId) {
      CampaignNodeId.damageWorkshop => CampaignNodeId.damageAssembly,
      CampaignNodeId.damageAssembly => CampaignNodeId.damageOverflow,
      CampaignNodeId.damageOverflow => CampaignNodeId.overflowWarden,
      _ => throw StateError('Unsupported Damage Lab node: $nodeId'),
    };
    final door = CampaignDoorComponent(
      position: switch (nodeId) {
        CampaignNodeId.damageWorkshop => Vector2(1820, 510),
        CampaignNodeId.damageAssembly => Vector2(1815, 565),
        CampaignNodeId.damageOverflow => Vector2(1815, 650),
        _ => Vector2(890, _floorY),
      },
      labelLocalizationKey: nodeId == CampaignNodeId.damageOverflow
          ? 'interaction.enterBossRoom'
          : 'interaction.nextRoom',
      onInteract: () =>
          game.travelToCampaignNode(target, entry: CampaignNodeEntry.west),
    );
    _forwardDoor = door;
    await add(door);
  }

  Future<void> _spawnSecretDoor() async {
    if (_secretDoor != null) return;
    final weapon = game.world.player.selectedWeapon;
    final (target, position, labelKey) = switch (weapon) {
      PlayerWeapon.sword => (
        CampaignNodeId.damageDashCache,
        Vector2(600, 805),
        'interaction.enterDashCache',
      ),
      PlayerWeapon.gauntlet => (
        CampaignNodeId.damageUpperArchive,
        Vector2(995, 220),
        'interaction.enterUpperArchive',
      ),
      PlayerWeapon.gun => (
        CampaignNodeId.damageTurretControl,
        Vector2(1530, 805),
        'interaction.enterTurretControl',
      ),
    };
    final door = CampaignDoorComponent(
      position: position,
      labelLocalizationKey: labelKey,
      accentColor: const Color(0xFFFFD35A),
      onInteract: () =>
          game.travelToCampaignNode(target, entry: CampaignNodeEntry.west),
    );
    _secretDoor = door;
    await add(door);
  }

  Future<void> _spawnMaintenanceShortcutDoor() async {
    if (_maintenanceShortcutDoor != null) return;
    final target = switch (nodeId) {
      CampaignNodeId.damageWorkshop => CampaignNodeId.damageOverflow,
      CampaignNodeId.damageOverflow => CampaignNodeId.damageWorkshop,
      _ => throw StateError('Maintenance shortcut is outside ROOM 1.'),
    };
    final position = switch (nodeId) {
      CampaignNodeId.damageWorkshop => Vector2(1540, 1015),
      CampaignNodeId.damageOverflow => Vector2(260, 900),
      _ => Vector2.zero(),
    };
    final door = CampaignDoorComponent(
      position: position,
      labelLocalizationKey: 'interaction.useMaintenanceShortcut',
      accentColor: const Color(0xFF45F3A6),
      onInteract: () =>
          game.travelToCampaignNode(target, entry: CampaignNodeEntry.east),
    );
    _maintenanceShortcutDoor = door;
    await add(door);
  }

  Future<void> _spawnRegionBranchDoors() async {
    if (_branchDoors.isNotEmpty) return;
    final temporalDoor = CampaignDoorComponent(
      position: Vector2(250, _floorY),
      labelLocalizationKey: 'interaction.enterTemporalHall',
      accentColor: const Color(0xFF9D8CFF),
      onInteract: () => game.travelToCampaignNode(
        CampaignNodeId.temporalAscent,
        entry: CampaignNodeEntry.west,
      ),
    );
    _branchDoors.addAll(<CampaignDoorComponent>[temporalDoor]);
    await addAll(_branchDoors);
  }

  void _onEnemyDefeated(PlatformerEnemyComponent enemy) {
    if (!_defeatedEnemies.add(enemy)) return;
    _defeatedCount += 1;
    game.runMetrics.recordOverflow();
    if (_enemyEncounterIds.keys.every(_defeatedEnemies.contains)) {
      progress.clearedEncounterIds.add(encounterId);
      if (nodeId == CampaignNodeId.damageOverflow) {
        game.campaignExploration.unlockShortcut(
          CampaignWorldGraph.damageMaintenanceShortcutId,
        );
        unawaited(_spawnMaintenanceShortcutDoor());
      }
      if (game.runItems.contains(RunItemId.conduitHeart)) {
        game.world.player.restoreIntegrity(1);
      }
      unawaited(_spawnForwardDoor());
      if (!progress.claimedBuildRewardIds.contains(encounterId)) {
        unawaited(
          Future<void>.microtask(
            () => game.openRoomOneBuildSelection(encounterId),
          ),
        );
      }
    }
    game.publishUiSnapshot(force: true);
  }

  void _onRecordCollected(int recordId) {
    progress.collectedRecordIds.add(recordId);
    _recordTerminals.removeWhere((terminal) => terminal.recordId == recordId);
    game.world.player.absorbDataShard(amount: 2);
    if (nodeId == CampaignNodeId.damageOverflow &&
        progress.questComplete &&
        !progress.questRewardClaimed) {
      unawaited(_spawnQuestReward());
    }
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnQuestReward() async {
    if (_questReward != null || progress.questRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: Vector2(1580, 844),
      item: RunItemId.conduitHeart,
      rewardTier: ItemRewardTier.quest,
      onCollected: (_) {
        progress.questRewardClaimed = true;
        _questReward = null;
      },
    );
    _questReward = reward;
    await add(reward);
  }

  void _startBossIntro() {
    final boss = _boss;
    if (_bossEncounterStarted || boss == null) return;
    _bossEncounterStarted = true;
    _bossIntroRemaining = 2.8;
    boss.beginIntro();
    _bossArenaPresentation?.beginIntro();
    game.setCinematicInputLocked(true);
    final banner = BossNameCardComponent(
      center: Vector2(480, 145),
      title: game.localization.text('enemy.overflowWarden.name'),
      subtitle: game.localization.text('boss.overflowWarden.intro'),
      accentColor: const Color(0xFFFFD35A),
    );
    _bossBanner = banner;
    add(banner);
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  void _onBossDefeated() {
    progress.bossDefeated = true;
    _boss = null;
    game.runMetrics.recordOverflow();
    game.campaignExploration.collectCoreSignature(CampaignRegion.damageLab);
    _bossArenaPresentation?.markCleared();
    for (final seal in _bossSeals) {
      seal.unlock();
    }
    unawaited(_showCoreSignatureCard());
    unawaited(_spawnBackDoor());
    unawaited(_spawnBossReward());
    unawaited(_spawnExitTerminal());
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnBossReward() async {
    if (_bossReward != null || progress.bossRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: Vector2(700, _floorY - 6),
      item: RunItemId.overflowCapacitor,
      rewardTier: ItemRewardTier.boss,
      onCollected: (_) {
        progress.bossRewardClaimed = true;
        _bossReward = null;
      },
    );
    _bossReward = reward;
    await add(reward);
  }

  Future<void> _showCoreSignatureCard() async {
    await add(
      BossNameCardComponent(
        center: Vector2(480, 145),
        title: game.localization.text('boss.coreSignatureAcquired'),
        subtitle:
            '${game.localization.text('room.damageLab')} // '
            '${game.localization.text('ability.wallJump.name')} // '
            '${game.localization.text('boss.optimizerGateUpdated')}',
        accentColor: const Color(0xFF45F3A6),
        style: BossNameCardStyle.victory,
        duration: 3.4,
      ),
    );
  }

  void _onBossPhaseChanged(OverflowWardenPhase phase) {
    switch (phase) {
      case OverflowWardenPhase.dormant:
        break;
      case OverflowWardenPhase.intro:
        _bossArenaPresentation?.beginIntro();
      case OverflowWardenPhase.shielded:
        _bossArenaPresentation?.beginPhaseOne();
      case OverflowWardenPhase.breached:
        _bossArenaPresentation?.beginPhaseTwo();
      case OverflowWardenPhase.critical || OverflowWardenPhase.overflowing:
        _bossArenaPresentation?.beginPhaseThree();
      case OverflowWardenPhase.defeated:
        _bossArenaPresentation?.markCleared();
    }
  }

  Future<void> _spawnExitTerminal() async {
    if (_exitTerminal != null) return;
    final terminal = PatchExitTerminalComponent(
      position: Vector2(850, _floorY - 6),
      accentColor: const Color(0xFFFFD35A),
    );
    _exitTerminal = terminal;
    await add(terminal);
  }

  bool tryInteract(PlayerComponent player) {
    if (_checkpoint?.tryActivate(player) ?? false) return true;
    if (_repairStation?.tryUse(player) ?? false) return true;
    if (_loadoutEvent?.tryResolve(player) ?? false) return true;
    if (_terrainPulseNode?.tryActivate(player) ?? false) return true;
    if (_backDoor?.tryEnter(player) ?? false) return true;
    if (_secretDoor?.tryEnter(player) ?? false) return true;
    if (_maintenanceShortcutDoor?.tryEnter(player) ?? false) return true;
    if (_forwardDoor?.tryEnter(player) ?? false) return true;
    for (final door in _branchDoors) {
      if (door.tryEnter(player)) return true;
    }
    for (final terminal in _recordTerminals.toList()) {
      if (terminal.tryCollect(player)) return true;
    }
    if (_questReward?.tryCollect(player) ?? false) return true;
    if (_bossReward?.tryCollect(player) ?? false) return true;
    final exit = _exitTerminal;
    if (exit == null || !exit.isNear(player)) return false;
    if (!progress.bossRewardClaimed || _patchSelectionOpened) return true;
    _patchSelectionOpened = true;
    game.openRoomOnePatchSelection();
    return true;
  }

  @override
  void update(double dt) {
    if (game.world.isReady &&
        nodeId == CampaignNodeId.overflowWarden &&
        !progress.bossDefeated) {
      _startBossIntro();
    }
    if (_bossIntroRemaining > 0) {
      _bossIntroRemaining = math.max(
        0,
        _bossIntroRemaining - game.clock.simulationDt,
      );
      if (_bossIntroRemaining <= 0) {
        _bossBanner?.removeFromParent();
        _bossBanner = null;
        game.setCinematicInputLocked(false);
        _boss?.activate();
      }
    }
    super.update(dt);
  }

  @override
  void onRemove() {
    game.setCinematicInputLocked(false);
    super.onRemove();
  }
}
