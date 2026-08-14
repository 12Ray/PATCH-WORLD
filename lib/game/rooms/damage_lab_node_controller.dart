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
  final List<CampaignDoorComponent> _branchDoors = <CampaignDoorComponent>[];
  CampaignCheckpointComponent? _checkpoint;
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

  @override
  Vector2 get playerSpawn =>
      entry == CampaignNodeEntry.west ? Vector2(166, 448) : Vector2(794, 448);

  @override
  final Vector2 worldSize = Vector2(960, 540);

  @override
  double get killPlaneY => 620;

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

  List<TraversalSegment> get requiredTraversalSegments => switch (nodeId) {
    CampaignNodeId.damageWorkshop => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.workshop.gap-a',
        rise: 0,
        gap: 90,
        landingWidth: 230,
      ),
      TraversalSegment(
        id: 'damage.workshop.gap-b',
        rise: 0,
        gap: 90,
        landingWidth: 220,
      ),
    ],
    CampaignNodeId.damageAssembly => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.assembly.gap-a',
        rise: 0,
        gap: 100,
        landingWidth: 220,
      ),
      TraversalSegment(
        id: 'damage.assembly.gap-b',
        rise: 0,
        gap: 100,
        landingWidth: 180,
      ),
    ],
    CampaignNodeId.damageOverflow => const <TraversalSegment>[
      TraversalSegment(
        id: 'damage.overflow.gap-a',
        rise: 0,
        gap: 100,
        landingWidth: 250,
      ),
      TraversalSegment(
        id: 'damage.overflow.gap-b',
        rise: 0,
        gap: 100,
        landingWidth: 210,
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
    await add(
      RoomBackdropComponent(RoomBackdropStyle.damage, worldSize: worldSize),
    );
    _buildGeometry();
    await addAll(_surfaces);
    await _addRoomFeatures();
    if (nodeId == CampaignNodeId.damageWorkshop) {
      final checkpoint = CampaignCheckpointComponent(
        position: Vector2(190, _floorY),
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
      _surface(0, 0, 24, 540, boundary: true),
      _surface(936, 0, 24, 540, boundary: true),
      ...switch (nodeId) {
        CampaignNodeId.damageWorkshop => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 330, 56),
          _surface(420, _floorY, 230, 56),
          _surface(740, _floorY, 220, 56),
          _surface(170, 404, 140, 20),
          _surface(480, 332, 150, 20),
        ],
        CampaignNodeId.damageAssembly => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 360, 56),
          _surface(460, _floorY, 220, 56),
          _surface(780, _floorY, 180, 56),
          _surface(120, 412, 160, 20),
          ConveyorPlatformComponent(
            position: Vector2(400, 340),
            size: Vector2(160, 20),
            direction: -1,
          ),
          _surface(690, 412, 150, 20),
        ],
        CampaignNodeId.damageOverflow => <PlatformSurfaceComponent>[
          _surface(0, _floorY, 300, 56),
          _surface(400, _floorY, 250, 56),
          _surface(750, _floorY, 210, 56),
          _surface(90, 400, 150, 20),
          _surface(405, 328, 150, 20),
          _surface(720, 400, 150, 20),
        ],
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
  }) => PlatformSurfaceComponent(
    position: Vector2(x, y),
    size: Vector2(width, height),
    isBoundary: boundary,
    style: PlatformSurfaceStyle.damage,
  );

  Future<void> _addRoomFeatures() async {
    final features = <Component>[];
    switch (nodeId) {
      case CampaignNodeId.damageWorkshop:
        features.addAll(<Component>[
          DamagePitComponent(
            position: Vector2(330, _floorY),
            size: Vector2(90, 56),
          ),
          DamagePitComponent(
            position: Vector2(650, _floorY),
            size: Vector2(90, 56),
          ),
          JumpPadComponent(position: Vector2(430, _floorY - 12)),
        ]);
      case CampaignNodeId.damageAssembly:
        features.addAll(<Component>[
          DamagePitComponent(
            position: Vector2(360, _floorY),
            size: Vector2(100, 56),
          ),
          DamagePitComponent(
            position: Vector2(680, _floorY),
            size: Vector2(100, 56),
          ),
        ]);
      case CampaignNodeId.damageOverflow:
        features.addAll(<Component>[
          DamagePitComponent(
            position: Vector2(300, _floorY),
            size: Vector2(100, 56),
          ),
          DamagePitComponent(
            position: Vector2(650, _floorY),
            size: Vector2(100, 56),
          ),
          PulsingLaserComponent(
            position: Vector2(558, 356),
            size: Vector2(12, 128),
            sourceId: 'hazard.damage-lab.overflow.optional-laser',
            phaseOffset: 1.1,
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
    final specs = switch (nodeId) {
      CampaignNodeId.damageWorkshop =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.patchMite, 265, 438),
          (PlatformerEnemyArchetype.checksumHopper, 560, 438),
        ],
      CampaignNodeId.damageAssembly =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.pulseTurret, 260, 438),
          (PlatformerEnemyArchetype.checksumHopper, 585, 438),
        ],
      CampaignNodeId.damageOverflow =>
        const <(PlatformerEnemyArchetype, double, double)>[
          (PlatformerEnemyArchetype.patchMite, 245, 438),
          (PlatformerEnemyArchetype.repairLeech, 540, 438),
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

  Future<void> _addQaRecord() async {
    if (progress.collectedRecordIds.contains(encounterId)) return;
    final x = switch (nodeId) {
      CampaignNodeId.damageWorkshop => 835.0,
      CampaignNodeId.damageAssembly => 565.0,
      CampaignNodeId.damageOverflow => 165.0,
      _ => 480.0,
    };
    final terminal = QaRecordTerminalComponent(
      position: Vector2(x, _floorY - 6),
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
      position: Vector2(70, _floorY),
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
      position: Vector2(890, _floorY),
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
        Vector2(300, _floorY),
        'interaction.enterDashCache',
      ),
      PlayerWeapon.gauntlet => (
        CampaignNodeId.damageUpperArchive,
        Vector2(480, 340),
        'interaction.enterUpperArchive',
      ),
      PlayerWeapon.gun => (
        CampaignNodeId.damageTurretControl,
        Vector2(610, _floorY),
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
    final collisionDoor = CampaignDoorComponent(
      position: Vector2(430, _floorY),
      labelLocalizationKey: 'interaction.enterCollisionArchive',
      onInteract: () => game.travelToCampaignNode(
        CampaignNodeId.collisionCompression,
        entry: CampaignNodeEntry.west,
      ),
    );
    _branchDoors.addAll(<CampaignDoorComponent>[temporalDoor, collisionDoor]);
    await addAll(_branchDoors);
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
      position: Vector2(470, _floorY - 6),
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
    if (_backDoor?.tryEnter(player) ?? false) return true;
    if (_secretDoor?.tryEnter(player) ?? false) return true;
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
