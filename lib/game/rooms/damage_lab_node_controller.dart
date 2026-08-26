import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';
import 'package:patch_world/game/campaign/story_map_art_contract.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_attack_coordinator.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_service_components.dart';
import 'package:patch_world/game/components/environment/patch_exit_terminal_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/qa_record_terminal_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
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
import 'package:patch_world/services/audio_service.dart';

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
        CampaignNodeTravelGuard,
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
  final Map<PlatformerEnemyComponent, String> _enemyIds =
      <PlatformerEnemyComponent, String>{};
  final Map<String, PlatformerEnemyComponent> _enemiesById =
      <String, PlatformerEnemyComponent>{};
  final Set<PlatformerEnemyComponent> _defeatedEnemies =
      <PlatformerEnemyComponent>{};
  final EnemyAttackCoordinator _enemyAttackCoordinator =
      EnemyAttackCoordinator();
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
  final List<WardenPressureVentComponent> _wardenPressureVents =
      <WardenPressureVentComponent>[];
  final List<WardenPhasePlatformComponent> _wardenPhasePlatforms =
      <WardenPhasePlatformComponent>[];
  final List<WardenSafeZoneComponent> _wardenSafeZones =
      <WardenSafeZoneComponent>[];
  final List<WardenSummonGateComponent> _wardenSummonGates =
      <WardenSummonGateComponent>[];
  final Set<PlatformerEnemyComponent> _wardenSummons =
      <PlatformerEnemyComponent>{};
  final Set<int> _wardenSummonedPhases = <int>{};
  bool _bossEncounterStarted = false;
  OverflowWardenPhase? _lastBossAudioPhase;
  bool _bossVictoryCuePlayed = false;
  bool _patchSelectionOpened = false;
  CampaignEncounterDirector? _encounterDirector;
  double _bossIntroRemaining = 0;
  double _bossRewardDiscoveryRemaining = 0;
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

  List<Rect> get authoredPlatformBounds => List<Rect>.unmodifiable(<Rect>[
    ...layout.surfaces
        .where((surface) => !surface.isBoundary)
        .map((surface) => surface.bounds),
    ...?layout.bossMechanic?.phasePlatforms.map((platform) => platform.bounds),
  ]);

  String? get environmentAsset => layout.environmentAsset;

  StoryMapArtSpec get mapArtSpec => StoryMapArtCatalog.specFor(nodeId);

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
  CampaignEncounterPhase? get encounterPhase => _encounterDirector?.phase;
  int get activeWaveIndex => _encounterDirector?.waveIndex ?? -1;
  int get activeEncounterEnemyCount =>
      _encounterDirector?.activeEnemyCount ?? 0;
  bool get isEncounterSealed => _encounterDirector?.isSealed ?? false;
  List<PlatformerEnemyComponent> get activeEncounterEnemies => _enemiesById
      .values
      .where((enemy) => enemy.isActiveThreat)
      .toList(growable: false);
  bool get isBossIntroActive => _bossIntroRemaining > 0;
  bool get isBossRewardDiscoveryActive => _bossRewardDiscoveryRemaining > 0;
  bool get hasExitTerminal => _exitTerminal != null;
  OverflowWardenBossComponent? get boss => _boss;
  BossArenaPresentationComponent? get bossArenaPresentation =>
      _bossArenaPresentation;
  List<BossSealGateComponent> get bossSeals =>
      List<BossSealGateComponent>.unmodifiable(_bossSeals);
  List<WardenPressureVentComponent> get wardenPressureVents =>
      List<WardenPressureVentComponent>.unmodifiable(_wardenPressureVents);
  List<WardenPhasePlatformComponent> get wardenPhasePlatforms =>
      List<WardenPhasePlatformComponent>.unmodifiable(_wardenPhasePlatforms);
  List<WardenSafeZoneComponent> get wardenSafeZones =>
      List<WardenSafeZoneComponent>.unmodifiable(_wardenSafeZones);
  List<WardenSummonGateComponent> get wardenSummonGates =>
      List<WardenSummonGateComponent>.unmodifiable(_wardenSummonGates);
  List<PlatformerEnemyComponent> get activeWardenSummons => _wardenSummons
      .where((enemy) => enemy.isMounted && !enemy.isRemoving)
      .toList(growable: false);

  List<(PlatformerEnemyArchetype, double, double)> get combatEncounterSpecs =>
      layout.enemies
          .map((enemy) => (enemy.archetype, enemy.position.x, enemy.position.y))
          .toList(growable: false);

  @override
  bool canLeaveCampaignNode(CampaignNodeId targetNode) => !isEncounterSealed;

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
    if (isBossIntroActive) return worldSize / 2;
    final boss = _boss;
    if (_bossEncounterStarted && boss != null && boss.isActive) {
      return Vector2(
        (playerPosition.x * .58 + boss.position.x * .42)
            .clamp(320, worldSize.x - 320)
            .toDouble(),
        (playerPosition.y * .58 + boss.position.y * .42 - 96)
            .clamp(240, worldSize.y - 240)
            .toDouble(),
      );
    }
    final director = _encounterDirector;
    final encounter = layout.encounter;
    if (director?.usesCombatCamera ?? false) {
      if (encounter == null) {
        throw StateError('$nodeId is missing its encounter camera contract.');
      }
      final activeEnemies = activeEncounterEnemies;
      PlatformerEnemyComponent? nearest;
      var nearestDistance = double.infinity;
      for (final enemy in activeEnemies) {
        final distance = playerPosition.distanceToSquared(enemy.position);
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearest = enemy;
        }
      }
      final target = nearest == null
          ? Vector2(playerPosition.x, playerPosition.y - 68)
          : Vector2(
              playerPosition.x * .58 + nearest.position.x * .42,
              (playerPosition.y - 54) * .58 + nearest.position.y * .42,
            );
      final zone = encounter.combatCamera.zone;
      return Vector2(
        target.x.clamp(zone.left, zone.right).toDouble(),
        target.y.clamp(zone.top, zone.bottom).toDouble(),
      );
    }
    return nodeId != CampaignNodeId.overflowWarden
        ? Vector2(playerPosition.x, playerPosition.y - 68)
        : worldSize / 2;
  }

  @override
  double cameraZoomFor(Vector2 playerPosition) {
    if (isBossIntroActive) return .94;
    if (_bossEncounterStarted && (_boss?.isActive ?? false)) {
      return layout.camera.zoom;
    }
    if (_encounterDirector?.usesCombatCamera ?? false) {
      return layout.encounter!.combatCamera.zoom;
    }
    return layout.camera.zoom;
  }

  @override
  double get horizontalCameraLead =>
      isEncounterSealed ? 0 : layout.camera.horizontalLead;

  @override
  double get horizontalCameraDeadZone =>
      isEncounterSealed ? 42 : layout.camera.horizontalDeadZone;

  @override
  double get verticalCameraDeadZone =>
      isEncounterSealed ? 30 : layout.camera.verticalDeadZone;

  @override
  double get cameraFollowResponsiveness => isEncounterSealed
      ? math.max(8, layout.camera.followResponsiveness)
      : layout.camera.followResponsiveness;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await add(
      StoryRoomLayersComponent(
        theme: mapArtSpec.theme,
        motif: mapArtSpec.motif,
        worldSize: worldSize,
      ),
    );
    _buildGeometry();
    await addAll(_surfaces);
    if (nodeId == CampaignNodeId.overflowWarden) {
      await _addWardenMechanics();
    }
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

  Future<void> _addWardenMechanics() async {
    final mechanic = layout.bossMechanic;
    if (mechanic == null) {
      throw StateError('Overflow Warden room is missing bossMechanic.');
    }

    _wardenPressureVents.addAll(
      mechanic.pressureVents.map(WardenPressureVentComponent.new),
    );
    _wardenPhasePlatforms.addAll(
      mechanic.phasePlatforms.map(WardenPhasePlatformComponent.new),
    );
    _wardenSafeZones.addAll(
      mechanic.safeZones.map(WardenSafeZoneComponent.new),
    );
    _wardenSummonGates.addAll(
      mechanic.summonGates.indexed.map(
        (entry) => WardenSummonGateComponent(
          spec: entry.$2,
          opensInPhase: entry.$1 + 2,
        ),
      ),
    );
    _surfaces.addAll(_wardenPhasePlatforms);
    await addAll(<Component>[
      ..._wardenSafeZones,
      ..._wardenPressureVents,
      ..._wardenPhasePlatforms,
      ..._wardenSummonGates,
    ]);
    if (progress.bossDefeated) {
      _clearWardenMechanics();
    } else {
      _setWardenMechanicPhase(0);
    }
  }

  void _setWardenMechanicPhase(int phase) {
    for (final vent in _wardenPressureVents) {
      vent.setBossPhase(phase);
    }
    for (final platform in _wardenPhasePlatforms) {
      platform.setBossPhase(phase);
    }
    for (final gate in _wardenSummonGates) {
      gate.setBossPhase(phase);
    }
    if (phase == 2 || phase == 3) unawaited(_spawnWardenSummon(phase));
  }

  Future<void> _spawnWardenSummon(int phase) async {
    if (progress.bossDefeated || !_wardenSummonedPhases.add(phase)) return;
    final gateIndex = phase - 2;
    if (gateIndex < 0 || gateIndex >= _wardenSummonGates.length) return;
    late final PlatformerEnemyComponent summon;
    summon = PlatformerEnemyComponent(
      archetype: PlatformerEnemyArchetype.repairLeech,
      position: _wardenSummonGates[gateIndex].spec.position.toVector2(),
      onDefeated: (enemy) => _wardenSummons.remove(enemy),
      attackCoordinator: _enemyAttackCoordinator,
      onRepairAlly: (amount) {
        final boss = _boss;
        if (boss == null || !boss.isActive || boss.isPhaseTransitioning) {
          return false;
        }
        if (summon.position.distanceToSquared(boss.position) > 250 * 250) {
          return false;
        }
        boss.receiveSupportHealing(amount);
        return true;
      },
    );
    _wardenSummons.add(summon);
    await add(summon);
    if (progress.bossDefeated || _boss == null) {
      _wardenSummons.remove(summon);
      if (!summon.isRemoving) summon.removeFromParent();
    }
  }

  void _clearWardenMechanics() {
    for (final vent in _wardenPressureVents) {
      vent.markCleared();
    }
    for (final platform in _wardenPhasePlatforms) {
      platform.markCleared();
    }
    for (final gate in _wardenSummonGates) {
      gate.markCleared();
    }
    for (final summon in _wardenSummons.toList(growable: false)) {
      if (!summon.isRemoving) summon.removeFromParent();
    }
    _wardenSummons.clear();
  }

  Future<void> _addCombatEncounter() async {
    final encounter = layout.encounter;
    if (encounter == null) {
      throw StateError('$nodeId is missing an encounter contract.');
    }
    final alreadyCleared = progress.clearedEncounterIds.contains(encounterId);
    _encounterDirector = CampaignEncounterDirector(
      spec: encounter,
      initiallyCleared: alreadyCleared,
      reverseWaves: entry == CampaignNodeEntry.east,
      onWaveActivated: _activateEncounterWave,
      onClearBeatStarted: _showEncounterClearBeat,
      onCleared: _finishEncounterClear,
      onPhaseChanged: (_) => game.publishUiSnapshot(force: true),
    );
    if (alreadyCleared) return;
    for (final spec in layout.enemies) {
      late final PlatformerEnemyComponent enemy;
      enemy = PlatformerEnemyComponent(
        archetype: spec.archetype,
        position: spec.position.toVector2(),
        onDefeated: _onEnemyDefeated,
        startsDormant: true,
        attackCoordinator: _enemyAttackCoordinator,
      );
      _enemyIds[enemy] = spec.id;
      _enemiesById[spec.id] = enemy;
      await add(enemy);
    }
  }

  void _activateEncounterWave(int waveIndex, List<String> enemyIds) {
    for (final enemyId in enemyIds) {
      final enemy = _enemiesById[enemyId];
      if (enemy == null) {
        throw StateError('$nodeId wave $waveIndex has no enemy "$enemyId".');
      }
      enemy.activateEncounter();
    }
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
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
      identity: BossArenaIdentity.overflowWarden,
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
      final orderedSeals = seals.toList()
        ..sort(
          (first, second) => first.position.x.compareTo(second.position.x),
        );
      final bossArenaBounds = Rect.fromLTRB(
        orderedSeals.first.position.x + orderedSeals.first.size.x,
        0,
        orderedSeals.last.position.x,
        worldSize.y,
      );
      final bossSpawn = layout.requireAnchor(DamageLabAnchorId.bossSpawn);
      final boss = OverflowWardenBossComponent(
        position: bossSpawn.toVector2(),
        arenaFloorY: bossSpawn.y + 56,
        arenaBounds: bossArenaBounds,
        onDefeated: _onBossDefeated,
        onPhaseChanged: _onBossPhaseChanged,
      );
      _boss = boss;
      await add(boss);
      return;
    }
    if (!progress.bossRewardClaimed) {
      await _spawnBossReward();
    } else {
      await _spawnExitTerminal();
    }
  }

  Future<void> _spawnAvailableDoors() async {
    if (nodeId != CampaignNodeId.overflowWarden || progress.bossDefeated) {
      await _spawnBackDoor();
    }
    if (nodeId != CampaignNodeId.overflowWarden) {
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
      isUnlockedResolver: () => !isEncounterSealed,
      lockedLabelLocalizationKeyResolver: () => 'interaction.clearThreats',
      onLockedInteract: _onRoomExitLocked,
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
      isUnlockedResolver: () =>
          !isEncounterSealed &&
          progress.clearedEncounterIds.contains(encounterId),
      lockedLabelLocalizationKeyResolver: () => 'interaction.clearThreats',
      onLockedInteract: _onRoomExitLocked,
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
      isUnlockedResolver: () => !isEncounterSealed,
      lockedLabelLocalizationKeyResolver: () => 'interaction.clearThreats',
      onLockedInteract: _onRoomExitLocked,
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
    final enemyId = _enemyIds[enemy];
    if (enemyId == null) {
      throw StateError('$nodeId defeated an unregistered encounter enemy.');
    }
    _defeatedCount += 1;
    game.runMetrics.recordOverflow();
    _encounterDirector?.notifyEnemyDefeated(enemyId);
    game.publishUiSnapshot(force: true);
  }

  void _showEncounterClearBeat() {
    add(
      BossNameCardComponent(
        center: game.world.player.position + Vector2(0, -145),
        title: game.localization.text('objective.roomTaskComplete'),
        subtitle: game.localization.text(
          nodeId == CampaignNodeId.damageOverflow
              ? 'interaction.enterBossRoom'
              : 'interaction.nextRoom',
        ),
        accentColor: const Color(0xFF45F3A6),
        style: BossNameCardStyle.victory,
        duration: layout.encounter!.clearBeatSeconds,
      ),
    );
    game.publishUiSnapshot(force: true);
  }

  void _finishEncounterClear() {
    // Progress and its reward are committed together after the clear beat.
    // Restarting during the beat therefore replays the encounter instead of
    // leaving behind a permanently cleared room with an unclaimed reward.
    if (!progress.clearedEncounterIds.add(encounterId)) return;
    if (game.runItems.contains(RunItemId.conduitHeart)) {
      game.world.player.restoreIntegrity(1);
    }
    if (nodeId == CampaignNodeId.damageAssembly) {
      unawaited(_spawnSecretDoor());
    }
    if (nodeId == CampaignNodeId.damageOverflow) {
      game.campaignExploration.unlockShortcut(
        CampaignWorldGraph.damageMaintenanceShortcutId,
      );
      unawaited(_spawnMaintenanceShortcutDoor());
    }
    if (!progress.claimedBuildRewardIds.contains(encounterId)) {
      unawaited(
        Future<void>.microtask(
          () => game.openRoomOneBuildSelection(encounterId),
        ),
      );
    }
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
  }

  void _onRoomExitLocked() {
    game.triggerImpactFeedback();
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
    game.setCinematicInputLocked(true);
    final banner = BossNameCardComponent(
      center: Vector2(worldSize.x / 2, 145),
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
    _playWardenVictoryCue();
    progress.bossDefeated = true;
    _boss = null;
    game.runMetrics.recordOverflow();
    game.campaignExploration.collectCoreSignature(CampaignRegion.damageLab);
    _bossArenaPresentation?.markCleared();
    _clearWardenMechanics();
    for (final seal in _bossSeals) {
      seal.unlock();
    }
    unawaited(_showCoreSignatureCard());
    unawaited(_spawnBackDoor());
    unawaited(_spawnBossReward());
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
        _bossRewardDiscoveryRemaining = 2.6;
      },
    );
    _bossReward = reward;
    await add(reward);
  }

  Future<void> _showCoreSignatureCard() async {
    await add(
      BossNameCardComponent(
        center: Vector2(worldSize.x / 2, 145),
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
    _playWardenPhaseCue(phase);
    switch (phase) {
      case OverflowWardenPhase.dormant:
        _setWardenMechanicPhase(0);
        break;
      case OverflowWardenPhase.intro:
        _setWardenMechanicPhase(0);
        _bossArenaPresentation?.beginIntro();
      case OverflowWardenPhase.shielded:
        _setWardenMechanicPhase(1);
        _bossArenaPresentation?.beginPhaseOne();
      case OverflowWardenPhase.breached:
        _setWardenMechanicPhase(2);
        _bossArenaPresentation?.beginPhaseTwo();
      case OverflowWardenPhase.critical:
        _setWardenMechanicPhase(3);
        _bossArenaPresentation?.beginPhaseThree();
      case OverflowWardenPhase.overflowing:
        _clearWardenMechanics();
        _bossArenaPresentation?.beginPhaseThree();
      case OverflowWardenPhase.defeated:
        _clearWardenMechanics();
        _bossArenaPresentation?.markCleared();
    }
  }

  void _playWardenPhaseCue(OverflowWardenPhase phase) {
    if (_lastBossAudioPhase == phase) return;
    _lastBossAudioPhase = phase;
    switch (phase) {
      case OverflowWardenPhase.intro:
        unawaited(
          game.audio.playStoryBossIntro(StoryBossAudioIdentity.overflowWarden),
        );
      case OverflowWardenPhase.shielded:
        unawaited(
          game.audio.playStoryBossPhase(
            StoryBossAudioIdentity.overflowWarden,
            phase: 1,
          ),
        );
      case OverflowWardenPhase.breached:
        unawaited(
          game.audio.playStoryBossPhase(
            StoryBossAudioIdentity.overflowWarden,
            phase: 2,
          ),
        );
      case OverflowWardenPhase.critical:
        unawaited(
          game.audio.playStoryBossPhase(
            StoryBossAudioIdentity.overflowWarden,
            phase: 3,
          ),
        );
      case OverflowWardenPhase.defeated:
        _playWardenVictoryCue();
      case OverflowWardenPhase.dormant || OverflowWardenPhase.overflowing:
        break;
    }
  }

  void _playWardenVictoryCue() {
    if (_bossVictoryCuePlayed) return;
    _bossVictoryCuePlayed = true;
    unawaited(
      game.audio.playStoryBossVictory(StoryBossAudioIdentity.overflowWarden),
    );
  }

  Future<void> _spawnExitTerminal() async {
    if (_exitTerminal != null ||
        progress.patchApplied ||
        !progress.bossRewardClaimed) {
      return;
    }
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
    if (game.world.isReady && nodeId != CampaignNodeId.overflowWarden) {
      final director = _encounterDirector;
      if (director != null) {
        final player = game.world.player.position;
        director.tryTrigger(Offset(player.x, player.y));
        director.update(game.clock.realDt);
      }
    }
    if (game.world.isReady &&
        nodeId == CampaignNodeId.overflowWarden &&
        !progress.bossDefeated) {
      _startBossIntro();
    }
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
    if (_bossRewardDiscoveryRemaining > 0) {
      _bossRewardDiscoveryRemaining = math.max(
        0,
        _bossRewardDiscoveryRemaining - game.clock.realDt,
      );
      if (_bossRewardDiscoveryRemaining <= 0) {
        unawaited(_spawnExitTerminal());
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

/// Phase-driven floor vent for the Warden pressure hangar. The authored bounds
/// control both the warning plume and the damage check.
final class WardenPressureVentComponent extends PositionComponent
    with HasGameReference<PatchWorldGame> {
  WardenPressureVentComponent(this.spec)
    : super(
        position: Vector2(spec.bounds.left, spec.bounds.top),
        size: Vector2(spec.bounds.width, spec.bounds.height),
        priority: 7,
      );

  final DamageLabPressureVentSpec spec;
  static const double phaseEntryGraceSeconds = 1.1;
  int _bossPhase = 0;
  double _elapsed = 0;
  double _phaseGraceRemaining = 0;
  bool _burstActive = false;
  bool _damagedThisBurst = false;
  bool _cleared = false;

  bool get isEnabled => !_cleared && _bossPhase >= spec.activeFromPhase;
  bool get isBurstActive => isEnabled && _burstActive;
  double get phaseGraceRemaining => _phaseGraceRemaining;
  Rect get worldBounds => spec.bounds;

  void setBossPhase(int phase) {
    _bossPhase = phase;
    _elapsed = 0;
    _phaseGraceRemaining = phase > 0 ? phaseEntryGraceSeconds : 0;
    _burstActive = false;
    _damagedThisBurst = false;
  }

  void markCleared() {
    _cleared = true;
    _bossPhase = 0;
    _phaseGraceRemaining = 0;
    _burstActive = false;
    _damagedThisBurst = false;
  }

  @override
  void update(double dt) {
    final enemyDt = isMounted ? game.clock.enemyDt : dt;
    if (!isEnabled || enemyDt <= 0) {
      super.update(dt);
      return;
    }
    _elapsed += enemyDt;
    if (_phaseGraceRemaining > 0) {
      _phaseGraceRemaining = math.max(0, _phaseGraceRemaining - enemyDt);
      _burstActive = false;
      super.update(dt);
      return;
    }
    final period = _bossPhase >= 3 ? 1.8 : 2.4;
    final phaseTime = (_elapsed + spec.phaseOffset) % period;
    final nextBurstActive = phaseTime >= period - .28;
    if (nextBurstActive && !_burstActive) _damagedThisBurst = false;
    _burstActive = nextBurstActive;
    if (_burstActive && !_damagedThisBurst) {
      final player = game.world.player;
      if (spec.bounds
          .inflate(6)
          .contains(Offset(player.position.x, player.position.y))) {
        _damagedThisBurst = true;
        player.takeDamage(1, causeId: 'hazard.damage-lab.warden.pressure-vent');
      }
    }
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final base = Rect.fromLTWH(0, size.y - 20, size.x, 20);
    canvas.drawRect(base, Paint()..color = const Color(0xFF1B263A));
    for (double x = 16; x < size.x; x += 32) {
      canvas.drawCircle(
        Offset(x, size.y - 10),
        5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF36E1FF).withValues(alpha: .55),
      );
    }
    if (!isEnabled) {
      super.render(canvas);
      return;
    }
    final period = _bossPhase >= 3 ? 1.8 : 2.4;
    final phaseTime = (_elapsed + spec.phaseOffset) % period;
    final warning = (phaseTime / period).clamp(0.0, 1.0);
    final plume = Rect.fromLTWH(8, 0, size.x - 16, size.y - 18);
    canvas.drawRect(
      plume,
      Paint()
        ..shader = Gradient.linear(
          Offset(size.x / 2, size.y),
          Offset(size.x / 2, 0),
          <Color>[
            const Color(
              0xFFFF4FD8,
            ).withValues(alpha: _burstActive ? .72 : .08 + warning * .18),
            const Color(0xFFFFD35A).withValues(alpha: _burstActive ? .18 : 0),
          ],
        ),
    );
    super.render(canvas);
  }
}

/// A platform whose collision and walkable artwork switch on atomically at a
/// boss phase boundary.
final class WardenPhasePlatformComponent extends PlatformSurfaceComponent {
  WardenPhasePlatformComponent(this.spec)
    : super(
        position: Vector2(spec.bounds.left, spec.bounds.top),
        size: Vector2(spec.bounds.width, spec.bounds.height),
        style: PlatformSurfaceStyle.damage,
        renderArtwork: true,
      );

  final DamageLabPhasePlatformSpec spec;
  int _bossPhase = 0;
  bool _cleared = false;

  bool get isEnabled => _cleared || _bossPhase >= spec.activeFromPhase;
  bool get isVisiblySolid => isEnabled && !isRemoving;

  void setBossPhase(int phase) => _bossPhase = phase;

  void markCleared() {
    _cleared = true;
    _bossPhase = 3;
  }

  @override
  bool get isSolid => isEnabled && super.isSolid;

  @override
  void render(Canvas canvas) {
    if (isEnabled) {
      super.render(canvas);
      return;
    }
    for (double x = 16; x < size.x; x += 32) {
      canvas.drawCircle(
        Offset(x, size.y / 2),
        3,
        Paint()..color = const Color(0xFF36E1FF).withValues(alpha: .22),
      );
    }
  }
}

final class WardenSafeZoneComponent extends PositionComponent {
  WardenSafeZoneComponent(this.spec)
    : super(
        position: Vector2(spec.bounds.left, spec.bounds.top),
        size: Vector2(spec.bounds.width, spec.bounds.height),
        priority: 6,
      );

  final DamageLabSafeZoneSpec spec;
  Rect get worldBounds => spec.bounds;

  @override
  void render(Canvas canvas) {
    final marker = Rect.fromLTWH(0, size.y - 12, size.x, 10);
    canvas.drawRect(
      marker,
      Paint()..color = const Color(0xFF45F3A6).withValues(alpha: .16),
    );
    canvas.drawLine(
      marker.bottomLeft,
      marker.bottomRight,
      Paint()
        ..strokeWidth = 2
        ..color = const Color(0xFF45F3A6).withValues(alpha: .7),
    );
  }
}

final class WardenSummonGateComponent extends PositionComponent {
  WardenSummonGateComponent({required this.spec, required this.opensInPhase})
    : super(
        position: spec.position.toVector2(),
        size: Vector2.all(72),
        anchor: Anchor.center,
        priority: 6,
      );

  final DamageLabSummonGateSpec spec;
  final int opensInPhase;
  int _bossPhase = 0;
  bool _cleared = false;
  double _clock = 0;

  bool get isOpen => !_cleared && _bossPhase >= opensInPhase;

  void setBossPhase(int phase) => _bossPhase = phase;

  void markCleared() {
    _cleared = true;
    _bossPhase = 0;
  }

  @override
  void update(double dt) {
    _clock += dt;
    super.update(dt);
  }

  @override
  void render(Canvas canvas) {
    final center = Offset(size.x / 2, size.y / 2);
    final pulse = isOpen ? 1 + math.sin(_clock * 6).abs() * .14 : 1.0;
    canvas.drawCircle(
      center,
      25 * pulse,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = isOpen ? 4 : 2
        ..color = (isOpen ? const Color(0xFFFF4FD8) : const Color(0xFF41506B))
            .withValues(alpha: .82),
    );
    canvas.drawRect(
      Rect.fromCenter(center: center, width: 22, height: 34),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFFFFD35A).withValues(alpha: isOpen ? .9 : .32),
    );
  }
}
