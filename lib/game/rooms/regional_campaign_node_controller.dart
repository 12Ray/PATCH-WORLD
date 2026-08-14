import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/patch_exit_terminal_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/qa_record_terminal_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

/// Independent 960x540 campaign scene used by Temporal Hall and Collision
/// Archive. The old four-cell controllers remain available for direct debug
/// launches while the connected campaign uses this graph-backed controller.
final class RegionalCampaignNodeController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        CampaignNodeRoom {
  RegionalCampaignNodeController({
    required this.nodeId,
    required this.entry,
    required this.progress,
  }) : assert(_supportedNodes.contains(nodeId));

  static const double _floorY = 484;
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

  @override
  Vector2 get playerSpawn =>
      entry == CampaignNodeEntry.west ? Vector2(154, 448) : Vector2(806, 448);

  @override
  final Vector2 worldSize = Vector2(960, 540);

  @override
  double get killPlaneY => 620;

  List<TraversalSegment> get requiredTraversalSegments => isBossRoom
      ? <TraversalSegment>[
          TraversalSegment(
            id: '${region.name}.boss.arena-floor',
            rise: 0,
            gap: 0,
            landingWidth: 960,
          ),
        ]
      : <TraversalSegment>[
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
        ];

  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2 respawnPointFor(Vector2 playerPosition) => playerSpawn.clone();

  @override
  Vector2 cameraTargetFor(Vector2 playerPosition) {
    if (isBossIntroActive) return Vector2(585, 250);
    final boss = _boss;
    if (_bossEncounterStarted && boss != null && boss.isActive) {
      return Vector2(playerPosition.x * .58 + boss.position.x * .42, 270);
    }
    return Vector2(480, 270);
  }

  @override
  double cameraZoomFor(Vector2 playerPosition) {
    if (isBossIntroActive) return 1.32;
    if (_bossEncounterStarted && (_boss?.isActive ?? false)) return 1.08;
    return 1;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(RoomBackdropComponent(backdropStyle, worldSize: worldSize));
    _buildGeometry();
    await addAll(_surfaces);
    await _addRoomFeatures();
    if (nodeId == firstNode) {
      final checkpoint = CampaignCheckpointComponent(
        position: Vector2(360, _floorY),
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
      _surface(0, 0, 24, 540, boundary: true),
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
    style: surfaceStyle,
  );

  Future<void> _addRoomFeatures() async {
    if (isBossRoom) return;
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

  Future<void> _addCombatEncounter() async {
    if (progress.clearedEncounterIds.contains(encounterId)) return;
    final specs = switch (nodeId) {
      CampaignNodeId.temporalAscent =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.tickRunner, 270, 438),
          (PlatformerEnemyArchetype.echoBat, 700, 350),
        ],
      CampaignNodeId.temporalFracture =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.delaySniper, 250, 390),
          (PlatformerEnemyArchetype.tickRunner, 700, 438),
        ],
      CampaignNodeId.temporalPendulum =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.rewindSkater, 270, 438),
          (PlatformerEnemyArchetype.echoBat, 700, 350),
        ],
      CampaignNodeId.collisionCompression =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.vectorRam, 270, 438),
          (PlatformerEnemyArchetype.polarityDrone, 700, 350),
        ],
      CampaignNodeId.collisionFracture =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.phaseMimic, 250, 390),
          (PlatformerEnemyArchetype.vectorRam, 700, 438),
        ],
      CampaignNodeId.collisionMerge =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.shardLobber, 270, 390),
          (PlatformerEnemyArchetype.polarityDrone, 700, 350),
        ],
      _ => const <(PlatformerEnemyArchetype, double, double)>[],
    };
    for (final spec in specs) {
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
    final x = switch (encounterId) {
      0 => 830.0,
      1 => 560.0,
      _ => 170.0,
    };
    final terminal = QaRecordTerminalComponent(
      position: Vector2(x, _floorY - 6),
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
      await _spawnForwardDoor();
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
      position: Vector2(70, _floorY),
      labelLocalizationKey: nodeId == firstNode
          ? 'interaction.returnOverflowJunction'
          : 'interaction.previousRoom',
      targetEntry: CampaignNodeEntry.east,
    );
    if (nodeId == firstNode &&
        game.campaignExploration.unlockedShortcutIds.contains(hubAccessId)) {
      await _spawnDoor(
        target: CampaignNodeId.bootSector,
        position: Vector2(190, _floorY),
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
      position: Vector2(890, _floorY),
      labelLocalizationKey: nodeId == thirdNode
          ? 'interaction.enterBossRoom'
          : 'interaction.nextRoom',
      targetEntry: CampaignNodeEntry.west,
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
      unawaited(_spawnForwardDoor());
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
      position: Vector2(500, _floorY - 6),
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
    await add(
      BossNameCardComponent(
        center: Vector2(480, 145),
        title: game.localization.text('boss.coreSignatureAcquired'),
        subtitle:
            '${game.localization.text(regionKey)} // '
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
