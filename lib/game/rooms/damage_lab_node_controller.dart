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
import 'package:patch_world/game/items/campaign_loadout_reward_catalog.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_room_status.dart';
import 'package:patch_world/game/rooms/maps/damage_lab_room_layout.dart';
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
    required this.layout,
  }) : assert(_supportedNodes.contains(nodeId)),
       assert(layout.nodeId == nodeId);

  static const Set<CampaignNodeId> _supportedNodes = <CampaignNodeId>{
    CampaignNodeId.damageWorkshop,
    CampaignNodeId.damageAssembly,
    CampaignNodeId.damageOverflow,
    CampaignNodeId.overflowWarden,
  };
  final CampaignNodeId nodeId;
  final CampaignNodeEntry entry;
  final DamageLabFloorState progress;
  final DamageLabRoomLayout layout;
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

  bool get usesBackdropAlignedGeometry => layout.isBackdropAligned;

  List<Rect> get backdropAlignedPlatformBounds => List<Rect>.unmodifiable(
    usesBackdropAlignedGeometry
        ? layout.surfaces.map((surface) => surface.bounds)
        : const <Rect>[],
  );

  String? get environmentAsset => layout.environmentAsset;

  @override
  Vector2 get playerSpawn => layout.spawnFor(entry).toVector2();

  @override
  late final Vector2 worldSize = layout.size;

  @override
  double get killPlaneY => layout.killPlaneY;

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
      layout.enemies
          .map((enemy) => (enemy.archetype, enemy.position.x, enemy.position.y))
          .toList(growable: false);

  List<TraversalSegment> get requiredTraversalSegments =>
      layout.requiredTraversalSegments;

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
    return layout.camera.zoom;
  }

  @override
  double get horizontalCameraLead => layout.camera.horizontalLead;

  @override
  double get horizontalCameraDeadZone => layout.camera.horizontalDeadZone;

  @override
  double get verticalCameraDeadZone => layout.camera.verticalDeadZone;

  @override
  double get cameraFollowResponsiveness => layout.camera.followResponsiveness;

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
    final checkpointAnchor = layout.anchor(DamageLabAnchorId.checkpoint);
    if (checkpointAnchor != null) {
      final checkpoint = CampaignCheckpointComponent(
        position: checkpointAnchor.toVector2(),
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
    _surfaces.addAll(
      layout.surfaces.map(
        (surface) => _surface(
          surface.bounds.left,
          surface.bounds.top,
          surface.bounds.width,
          surface.bounds.height,
          boundary: surface.isBoundary,
          renderArtwork: surface.renderArtwork,
        ),
      ),
    );
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
    for (final feature in layout.features) {
      switch (feature.kind) {
        case DamageLabFeatureKind.jumpPad:
          features.add(
            JumpPadComponent(position: feature.position.toVector2()),
          );
        case DamageLabFeatureKind.pulsingLaser:
          features.add(
            PulsingLaserComponent(
              position: feature.position.toVector2(),
              size: feature.size.toVector2(),
              sourceId: feature.sourceId!,
              phaseOffset: feature.phaseOffset,
            ),
          );
        case DamageLabFeatureKind.spikeHazard:
          features.add(
            RoomHazardComponent(
              position: feature.position.toVector2(),
              size: feature.size.toVector2(),
              style: RoomHazardStyle.spikes,
              sourceId: feature.sourceId!,
            ),
          );
        case DamageLabFeatureKind.bossSeal:
          // Boss seals are conditional collision objects created with the
          // encounter so revisiting a defeated boss room leaves them open.
          break;
      }
    }
    await addAll(features);
  }

  Future<void> _addCombatEncounter() async {
    if (progress.clearedEncounterIds.contains(encounterId)) return;
    for (final spec in layout.enemies) {
      late final PlatformerEnemyComponent enemy;
      enemy = PlatformerEnemyComponent(
        archetype: spec.archetype,
        position: spec.position.toVector2(),
        onDefeated: _onEnemyDefeated,
      );
      _enemyEncounterIds[enemy] = encounterId;
      await add(enemy);
    }
  }

  Future<void> _addTerrainPulseRoute() async {
    final pulse = layout.terrainPulse;
    if (pulse == null) return;
    final bridge = TerrainPulseBridgeComponent(
      position: Vector2(pulse.bridgeBounds.left, pulse.bridgeBounds.top),
      size: Vector2(pulse.bridgeBounds.width, pulse.bridgeBounds.height),
      style: PlatformSurfaceStyle.damage,
    );
    final node = TerrainPulseNodeComponent(
      position: pulse.nodePosition.toVector2(),
      nodeId: pulse.routeId,
      onActivated: bridge.activate,
      accentColor: const Color(0xFF36E1FF),
    );
    _surfaces.add(bridge);
    _terrainPulseNode = node;
    await addAll(<Component>[bridge, node]);
    if (game.campaignExploration.activatedTerrainNodeIds.contains(
      pulse.routeId,
    )) {
      node.restoreActivated();
    }
  }

  Future<void> _addServiceRoomFeatures() async {
    final repairAnchor = layout.anchor(DamageLabAnchorId.repairStation);
    if (repairAnchor != null) {
      final station = CampaignRepairStationComponent(
        position: repairAnchor.toVector2(),
        used: progress.repairStationUsed,
        onUsed: () => progress.repairStationUsed = true,
        accentColor: const Color(0xFF36E1FF),
      );
      _repairStation = station;
      await add(station);
    }
    final loadoutAnchor = layout.anchor(DamageLabAnchorId.loadoutEvent);
    if (loadoutAnchor != null) {
      final terminal = LoadoutEventTerminalComponent(
        position: loadoutAnchor.toVector2(),
        resolved: progress.loadoutEventResolved,
        eventId: CampaignLoadoutEventId.damageLab,
        onResolved: () => progress.loadoutEventResolved = true,
        accentColor: const Color(0xFFFF4FD8),
      );
      _loadoutEvent = terminal;
      await add(terminal);
    }
  }

  Future<void> _addQaRecord() async {
    if (progress.collectedRecordIds.contains(encounterId)) return;
    final anchor = layout.requireAnchor(DamageLabAnchorId.qaRecord);
    final terminal = QaRecordTerminalComponent(
      position: anchor.toVector2(),
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
      final seals = layout.features
          .where((feature) => feature.kind == DamageLabFeatureKind.bossSeal)
          .map(
            (feature) => BossSealGateComponent(
              position: feature.position.toVector2(),
              size: feature.size.toVector2(),
              style: PlatformSurfaceStyle.damage,
            ),
          )
          .toList(growable: false);
      _bossSeals.addAll(seals);
      _surfaces.addAll(seals);
      await addAll(seals);
      final bossSpawn = layout.requireAnchor(DamageLabAnchorId.bossSpawn);
      final boss = OverflowWardenBossComponent(
        position: bossSpawn.toVector2(),
        arenaFloorY: bossSpawn.y + 56,
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
      position: layout.requireAnchor(DamageLabAnchorId.backDoor).toVector2(),
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
    final target = CampaignWorldGraph.linearNextNode[nodeId];
    if (target == null) {
      throw StateError('Damage Lab node has no forward route: $nodeId');
    }
    final door = CampaignDoorComponent(
      position: layout.requireAnchor(DamageLabAnchorId.forwardDoor).toVector2(),
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
    final socket = layout.secretDoorFor(weapon);
    final requirement = switch (weapon) {
      PlayerWeapon.sword => CampaignRouteRequirement.swordDash,
      PlayerWeapon.gauntlet => CampaignRouteRequirement.gauntletDoubleJump,
      PlayerWeapon.gun => CampaignRouteRequirement.gunRangedSwitch,
    };
    final connection = game.campaignWorld
        .connectionsFrom(nodeId)
        .singleWhere((candidate) => candidate.requirement == requirement);
    final target = connection.other(nodeId);
    final labelKey = switch (target) {
      CampaignNodeId.damageDashCache => 'interaction.enterDashCache',
      CampaignNodeId.damageUpperArchive => 'interaction.enterUpperArchive',
      CampaignNodeId.damageTurretControl => 'interaction.enterTurretControl',
      _ => throw StateError('Unsupported Damage Lab secret node: $target'),
    };
    final door = CampaignDoorComponent(
      position: socket.position.toVector2(),
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
    final door = CampaignDoorComponent(
      position: layout
          .requireAnchor(DamageLabAnchorId.maintenanceShortcut)
          .toVector2(),
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
      position: layout
          .requireAnchor(DamageLabAnchorId.regionBranchDoor)
          .toVector2(),
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
      position: layout.requireAnchor(DamageLabAnchorId.questReward).toVector2(),
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
      position: layout.requireAnchor(DamageLabAnchorId.bossReward).toVector2(),
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
      position: layout
          .requireAnchor(DamageLabAnchorId.exitTerminal)
          .toVector2(),
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
