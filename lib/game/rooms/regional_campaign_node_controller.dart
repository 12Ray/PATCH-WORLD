import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
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
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

/// Connected campaign scene used by Temporal Hall and Collision Archive.
///
/// Both regions' three exploration rooms use authored 1920x1080 geometry.
/// Their boss arenas retain the tighter 960x540 cinematic contract.
final class RegionalCampaignNodeController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        PlatformerRoomCameraLead,
        PlatformerRoomCameraFollow,
        CampaignNodeRoom {
  RegionalCampaignNodeController({
    required this.nodeId,
    required this.entry,
    required this.progress,
  }) : assert(_supportedNodes.contains(nodeId));

  static const double _floorY = 484;
  static const double _expandedRoomWidth = 1920;
  static const double _expandedRoomHeight = 1080;
  static const String _temporalAscentEnvironmentAsset =
      'assets/images/rooms/temporal-ascent-v1.webp';
  static const String _temporalFractureEnvironmentAsset =
      'assets/images/rooms/temporal-fracture-v1.webp';
  static const String _temporalPendulumEnvironmentAsset =
      'assets/images/rooms/temporal-pendulum-v1.webp';
  static const String _collisionCompressionEnvironmentAsset =
      'assets/images/rooms/collision-compression-v1.webp';
  static const String _collisionFractureEnvironmentAsset =
      'assets/images/rooms/collision-fracture-v1.webp';
  static const String _collisionMergeEnvironmentAsset =
      'assets/images/rooms/collision-merge-v1.webp';

  /// ROOM 2-1: the mandatory route rises in 75px steps from the lower-west
  /// airlock to the upper-east airlock. The high gallery and maintenance
  /// floor are optional loops traced from the authored background.
  static const List<Rect> _temporalAscentPlatformBounds = <Rect>[
    Rect.fromLTWH(40, 900, 400, 28),
    Rect.fromLTWH(390, 825, 230, 24),
    Rect.fromLTWH(570, 750, 230, 24),
    Rect.fromLTWH(750, 675, 230, 24),
    Rect.fromLTWH(930, 600, 230, 24),
    Rect.fromLTWH(1110, 525, 230, 24),
    Rect.fromLTWH(1290, 450, 230, 24),
    Rect.fromLTWH(1470, 375, 230, 24),
    Rect.fromLTWH(1620, 300, 260, 24),
    Rect.fromLTWH(1600, 230, 280, 28),
    // Upper observation gallery.
    Rect.fromLTWH(40, 230, 500, 28),
    Rect.fromLTWH(520, 300, 150, 24),
    Rect.fromLTWH(680, 375, 150, 24),
    Rect.fromLTWH(840, 300, 150, 24),
    Rect.fromLTWH(1000, 225, 260, 28),
    // Lower maintenance loop and recovery stairs.
    Rect.fromLTWH(360, 960, 180, 24),
    Rect.fromLTWH(500, 1020, 520, 60),
    Rect.fromLTWH(1120, 980, 260, 28),
    Rect.fromLTWH(1460, 940, 420, 40),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  /// ROOM 2-2: a stable lower-middle zigzag crosses the time fracture. The
  /// suspended upper route and lower record pocket are deliberately optional.
  static const List<Rect> _temporalFracturePlatformBounds = <Rect>[
    Rect.fromLTWH(40, 750, 450, 28),
    Rect.fromLTWH(440, 675, 220, 24),
    Rect.fromLTWH(610, 600, 220, 24),
    Rect.fromLTWH(780, 525, 220, 24),
    Rect.fromLTWH(950, 600, 220, 24),
    Rect.fromLTWH(1120, 525, 220, 24),
    Rect.fromLTWH(1290, 500, 250, 24),
    Rect.fromLTWH(1460, 425, 420, 28),
    // Fractured upper timeline.
    Rect.fromLTWH(40, 190, 280, 28),
    Rect.fromLTWH(300, 285, 160, 24),
    Rect.fromLTWH(470, 360, 160, 24),
    Rect.fromLTWH(640, 285, 150, 24),
    Rect.fromLTWH(1130, 270, 150, 24),
    Rect.fromLTWH(1280, 210, 180, 24),
    Rect.fromLTWH(1440, 160, 440, 28),
    // Secret record pocket, with a reversible static staircase.
    Rect.fromLTWH(360, 825, 180, 24),
    Rect.fromLTWH(250, 900, 180, 24),
    Rect.fromLTWH(40, 980, 520, 60),
    Rect.fromLTWH(700, 900, 260, 28),
    Rect.fromLTWH(1180, 900, 300, 28),
    Rect.fromLTWH(1500, 980, 380, 60),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  /// ROOM 2-3: the safe exterior stairs skirt the pendulum. The central
  /// machinery, upper gallery, and deep service loop are optional risks.
  static const List<Rect> _temporalPendulumPlatformBounds = <Rect>[
    Rect.fromLTWH(40, 700, 400, 28),
    Rect.fromLTWH(390, 625, 220, 24),
    Rect.fromLTWH(560, 550, 220, 24),
    Rect.fromLTWH(730, 475, 220, 24),
    Rect.fromLTWH(900, 550, 220, 24),
    Rect.fromLTWH(1080, 475, 220, 24),
    Rect.fromLTWH(1260, 400, 220, 24),
    Rect.fromLTWH(1440, 325, 440, 28),
    // Pendulum observation gallery.
    Rect.fromLTWH(350, 225, 540, 28),
    Rect.fromLTWH(1030, 225, 500, 28),
    Rect.fromLTWH(1530, 290, 350, 28),
    // Deep maintenance loop.
    Rect.fromLTWH(40, 900, 480, 40),
    Rect.fromLTWH(500, 980, 360, 60),
    Rect.fromLTWH(910, 900, 320, 28),
    Rect.fromLTWH(1260, 980, 620, 60),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  /// ROOM 3-1: a static staircase passes outside the compression machinery;
  /// conveyors and pistons form optional shortcuts instead of progress gates.
  static const List<Rect> _collisionCompressionPlatformBounds = <Rect>[
    Rect.fromLTWH(40, 980, 420, 40),
    Rect.fromLTWH(390, 905, 220, 24),
    Rect.fromLTWH(560, 830, 220, 24),
    Rect.fromLTWH(730, 755, 220, 24),
    Rect.fromLTWH(900, 680, 220, 24),
    Rect.fromLTWH(1070, 605, 220, 24),
    Rect.fromLTWH(1240, 530, 220, 24),
    Rect.fromLTWH(1410, 550, 470, 28),
    // High compression audit gallery.
    Rect.fromLTWH(40, 280, 360, 28),
    Rect.fromLTWH(350, 360, 180, 24),
    Rect.fromLTWH(510, 435, 200, 24),
    Rect.fromLTWH(650, 225, 680, 28),
    Rect.fromLTWH(1260, 320, 180, 24),
    Rect.fromLTWH(1430, 245, 450, 28),
    // Rollback cache loop.
    Rect.fromLTWH(40, 1040, 520, 40),
    Rect.fromLTWH(650, 990, 260, 28),
    Rect.fromLTWH(1050, 970, 300, 28),
    Rect.fromLTWH(1500, 1000, 380, 40),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  /// ROOM 3-2: the mandatory route skirts the fracture on broad shelves. The
  /// central bridge fragments and phase-shifted platforms remain optional.
  static const List<Rect> _collisionFracturePlatformBounds = <Rect>[
    Rect.fromLTWH(40, 980, 320, 40),
    Rect.fromLTWH(300, 905, 210, 24),
    Rect.fromLTWH(460, 830, 210, 24),
    Rect.fromLTWH(620, 755, 210, 24),
    Rect.fromLTWH(780, 680, 210, 24),
    Rect.fromLTWH(940, 605, 210, 24),
    Rect.fromLTWH(1100, 530, 210, 24),
    Rect.fromLTWH(1260, 455, 210, 24),
    Rect.fromLTWH(1420, 380, 210, 24),
    Rect.fromLTWH(1580, 305, 300, 24),
    Rect.fromLTWH(1680, 250, 200, 28),
    // High audit balcony and fracture fragments.
    Rect.fromLTWH(40, 405, 300, 28),
    Rect.fromLTWH(280, 320, 200, 24),
    Rect.fromLTWH(480, 285, 220, 24),
    Rect.fromLTWH(760, 210, 150, 24),
    Rect.fromLTWH(1010, 280, 150, 24),
    Rect.fromLTWH(1260, 210, 180, 24),
    Rect.fromLTWH(1450, 160, 430, 28),
    // Lower rollback vault and return steps.
    Rect.fromLTWH(40, 1040, 520, 40),
    Rect.fromLTWH(590, 970, 240, 28),
    Rect.fromLTWH(900, 900, 280, 28),
    Rect.fromLTWH(1300, 970, 300, 28),
    Rect.fromLTWH(1600, 1040, 280, 40),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];

  /// ROOM 3-3: two broad exterior branches reconverge around the merge core.
  /// The periodically merging bridge is an optional high-risk center line.
  static const List<Rect> _collisionMergePlatformBounds = <Rect>[
    Rect.fromLTWH(40, 980, 420, 40),
    Rect.fromLTWH(390, 905, 220, 24),
    Rect.fromLTWH(560, 830, 220, 24),
    Rect.fromLTWH(730, 755, 220, 24),
    Rect.fromLTWH(900, 680, 220, 24),
    Rect.fromLTWH(1070, 605, 220, 24),
    Rect.fromLTWH(1240, 530, 220, 24),
    Rect.fromLTWH(1410, 455, 220, 24),
    Rect.fromLTWH(1570, 380, 310, 24),
    Rect.fromLTWH(1650, 305, 230, 24),
    Rect.fromLTWH(1600, 230, 280, 28),
    // Upper control branches.
    Rect.fromLTWH(40, 230, 320, 28),
    Rect.fromLTWH(360, 345, 250, 24),
    Rect.fromLTWH(520, 255, 250, 24),
    Rect.fromLTWH(760, 195, 390, 28),
    Rect.fromLTWH(1120, 255, 260, 24),
    Rect.fromLTWH(1380, 220, 500, 28),
    // Deep service and rollback loop.
    Rect.fromLTWH(40, 1040, 540, 40),
    Rect.fromLTWH(650, 990, 300, 28),
    Rect.fromLTWH(1000, 920, 300, 28),
    Rect.fromLTWH(1380, 990, 500, 40),
    Rect.fromLTWH(1896, 0, 24, 1080),
  ];
  static const Set<CampaignNodeId> _supportedNodes = <CampaignNodeId>{
    CampaignNodeId.temporalAscent,
    CampaignNodeId.temporalFracture,
    CampaignNodeId.temporalPendulum,
    CampaignNodeId.chronoJailer,
    CampaignNodeId.collisionCompression,
    CampaignNodeId.collisionFracture,
    CampaignNodeId.collisionMerge,
    CampaignNodeId.kernelChimera,
  };

  final CampaignNodeId nodeId;
  final CampaignNodeEntry entry;
  final CampaignFloorState progress;
  final List<PlatformSurfaceComponent> _surfaces = <PlatformSurfaceComponent>[];
  final Map<PlatformerEnemyComponent, int> _enemyEncounterIds =
      <PlatformerEnemyComponent, int>{};
  final Set<PlatformerEnemyComponent> _defeatedEnemies =
      <PlatformerEnemyComponent>{};
  final List<QaRecordTerminalComponent> _recordTerminals =
      <QaRecordTerminalComponent>[];
  final Map<CampaignNodeId, CampaignDoorComponent> _doors =
      <CampaignNodeId, CampaignDoorComponent>{};

  CampaignCheckpointComponent? _checkpoint;
  CampaignRepairStationComponent? _repairStation;
  LoadoutEventTerminalComponent? _loadoutEvent;
  TerrainPulseNodeComponent? _terrainPulseNode;
  CampaignChapterBossComponent? _boss;
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

  bool get isTemporal => switch (nodeId) {
    CampaignNodeId.temporalAscent ||
    CampaignNodeId.temporalFracture ||
    CampaignNodeId.temporalPendulum ||
    CampaignNodeId.chronoJailer => true,
    _ => false,
  };

  CampaignRegion get region => isTemporal
      ? CampaignRegion.temporalHall
      : CampaignRegion.collisionArchive;

  PlatformSurfaceStyle get surfaceStyle => isTemporal
      ? PlatformSurfaceStyle.temporal
      : PlatformSurfaceStyle.collision;

  RoomBackdropStyle get backdropStyle =>
      isTemporal ? RoomBackdropStyle.temporal : RoomBackdropStyle.collision;

  CampaignChapterBossKind get bossKind => isTemporal
      ? CampaignChapterBossKind.chronoJailer
      : CampaignChapterBossKind.kernelChimera;

  Color get accentColor =>
      isTemporal ? const Color(0xFF9D8CFF) : const Color(0xFF36E1FF);

  RunItemId get questRewardItem =>
      isTemporal ? RunItemId.echoClock : RunItemId.vectorBoots;

  RunItemId get bossRewardItem =>
      isTemporal ? RunItemId.temporalRelay : RunItemId.collisionPrism;

  String get recordLocalizationKey =>
      isTemporal ? 'quest.timeFragment' : 'quest.mergeLog';

  String get bossIntroLocalizationKey =>
      isTemporal ? 'boss.chronoJailer.intro' : 'boss.kernelChimera.intro';

  int get encounterId => switch (nodeId) {
    CampaignNodeId.temporalAscent || CampaignNodeId.collisionCompression => 0,
    CampaignNodeId.temporalFracture || CampaignNodeId.collisionFracture => 1,
    CampaignNodeId.temporalPendulum || CampaignNodeId.collisionMerge => 2,
    CampaignNodeId.chronoJailer || CampaignNodeId.kernelChimera => 3,
    _ => throw StateError('Unsupported regional node: $nodeId'),
  };

  bool get isBossRoom => encounterId == 3;
  int get currentCellNumber => encounterId + 1;
  int get clearedEncounterCount => progress.clearedEncounterCount;
  int get recordCount => progress.collectedRecordCount;
  int get defeatedCount => _defeatedCount;
  bool get isCompleted => progress.bossDefeated;
  bool get isBossIntroActive => _bossIntroRemaining > 0;
  int? get bossHealth => _bossEncounterStarted ? _boss?.health : null;
  int? get bossMaxHealth => _bossEncounterStarted ? _boss?.maxHealth : null;
  String? get bossPhaseKey => _bossEncounterStarted ? _boss?.phaseId : null;
  CampaignChapterBossComponent? get boss => _boss;
  BossArenaPresentationComponent? get bossArenaPresentation =>
      _bossArenaPresentation;
  List<BossSealGateComponent> get bossSeals =>
      List<BossSealGateComponent>.unmodifiable(_bossSeals);

  CampaignNodeId get firstNode => isTemporal
      ? CampaignNodeId.temporalAscent
      : CampaignNodeId.collisionCompression;
  CampaignNodeId get secondNode => isTemporal
      ? CampaignNodeId.temporalFracture
      : CampaignNodeId.collisionFracture;
  CampaignNodeId get thirdNode => isTemporal
      ? CampaignNodeId.temporalPendulum
      : CampaignNodeId.collisionMerge;
  CampaignNodeId get bossNode =>
      isTemporal ? CampaignNodeId.chronoJailer : CampaignNodeId.kernelChimera;
  String get hubAccessId => isTemporal
      ? CampaignWorldGraph.temporalHubAccessId
      : CampaignWorldGraph.collisionHubAccessId;
  String get hubLiftId => isTemporal
      ? CampaignWorldGraph.temporalHubLiftId
      : CampaignWorldGraph.collisionHubLiftId;

  @override
  CampaignNodeId get campaignNodeId => nodeId;

  bool get usesExpandedTemporalGeometry => isTemporal && !isBossRoom;
  bool get usesExpandedCollisionGeometry => !isTemporal && !isBossRoom;
  bool get usesExpandedRegionalGeometry => !isBossRoom;

  List<Rect> get backdropAlignedPlatformBounds =>
      List<Rect>.unmodifiable(switch (nodeId) {
        CampaignNodeId.temporalAscent => _temporalAscentPlatformBounds,
        CampaignNodeId.temporalFracture => _temporalFracturePlatformBounds,
        CampaignNodeId.temporalPendulum => _temporalPendulumPlatformBounds,
        CampaignNodeId.collisionCompression =>
          _collisionCompressionPlatformBounds,
        CampaignNodeId.collisionFracture => _collisionFracturePlatformBounds,
        CampaignNodeId.collisionMerge => _collisionMergePlatformBounds,
        _ => const <Rect>[],
      });

  String? get environmentAsset => switch (nodeId) {
    CampaignNodeId.temporalAscent => _temporalAscentEnvironmentAsset,
    CampaignNodeId.temporalFracture => _temporalFractureEnvironmentAsset,
    CampaignNodeId.temporalPendulum => _temporalPendulumEnvironmentAsset,
    CampaignNodeId.collisionCompression =>
      _collisionCompressionEnvironmentAsset,
    CampaignNodeId.collisionFracture => _collisionFractureEnvironmentAsset,
    CampaignNodeId.collisionMerge => _collisionMergeEnvironmentAsset,
    _ => null,
  };

  Vector2 get _westDoorPosition => switch (nodeId) {
    CampaignNodeId.temporalAscent => Vector2(90, 900),
    CampaignNodeId.temporalFracture => Vector2(90, 750),
    CampaignNodeId.temporalPendulum => Vector2(90, 700),
    CampaignNodeId.collisionCompression => Vector2(90, 980),
    CampaignNodeId.collisionFracture => Vector2(90, 980),
    CampaignNodeId.collisionMerge => Vector2(90, 980),
    _ => Vector2(70, _floorY),
  };

  Vector2 get _eastDoorPosition => switch (nodeId) {
    CampaignNodeId.temporalAscent => Vector2(1810, 230),
    CampaignNodeId.temporalFracture => Vector2(1810, 425),
    CampaignNodeId.temporalPendulum => Vector2(1810, 325),
    CampaignNodeId.collisionCompression => Vector2(1810, 550),
    CampaignNodeId.collisionFracture => Vector2(1810, 250),
    CampaignNodeId.collisionMerge => Vector2(1810, 230),
    _ => Vector2(890, _floorY),
  };

  Vector2 get _recordPosition => switch (nodeId) {
    CampaignNodeId.temporalAscent => Vector2(1510, 375),
    CampaignNodeId.temporalFracture => Vector2(250, 980),
    CampaignNodeId.temporalPendulum => Vector2(1320, 400),
    CampaignNodeId.collisionCompression => Vector2(1060, 680),
    CampaignNodeId.collisionFracture => Vector2(300, 1040),
    CampaignNodeId.collisionMerge => Vector2(980, 680),
    _ => Vector2(switch (encounterId) {
      0 => 830.0,
      1 => 560.0,
      _ => 170.0,
    }, _floorY - 6),
  };

  Vector2 get _questRewardPosition => switch (nodeId) {
    CampaignNodeId.temporalPendulum => Vector2(1320, 400),
    CampaignNodeId.collisionMerge => Vector2(980, 680),
    _ => Vector2(500, _floorY - 6),
  };

  List<(PlatformerEnemyArchetype, double, double)> get combatEncounterSpecs =>
      switch (nodeId) {
        CampaignNodeId.temporalAscent =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.tickRunner, 410, 854),
            (PlatformerEnemyArchetype.echoBat, 790, 610),
            (PlatformerEnemyArchetype.delaySniper, 1160, 479),
            (PlatformerEnemyArchetype.rewindSkater, 1680, 254),
          ],
        CampaignNodeId.temporalFracture =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.delaySniper, 360, 704),
            (PlatformerEnemyArchetype.tickRunner, 700, 554),
            (PlatformerEnemyArchetype.echoBat, 1080, 500),
            (PlatformerEnemyArchetype.rewindSkater, 1580, 379),
          ],
        CampaignNodeId.temporalPendulum =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.rewindSkater, 360, 654),
            (PlatformerEnemyArchetype.echoBat, 780, 420),
            (PlatformerEnemyArchetype.tickRunner, 1160, 429),
            (PlatformerEnemyArchetype.delaySniper, 1600, 279),
          ],
        CampaignNodeId.collisionCompression =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.vectorRam, 390, 934),
            (PlatformerEnemyArchetype.polarityDrone, 760, 690),
            (PlatformerEnemyArchetype.phaseMimic, 1110, 559),
            (PlatformerEnemyArchetype.shardLobber, 1580, 504),
          ],
        CampaignNodeId.collisionFracture =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.phaseMimic, 350, 934),
            (PlatformerEnemyArchetype.vectorRam, 760, 709),
            (PlatformerEnemyArchetype.shardLobber, 1160, 484),
            (PlatformerEnemyArchetype.polarityDrone, 1640, 259),
          ],
        CampaignNodeId.collisionMerge =>
          const <(PlatformerEnemyArchetype, double, double)>[
            (PlatformerEnemyArchetype.shardLobber, 390, 934),
            (PlatformerEnemyArchetype.polarityDrone, 780, 700),
            (PlatformerEnemyArchetype.vectorRam, 1180, 559),
            (PlatformerEnemyArchetype.phaseMimic, 1660, 259),
          ],
        _ => const <(PlatformerEnemyArchetype, double, double)>[],
      };

  @override
  Vector2 get playerSpawn {
    final door = entry == CampaignNodeEntry.west
        ? _westDoorPosition
        : _eastDoorPosition;
    return door - Vector2(0, 36);
  }

  @override
  late final Vector2 worldSize = Vector2(
    usesExpandedRegionalGeometry ? _expandedRoomWidth : 960,
    usesExpandedRegionalGeometry ? _expandedRoomHeight : 540,
  );

  @override
  double get killPlaneY => usesExpandedRegionalGeometry ? 1160 : 620;

  List<TraversalSegment> get requiredTraversalSegments => switch (nodeId) {
    CampaignNodeId.temporalAscent => const <TraversalSegment>[
      TraversalSegment(
        id: 'temporal.ascent.step-1',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.step-2',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.step-3',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.step-4',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.step-5',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.step-6',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.step-7',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'temporal.ascent.airlock-step',
        rise: 70,
        gap: 0,
        landingWidth: 260,
      ),
    ],
    CampaignNodeId.temporalFracture => const <TraversalSegment>[
      TraversalSegment(
        id: 'temporal.fracture.stable-rise-1',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.fracture.stable-rise-2',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.fracture.stable-rise-3',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.fracture.stable-crossing',
        rise: 0,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.fracture.stable-rise-4',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.fracture.east-airlock',
        rise: 75,
        gap: 0,
        landingWidth: 420,
      ),
    ],
    CampaignNodeId.temporalPendulum => const <TraversalSegment>[
      TraversalSegment(
        id: 'temporal.pendulum.outer-step-1',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.pendulum.outer-step-2',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.pendulum.outer-step-3',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.pendulum.outer-landing',
        rise: 0,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.pendulum.outer-step-4',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.pendulum.outer-step-5',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'temporal.pendulum.preboss-airlock',
        rise: 75,
        gap: 0,
        landingWidth: 440,
      ),
    ],
    CampaignNodeId.collisionCompression => const <TraversalSegment>[
      TraversalSegment(
        id: 'collision.compression.static-step-1',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.compression.static-step-2',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.compression.static-step-3',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.compression.static-step-4',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.compression.static-step-5',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.compression.static-step-6',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.compression.east-airlock',
        rise: 0,
        gap: 0,
        landingWidth: 470,
      ),
    ],
    CampaignNodeId.collisionFracture => const <TraversalSegment>[
      TraversalSegment(
        id: 'collision.fracture.outer-step-1',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-2',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-3',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-4',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-5',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-6',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-7',
        rise: 75,
        gap: 0,
        landingWidth: 210,
      ),
      TraversalSegment(
        id: 'collision.fracture.outer-step-8',
        rise: 75,
        gap: 0,
        landingWidth: 300,
      ),
      TraversalSegment(
        id: 'collision.fracture.east-airlock',
        rise: 55,
        gap: 0,
        landingWidth: 200,
      ),
    ],
    CampaignNodeId.collisionMerge => const <TraversalSegment>[
      TraversalSegment(
        id: 'collision.merge.outer-step-1',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-2',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-3',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-4',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-5',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-6',
        rise: 75,
        gap: 0,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-7',
        rise: 75,
        gap: 0,
        landingWidth: 310,
      ),
      TraversalSegment(
        id: 'collision.merge.outer-step-8',
        rise: 75,
        gap: 0,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'collision.merge.preboss-airlock',
        rise: 75,
        gap: 0,
        landingWidth: 280,
      ),
    ],
    _ when isBossRoom => <TraversalSegment>[
      TraversalSegment(
        id: '${region.name}.boss.arena-floor',
        rise: 0,
        gap: 0,
        landingWidth: 960,
      ),
    ],
    _ => <TraversalSegment>[
      TraversalSegment(
        id: '${nodeId.name}.gap-a',
        rise: 0,
        gap: encounterId == 1 ? 100 : 90,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: '${nodeId.name}.gap-b',
        rise: 0,
        gap: encounterId == 2 ? 100 : 90,
        landingWidth: 180,
      ),
      TraversalSegment(
        id: '${nodeId.name}.optional-static-step',
        rise: 72,
        gap: 0,
        landingWidth: 140,
      ),
    ],
  };

  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) {
    final checkpoint = _checkpoint;
    if (checkpoint != null && checkpoint.isActive) {
      return checkpoint.position - Vector2(0, 36);
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
    return usesExpandedRegionalGeometry
        ? Vector2(playerPosition.x, playerPosition.y - 68)
        : Vector2(480, 270);
  }

  @override
  double cameraZoomFor(Vector2 playerPosition) {
    if (isBossIntroActive) return 1.32;
    if (_bossEncounterStarted && (_boss?.isActive ?? false)) return 1.08;
    return usesExpandedRegionalGeometry ? .92 : 1;
  }

  @override
  double get horizontalCameraLead => usesExpandedRegionalGeometry ? 96 : 0;

  @override
  double get horizontalCameraDeadZone => usesExpandedRegionalGeometry ? 112 : 0;

  @override
  double get verticalCameraDeadZone => usesExpandedRegionalGeometry ? 58 : 0;

  @override
  double get cameraFollowResponsiveness =>
      usesExpandedRegionalGeometry ? 5.2 : 1000;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      RoomBackdropComponent(
        backdropStyle,
        worldSize: worldSize,
        environmentAsset: environmentAsset,
      ),
    );
    _buildGeometry();
    await addAll(_surfaces);
    await _addRoomFeatures();
    await _addTerrainPulseRoute();
    await _addServiceRoomFeatures();
    if (nodeId == firstNode) {
      final checkpoint = CampaignCheckpointComponent(
        position: usesExpandedRegionalGeometry
            ? (isTemporal ? Vector2(300, 900) : Vector2(420, 980))
            : Vector2(360, _floorY),
        isActive: game.campaignExploration.checkpointNodeId == campaignNodeId,
        onActivated: () => game.activateCampaignCheckpoint(campaignNodeId),
      );
      _checkpoint = checkpoint;
      await add(checkpoint);
    }
    if (isBossRoom) {
      await _addBossEncounter();
    } else {
      await _addCombatEncounter();
      await _addRecord();
      if (nodeId == thirdNode &&
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
        usesExpandedRegionalGeometry ? _expandedRoomHeight : 540,
        boundary: true,
      ),
      if (usesExpandedRegionalGeometry)
        ...backdropAlignedPlatformBounds.map(
          (bounds) => _surface(
            bounds.left,
            bounds.top,
            bounds.width,
            bounds.height,
            boundary: bounds.left == 1896,
            renderArtwork: false,
          ),
        )
      else ...<PlatformSurfaceComponent>[
        _surface(936, 0, 24, 540, boundary: true),
        if (isBossRoom) ...<PlatformSurfaceComponent>[
          _surface(0, _floorY, 960, 56),
          _surface(150, 396, 170, 20),
          _surface(640, 396, 170, 20),
        ] else ...<PlatformSurfaceComponent>[
          _surface(0, _floorY, encounterId == 1 ? 350 : 340, 56),
          _surface(encounterId == 1 ? 450 : 430, _floorY, 220, 56),
          _surface(
            encounterId == 1
                ? 760
                : encounterId == 2
                ? 750
                : 740,
            _floorY,
            encounterId == 2 ? 210 : 220,
            56,
          ),
          _surface(120, 412, 160, 20),
          _surface(430, 340, 160, 20),
          _surface(700, 412, 150, 20),
        ],
      ],
    ]);
  }

  Future<void> _addTerrainPulseRoute() async {
    if (nodeId != secondNode) return;
    final routeId = 'terrain.${nodeId.name}.upper-bypass';
    final bridge = TerrainPulseBridgeComponent(
      position: isTemporal ? Vector2(1010, 250) : Vector2(1010, 545),
      size: Vector2(190, 20),
      style: surfaceStyle,
    );
    final node = TerrainPulseNodeComponent(
      position: isTemporal ? Vector2(890, 554) : Vector2(890, 980),
      nodeId: routeId,
      onActivated: bridge.activate,
      accentColor: accentColor,
    );
    _surfaces.add(bridge);
    _terrainPulseNode = node;
    await addAll(<Component>[bridge, node]);
    if (game.campaignExploration.activatedTerrainNodeIds.contains(routeId)) {
      node.restoreActivated();
    }
  }

  Future<void> _addServiceRoomFeatures() async {
    if (nodeId == firstNode) {
      final station = CampaignRepairStationComponent(
        position: isTemporal ? Vector2(510, 900) : Vector2(560, 980),
        used: progress.repairStationUsed,
        onUsed: () => progress.repairStationUsed = true,
        accentColor: accentColor,
      );
      _repairStation = station;
      await add(station);
    }
    if (nodeId == thirdNode) {
      final terminal = LoadoutEventTerminalComponent(
        position: isTemporal ? Vector2(1500, 680) : Vector2(1500, 980),
        resolved: progress.loadoutEventResolved,
        rewardFor: (weapon) => switch ((isTemporal, weapon)) {
          (true, PlayerWeapon.sword) => RunItemId.chronalBuffer,
          (true, PlayerWeapon.gauntlet) => RunItemId.echoSpring,
          (true, PlayerWeapon.gun) => RunItemId.predictiveScope,
          (false, PlayerWeapon.sword) => RunItemId.vectorEdge,
          (false, PlayerWeapon.gauntlet) => RunItemId.impactLattice,
          (false, PlayerWeapon.gun) => RunItemId.splitChamber,
        },
        onResolved: () => progress.loadoutEventResolved = true,
        accentColor: accentColor,
      );
      _loadoutEvent = terminal;
      await add(terminal);
    }
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
    style: surfaceStyle,
    renderArtwork: renderArtwork,
  );

  Future<void> _addRoomFeatures() async {
    if (isBossRoom) return;
    if (usesExpandedRegionalGeometry) {
      if (isTemporal) {
        await _addExpandedTemporalFeatures();
      } else {
        await _addExpandedCollisionFeatures();
      }
      return;
    }
    final firstGapX = encounterId == 1 ? 350.0 : 340.0;
    final firstGapWidth = encounterId == 1 ? 100.0 : 90.0;
    final secondGapX = encounterId == 1 ? 670.0 : 650.0;
    final secondGapWidth = encounterId == 2 ? 100.0 : 90.0;
    final features = <Component>[
      DamagePitComponent(
        position: Vector2(firstGapX, _floorY),
        size: Vector2(firstGapWidth, 56),
        style: surfaceStyle,
      ),
      DamagePitComponent(
        position: Vector2(secondGapX, _floorY),
        size: Vector2(secondGapWidth, 56),
        style: surfaceStyle,
      ),
    ];
    if (isTemporal) {
      switch (encounterId) {
        case 0:
          features.add(
            MovingPlatformComponent(
              start: Vector2(600, 330),
              end: Vector2(720, 250),
              size: Vector2(120, 20),
              periodSeconds: 4,
              style: surfaceStyle,
            ),
          );
        case 1:
          features.addAll(<Component>[
            BreakablePlatformComponent(
              position: Vector2(610, 300),
              size: Vector2(150, 20),
              style: surfaceStyle,
            ),
            PulsingLaserComponent(
              position: Vector2(548, 210),
              size: Vector2(12, 130),
              sourceId: 'hazard.temporal-hall.fracture.optional-timeline',
              style: surfaceStyle,
              activeSeconds: 1.1,
              inactiveSeconds: 1.3,
            ),
          ]);
        case 2:
          features.addAll(<Component>[
            CrusherHazardComponent(
              start: Vector2(480, 150),
              end: Vector2(480, 270),
              size: Vector2(90, 54),
              sourceId: 'hazard.temporal-hall.pendulum.optional-crusher',
              style: surfaceStyle,
              periodSeconds: 4.2,
            ),
            RoomHazardComponent(
              position: Vector2(460, 328),
              size: Vector2(80, 12),
              style: RoomHazardStyle.spikes,
              surfaceStyle: surfaceStyle,
              sourceId: 'hazard.temporal-hall.pendulum.clock-teeth',
            ),
          ]);
      }
    } else {
      switch (encounterId) {
        case 0:
          features.add(
            MovingPlatformComponent(
              start: Vector2(590, 330),
              end: Vector2(720, 245),
              size: Vector2(120, 20),
              periodSeconds: 3.5,
              style: surfaceStyle,
            ),
          );
        case 1:
          features.addAll(<Component>[
            BreakablePlatformComponent(
              position: Vector2(610, 295),
              size: Vector2(150, 20),
              style: surfaceStyle,
              breakDelay: .55,
            ),
            PulsingLaserComponent(
              position: Vector2(548, 205),
              size: Vector2(12, 135),
              sourceId: 'hazard.collision-archive.fracture.optional-slice',
              style: surfaceStyle,
            ),
          ]);
        case 2:
          features.addAll(<Component>[
            CrusherHazardComponent(
              start: Vector2(480, 145),
              end: Vector2(480, 265),
              size: Vector2(95, 58),
              sourceId: 'hazard.collision-archive.merge.optional-crusher',
              style: surfaceStyle,
              periodSeconds: 3.4,
            ),
            RoomHazardComponent(
              position: Vector2(455, 328),
              size: Vector2(90, 12),
              style: RoomHazardStyle.spikes,
              surfaceStyle: surfaceStyle,
              sourceId: 'hazard.collision-archive.merge.polarity-teeth',
            ),
          ]);
      }
    }
    await addAll(features);
  }

  Future<void> _addExpandedTemporalFeatures() async {
    final features = <Component>[];
    final dynamicSurfaces = <PlatformSurfaceComponent>[];
    switch (nodeId) {
      case CampaignNodeId.temporalAscent:
        dynamicSurfaces.addAll(<PlatformSurfaceComponent>[
          MovingPlatformComponent(
            start: Vector2(1010, 430),
            end: Vector2(1010, 300),
            size: Vector2(132, 22),
            periodSeconds: 4.8,
            style: surfaceStyle,
          ),
          RewindPlatformComponent(
            timeline: <Vector2>[
              Vector2(1260, 300),
              Vector2(1400, 255),
              Vector2(1500, 300),
            ],
            size: Vector2(128, 22),
            periodSeconds: 5.6,
            style: surfaceStyle,
          ),
        ]);
        features.add(
          JumpPadComponent(position: Vector2(750, 663), style: surfaceStyle),
        );
      case CampaignNodeId.temporalFracture:
        dynamicSurfaces.addAll(<PlatformSurfaceComponent>[
          BreakablePlatformComponent(
            position: Vector2(830, 365),
            size: Vector2(145, 22),
            style: surfaceStyle,
            breakDelay: .8,
          ),
          RewindPlatformComponent(
            timeline: <Vector2>[
              Vector2(720, 330),
              Vector2(895, 285),
              Vector2(1065, 330),
            ],
            size: Vector2(138, 22),
            periodSeconds: 6.2,
            style: surfaceStyle,
          ),
        ]);
        features.addAll(<Component>[
          PulsingLaserComponent(
            position: Vector2(948, 245),
            size: Vector2(14, 280),
            sourceId: 'hazard.temporal-hall.fracture.timeline-seam',
            style: surfaceStyle,
            activeSeconds: 1.15,
            inactiveSeconds: 1.45,
          ),
          RoomHazardComponent(
            position: Vector2(760, 878),
            size: Vector2(140, 18),
            style: RoomHazardStyle.spikes,
            surfaceStyle: surfaceStyle,
            sourceId: 'hazard.temporal-hall.fracture.discarded-timeline',
          ),
        ]);
      case CampaignNodeId.temporalPendulum:
        dynamicSurfaces.add(
          RewindPlatformComponent(
            timeline: <Vector2>[
              Vector2(760, 350),
              Vector2(940, 300),
              Vector2(1120, 350),
            ],
            size: Vector2(132, 22),
            periodSeconds: 5.4,
            style: surfaceStyle,
          ),
        );
        features.addAll(<Component>[
          CrusherHazardComponent(
            start: Vector2(920, 170),
            end: Vector2(920, 390),
            size: Vector2(86, 64),
            sourceId: 'hazard.temporal-hall.pendulum.central-crusher',
            style: surfaceStyle,
            periodSeconds: 4.4,
          ),
          PulsingLaserComponent(
            position: Vector2(1000, 600),
            size: Vector2(14, 300),
            sourceId: 'hazard.temporal-hall.pendulum.service-beam',
            style: surfaceStyle,
            activeSeconds: .9,
            inactiveSeconds: 1.6,
          ),
          RoomHazardComponent(
            position: Vector2(870, 878),
            size: Vector2(120, 18),
            style: RoomHazardStyle.spikes,
            surfaceStyle: surfaceStyle,
            sourceId: 'hazard.temporal-hall.pendulum.clock-teeth',
          ),
        ]);
      default:
        break;
    }
    _surfaces.addAll(dynamicSurfaces);
    features.addAll(dynamicSurfaces);
    await addAll(features);
  }

  Future<void> _addExpandedCollisionFeatures() async {
    final features = <Component>[];
    final dynamicSurfaces = <PlatformSurfaceComponent>[];
    switch (nodeId) {
      case CampaignNodeId.collisionCompression:
        dynamicSurfaces.addAll(<PlatformSurfaceComponent>[
          MovingPlatformComponent(
            start: Vector2(690, 430),
            end: Vector2(845, 430),
            size: Vector2(138, 22),
            periodSeconds: 4.8,
            style: surfaceStyle,
          ),
          MovingPlatformComponent(
            start: Vector2(1090, 430),
            end: Vector2(935, 430),
            size: Vector2(138, 22),
            periodSeconds: 4.8,
            style: surfaceStyle,
          ),
          ConveyorPlatformComponent(
            position: Vector2(760, 865),
            size: Vector2(180, 22),
            direction: 1,
            style: surfaceStyle,
          ),
        ]);
        features.addAll(<Component>[
          CrusherHazardComponent(
            start: Vector2(925, 250),
            end: Vector2(925, 490),
            size: Vector2(90, 66),
            sourceId: 'hazard.collision-archive.compression.central-piston',
            style: surfaceStyle,
            periodSeconds: 4.1,
          ),
          PulsingLaserComponent(
            position: Vector2(958, 520),
            size: Vector2(14, 160),
            sourceId: 'hazard.collision-archive.compression.seam',
            style: surfaceStyle,
            activeSeconds: 1,
            inactiveSeconds: 1.5,
          ),
        ]);
      case CampaignNodeId.collisionFracture:
        dynamicSurfaces.addAll(<PlatformSurfaceComponent>[
          BreakablePlatformComponent(
            position: Vector2(820, 360),
            size: Vector2(145, 22),
            style: surfaceStyle,
            breakDelay: .65,
          ),
          MovingPlatformComponent(
            start: Vector2(990, 345),
            end: Vector2(1160, 260),
            size: Vector2(138, 22),
            periodSeconds: 5,
            style: surfaceStyle,
          ),
        ]);
        features.addAll(<Component>[
          PulsingLaserComponent(
            position: Vector2(948, 215),
            size: Vector2(14, 390),
            sourceId: 'hazard.collision-archive.fracture.phase-slice',
            style: surfaceStyle,
            activeSeconds: 1.05,
            inactiveSeconds: 1.35,
          ),
          RoomHazardComponent(
            position: Vector2(890, 878),
            size: Vector2(130, 18),
            style: RoomHazardStyle.spikes,
            surfaceStyle: surfaceStyle,
            sourceId: 'hazard.collision-archive.fracture.rollback-shards',
          ),
        ]);
      case CampaignNodeId.collisionMerge:
        dynamicSurfaces.addAll(<PlatformSurfaceComponent>[
          MergingPlatformComponent(
            position: Vector2(840, 430),
            size: Vector2(240, 24),
            periodSeconds: 5.6,
            style: surfaceStyle,
          ),
          MovingPlatformComponent(
            start: Vector2(690, 510),
            end: Vector2(815, 455),
            size: Vector2(130, 22),
            periodSeconds: 4.6,
            style: surfaceStyle,
          ),
          MovingPlatformComponent(
            start: Vector2(1100, 455),
            end: Vector2(1225, 510),
            size: Vector2(130, 22),
            periodSeconds: 4.6,
            style: surfaceStyle,
          ),
        ]);
        features.addAll(<Component>[
          PulsingLaserComponent(
            position: Vector2(958, 230),
            size: Vector2(14, 450),
            sourceId: 'hazard.collision-archive.merge.fusion-axis',
            style: surfaceStyle,
            activeSeconds: .8,
            inactiveSeconds: 1.8,
          ),
          RoomHazardComponent(
            position: Vector2(940, 888),
            size: Vector2(120, 18),
            style: RoomHazardStyle.spikes,
            surfaceStyle: surfaceStyle,
            sourceId: 'hazard.collision-archive.merge.unstable-shards',
          ),
        ]);
      default:
        break;
    }
    _surfaces.addAll(dynamicSurfaces);
    features.addAll(dynamicSurfaces);
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

  Future<void> _addRecord() async {
    if (progress.collectedRecordIds.contains(encounterId)) return;
    final terminal = QaRecordTerminalComponent(
      position: _recordPosition,
      recordId: encounterId,
      labelLocalizationKey: recordLocalizationKey,
      onCollected: _onRecordCollected,
    );
    _recordTerminals.add(terminal);
    await add(terminal);
  }

  Future<void> _addBossEncounter() async {
    final arenaPresentation = BossArenaPresentationComponent(
      size: worldSize.clone(),
      accentColor: accentColor,
      initiallyCleared: progress.bossDefeated,
    );
    _bossArenaPresentation = arenaPresentation;
    await add(arenaPresentation);
    if (!progress.bossDefeated) {
      final seals = <BossSealGateComponent>[
        BossSealGateComponent(
          position: Vector2(96, 172),
          size: Vector2(18, 312),
          style: surfaceStyle,
        ),
        BossSealGateComponent(
          position: Vector2(846, 172),
          size: Vector2(18, 312),
          style: surfaceStyle,
        ),
      ];
      _bossSeals.addAll(seals);
      _surfaces.addAll(seals);
      await addAll(seals);
      final boss = CampaignChapterBossComponent(
        position: Vector2(620, _floorY - 56),
        kind: bossKind,
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
    if (!isBossRoom || progress.bossDefeated) await _spawnBackDoors();
    if (!isBossRoom && progress.clearedEncounterIds.contains(encounterId)) {
      await _spawnClearedRoomDoors();
    }
    if (isBossRoom && progress.bossDefeated && progress.patchApplied) {
      await _spawnHubLiftDoor();
    }
  }

  Future<void> _spawnBackDoors() async {
    final previous = switch (nodeId) {
      CampaignNodeId.temporalAscent ||
      CampaignNodeId.collisionCompression => CampaignNodeId.overflowWarden,
      CampaignNodeId.temporalFracture => CampaignNodeId.temporalAscent,
      CampaignNodeId.temporalPendulum => CampaignNodeId.temporalFracture,
      CampaignNodeId.chronoJailer => CampaignNodeId.temporalPendulum,
      CampaignNodeId.collisionFracture => CampaignNodeId.collisionCompression,
      CampaignNodeId.collisionMerge => CampaignNodeId.collisionFracture,
      CampaignNodeId.kernelChimera => CampaignNodeId.collisionMerge,
      _ => throw StateError('Unsupported regional node: $nodeId'),
    };
    await _spawnDoor(
      target: previous,
      position: _westDoorPosition,
      labelLocalizationKey: nodeId == firstNode
          ? 'interaction.returnOverflowJunction'
          : 'interaction.previousRoom',
      targetEntry: CampaignNodeEntry.east,
    );
    if (nodeId == firstNode &&
        game.campaignExploration.unlockedShortcutIds.contains(hubAccessId)) {
      await _spawnDoor(
        target: CampaignNodeId.bootSector,
        position: usesExpandedRegionalGeometry
            ? _westDoorPosition + Vector2(130, 0)
            : Vector2(190, _floorY),
        labelLocalizationKey: 'interaction.returnBootSector',
        targetEntry: CampaignNodeEntry.east,
        color: accentColor,
      );
    }
  }

  Future<void> _spawnForwardDoor() async {
    final target = switch (nodeId) {
      CampaignNodeId.temporalAscent => CampaignNodeId.temporalFracture,
      CampaignNodeId.temporalFracture => CampaignNodeId.temporalPendulum,
      CampaignNodeId.temporalPendulum => CampaignNodeId.chronoJailer,
      CampaignNodeId.collisionCompression => CampaignNodeId.collisionFracture,
      CampaignNodeId.collisionFracture => CampaignNodeId.collisionMerge,
      CampaignNodeId.collisionMerge => CampaignNodeId.kernelChimera,
      _ => throw StateError('Boss rooms do not have a forward room door.'),
    };
    await _spawnDoor(
      target: target,
      position: _eastDoorPosition,
      labelLocalizationKey: nodeId == thirdNode
          ? 'interaction.enterBossRoom'
          : 'interaction.nextRoom',
      targetEntry: CampaignNodeEntry.west,
    );
  }

  Future<void> _spawnClearedRoomDoors() async {
    await _spawnForwardDoor();
    if (nodeId == secondNode) await _spawnSecretDoor();
  }

  Future<void> _spawnSecretDoor() async {
    final weapon = game.world.player.selectedWeapon;
    final target = switch ((region, weapon)) {
      (CampaignRegion.temporalHall, PlayerWeapon.sword) =>
        CampaignNodeId.temporalDashRift,
      (CampaignRegion.temporalHall, PlayerWeapon.gauntlet) =>
        CampaignNodeId.temporalUpperLoop,
      (CampaignRegion.temporalHall, PlayerWeapon.gun) =>
        CampaignNodeId.temporalRelayControl,
      (CampaignRegion.collisionArchive, PlayerWeapon.sword) =>
        CampaignNodeId.collisionVectorCache,
      (CampaignRegion.collisionArchive, PlayerWeapon.gauntlet) =>
        CampaignNodeId.collisionUpperMatrix,
      (CampaignRegion.collisionArchive, PlayerWeapon.gun) =>
        CampaignNodeId.collisionPrismControl,
      _ => throw StateError('Unsupported optional route region: $region'),
    };
    final labelLocalizationKey = switch (target) {
      CampaignNodeId.temporalDashRift => 'interaction.enterTemporalDashRift',
      CampaignNodeId.temporalUpperLoop => 'interaction.enterTemporalUpperLoop',
      CampaignNodeId.temporalRelayControl =>
        'interaction.enterTemporalRelayControl',
      CampaignNodeId.collisionVectorCache =>
        'interaction.enterCollisionVectorCache',
      CampaignNodeId.collisionUpperMatrix =>
        'interaction.enterCollisionUpperMatrix',
      CampaignNodeId.collisionPrismControl =>
        'interaction.enterCollisionPrismControl',
      _ => throw StateError('Unsupported optional route node: $target'),
    };
    await _spawnDoor(
      target: target,
      position: usesExpandedRegionalGeometry
          ? (isTemporal ? Vector2(250, 980) : Vector2(300, 1040))
          : Vector2(770, _floorY),
      labelLocalizationKey: labelLocalizationKey,
      targetEntry: CampaignNodeEntry.west,
      color: accentColor,
    );
  }

  Future<void> _spawnHubLiftDoor() => _spawnDoor(
    target: CampaignNodeId.bootSector,
    position: Vector2(245, _floorY),
    labelLocalizationKey: 'interaction.returnHubLift',
    targetEntry: CampaignNodeEntry.east,
    color: accentColor,
  );

  Future<void> _spawnDoor({
    required CampaignNodeId target,
    required Vector2 position,
    required String labelLocalizationKey,
    required CampaignNodeEntry targetEntry,
    Color? color,
  }) async {
    if (_doors.containsKey(target)) return;
    final door = CampaignDoorComponent(
      position: position,
      labelLocalizationKey: labelLocalizationKey,
      accentColor: color ?? accentColor,
      onInteract: () => game.travelToCampaignNode(target, entry: targetEntry),
    );
    _doors[target] = door;
    await add(door);
  }

  void _onEnemyDefeated(PlatformerEnemyComponent enemy) {
    if (!_defeatedEnemies.add(enemy)) return;
    _defeatedCount += 1;
    game.runMetrics.recordOverflow();
    if (_enemyEncounterIds.keys.every(_defeatedEnemies.contains)) {
      progress.clearedEncounterIds.add(encounterId);
      if (game.runItems.contains(RunItemId.conduitHeart)) {
        game.world.player.restoreIntegrity(1);
      }
      unawaited(_spawnClearedRoomDoors());
    }
    game.publishUiSnapshot(force: true);
  }

  void _onRecordCollected(int recordId) {
    progress.collectedRecordIds.add(recordId);
    _recordTerminals.removeWhere((terminal) => terminal.recordId == recordId);
    game.world.player.absorbDataShard(amount: 2);
    if (nodeId == thirdNode &&
        progress.questComplete &&
        !progress.questRewardClaimed) {
      unawaited(_spawnQuestReward());
    }
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnQuestReward() async {
    if (_questReward != null || progress.questRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: _questRewardPosition,
      item: questRewardItem,
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
      title: game.localization.text(bossKind.enemyLocalizationKey),
      subtitle: game.localization.text(bossIntroLocalizationKey),
      accentColor: accentColor,
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
    game.campaignExploration
      ..collectCoreSignature(region)
      ..unlockShortcut(hubLiftId);
    _bossArenaPresentation?.markCleared();
    for (final seal in _bossSeals) {
      seal.unlock();
    }
    unawaited(_showCoreSignatureCard());
    unawaited(_spawnBackDoors());
    unawaited(_spawnBossReward());
    unawaited(_spawnExitTerminal());
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnBossReward() async {
    if (_bossReward != null || progress.bossRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: Vector2(700, _floorY - 6),
      item: bossRewardItem,
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
    final regionKey = isTemporal
        ? 'room.temporalHall'
        : 'room.collisionArchive';
    final abilityKey = isTemporal
        ? 'ability.airDash.name'
        : 'ability.terrainPulse.name';
    await add(
      BossNameCardComponent(
        center: Vector2(480, 145),
        title: game.localization.text('boss.coreSignatureAcquired'),
        subtitle:
            '${game.localization.text(regionKey)} // '
            '${game.localization.text(abilityKey)} // '
            '${game.localization.text('boss.optimizerGateUpdated')}',
        accentColor: const Color(0xFF45F3A6),
        style: BossNameCardStyle.victory,
        duration: 3.4,
      ),
    );
  }

  void _onBossPhaseChanged(CampaignChapterBossPhase phase) {
    switch (phase) {
      case CampaignChapterBossPhase.dormant:
        break;
      case CampaignChapterBossPhase.intro:
        _bossArenaPresentation?.beginIntro();
      case CampaignChapterBossPhase.phaseOne:
        _bossArenaPresentation?.beginPhaseOne();
      case CampaignChapterBossPhase.phaseTwo:
        _bossArenaPresentation?.beginPhaseTwo();
      case CampaignChapterBossPhase.phaseThree:
        _bossArenaPresentation?.beginPhaseThree();
      case CampaignChapterBossPhase.defeated:
        _bossArenaPresentation?.markCleared();
    }
  }

  Future<void> _spawnExitTerminal() async {
    if (_exitTerminal != null) return;
    final terminal = PatchExitTerminalComponent(
      position: Vector2(850, _floorY - 6),
      accentColor: accentColor,
    );
    _exitTerminal = terminal;
    await add(terminal);
  }

  bool tryInteract(PlayerComponent player) {
    if (_checkpoint?.tryActivate(player) ?? false) return true;
    if (_repairStation?.tryUse(player) ?? false) return true;
    if (_loadoutEvent?.tryResolve(player) ?? false) return true;
    if (_terrainPulseNode?.tryActivate(player) ?? false) return true;
    for (final door in _doors.values.toList()) {
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
    if (isTemporal) {
      game.openRoomTwoPatchSelection();
    } else {
      game.openRoomThreePatchSelection();
    }
    return true;
  }

  @override
  void update(double dt) {
    if (isBossRoom && !progress.bossDefeated) _startBossIntro();
    if (_bossIntroRemaining > 0) {
      _bossIntroRemaining = math.max(
        0,
        _bossIntroRemaining - game.clock.realDt,
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
