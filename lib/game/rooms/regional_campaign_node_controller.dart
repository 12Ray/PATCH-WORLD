import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/campaign/regional_room_objective.dart';
import 'package:patch_world/game/campaign/story_map_art_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_attack_coordinator.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_room_objective_component.dart';
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
import 'package:patch_world/game/rooms/maps/regional_campaign_room_layout.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/services/audio_service.dart';

/// Connected campaign scene used by Temporal Hall and Collision Archive.
///
/// Both regions' three exploration rooms use authored 1920x1080 geometry.
/// Their boss arenas use a wide 1440x832 combat contract.
final class RegionalCampaignNodeController extends Component
    with HasGameReference<PatchWorldGame>
    implements
        PlatformerRoomGeometry,
        PlatformerRoomCameraTarget,
        PlatformerRoomCameraZoom,
        PlatformerRoomCameraLead,
        PlatformerRoomCameraFollow,
        PlatformerRoomSurfaceMotion,
        CampaignNodeRoom,
        CampaignNodeTravelGuard {
  RegionalCampaignNodeController({
    required this.nodeId,
    required this.entry,
    required this.progress,
    required this.layout,
  }) {
    if (!_supportedNodes.contains(nodeId)) {
      throw ArgumentError.value(nodeId, 'nodeId', 'Unsupported regional node');
    }
    if (layout.nodeId != nodeId) {
      throw ArgumentError(
        'Layout ${layout.nodeId.name} cannot mount as ${nodeId.name}.',
      );
    }
  }

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
  final RegionalCampaignRoomLayout layout;
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
  final List<CampaignRoomObjectiveComponent> _objectiveNodes =
      <CampaignRoomObjectiveComponent>[];
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
  Component? _objectiveHazard;
  PulsingLaserComponent? _objectiveLaser;
  MergingPlatformComponent? _objectiveMergePlatform;
  final List<BossSealGateComponent> _bossSeals = <BossSealGateComponent>[];
  final Map<String, Component> _bossMechanicComponents = <String, Component>{};
  final Map<String, PlatformSurfaceComponent> _bossMechanicSurfaces =
      <String, PlatformSurfaceComponent>{};
  final Set<int> _activatedObjectiveNodeIds = <int>{};
  bool _bossEncounterStarted = false;
  bool _patchSelectionOpened = false;
  CampaignEncounterDirector? _encounterDirector;
  double _bossIntroRemaining = 0;
  double _bossRewardDiscoveryRemaining = 0;
  double _objectiveTimeRemaining = 0;
  int _defeatedCount = 0;
  int _bossMechanicEpoch = 0;
  int? _activeBossMechanicPhase;
  bool _bossMechanicsDisposed = false;
  final Set<int> _playedBossAudioPhases = <int>{};
  bool _playedBossIntroAudio = false;
  bool _playedBossVictoryAudio = false;

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

  CampaignChapterBossKind get bossKind => isTemporal
      ? CampaignChapterBossKind.chronoJailer
      : CampaignChapterBossKind.kernelChimera;

  BossArenaIdentity get bossArenaIdentity => isTemporal
      ? BossArenaIdentity.chronoJailer
      : BossArenaIdentity.kernelChimera;

  StoryBossAudioIdentity get bossAudioIdentity => isTemporal
      ? StoryBossAudioIdentity.chronoJailer
      : StoryBossAudioIdentity.kernelChimera;

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
  RegionalRoomObjectiveSpec get roomObjectiveSpec =>
      RegionalRoomObjectiveCatalog.forNode(nodeId);
  int get currentCellNumber => encounterId + 1;
  int get clearedEncounterCount => progress.clearedEncounterCount;
  int get recordCount => progress.collectedRecordCount;
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
  int get enemyCount => combatEncounterSpecs.length;
  int get objectiveProgress => roomObjectiveComplete
      ? roomObjectiveSpec.requiredNodeCount
      : _activatedObjectiveNodeIds.length;
  int get objectiveRequiredCount => roomObjectiveSpec.requiredNodeCount;
  bool get roomObjectiveComplete =>
      !isBossRoom && progress.completedObjectiveIds.contains(encounterId);
  bool get roomExitUnlocked =>
      !isBossRoom &&
      !isEncounterSealed &&
      (nodeId == thirdNode
          ? progress.allRoomsComplete
          : progress.isRoomComplete(encounterId));
  double get objectiveTimeRemaining => _objectiveTimeRemaining;
  List<CampaignRoomObjectiveComponent> get objectiveNodes =>
      List<CampaignRoomObjectiveComponent>.unmodifiable(_objectiveNodes);
  String get roomObjectiveLabel => game.localization.text(
    roomObjectiveSpec.objectiveLocalizationKey,
    parameters: <String, Object>{
      'objective': objectiveProgress,
      'total': objectiveRequiredCount,
      'defeated': progress.clearedEncounterIds.contains(encounterId)
          ? enemyCount
          : defeatedCount,
      'enemies': enemyCount,
      'time':
          (objectiveTimeRemaining > 0
                  ? objectiveTimeRemaining
                  : roomObjectiveSpec.timeLimitSeconds ?? 0)
              .ceil(),
    },
  );
  bool get isCompleted => progress.bossDefeated;
  bool get isBossIntroActive => _bossIntroRemaining > 0;
  bool get isBossRewardDiscoveryActive => _bossRewardDiscoveryRemaining > 0;
  bool get hasExitTerminal => _exitTerminal != null;
  int? get bossHealth => _bossEncounterStarted ? _boss?.health : null;
  int? get bossMaxHealth => _bossEncounterStarted ? _boss?.maxHealth : null;
  String? get bossPhaseKey => _bossEncounterStarted ? _boss?.phaseId : null;
  CampaignChapterBossComponent? get boss => _boss;
  BossArenaPresentationComponent? get bossArenaPresentation =>
      _bossArenaPresentation;
  List<BossSealGateComponent> get bossSeals =>
      List<BossSealGateComponent>.unmodifiable(_bossSeals);
  int? get activeBossMechanicPhase => _activeBossMechanicPhase;
  Set<String> get activeBossMechanicIds =>
      Set<String>.unmodifiable(_bossMechanicComponents.keys);
  Rect? get bossArenaBounds => isBossRoom ? layout.bossArenaBounds : null;

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

  List<Rect> get backdropAlignedPlatformBounds => List<Rect>.unmodifiable(
    layout.surfaces
        .where((surface) => !surface.renderArtwork)
        .map((surface) => surface.bounds),
  );

  List<Rect> get authoredPlatformBounds => List<Rect>.unmodifiable(
    layout.surfaces
        .where((surface) => !surface.isBoundary)
        .map((surface) => surface.bounds),
  );

  String? get environmentAsset => layout.environmentAsset;

  StoryMapArtSpec get mapArtSpec => StoryMapArtCatalog.specFor(nodeId);

  Vector2 _anchorVector(String id) => layout.requireAnchor(id).toVector2();

  Vector2 get _westDoorPosition =>
      _anchorVector(RegionalCampaignAnchorId.backDoor);

  Vector2 get _eastDoorPosition =>
      _anchorVector(RegionalCampaignAnchorId.forwardDoor);

  Vector2 get _recordPosition =>
      _anchorVector(RegionalCampaignAnchorId.qaRecord);

  Vector2 get _questRewardPosition =>
      _anchorVector(RegionalCampaignAnchorId.questReward);

  List<(PlatformerEnemyArchetype, double, double)> get combatEncounterSpecs =>
      layout.enemies
          .map((enemy) => (enemy.archetype, enemy.position.x, enemy.position.y))
          .toList(growable: false);

  @override
  bool canLeaveCampaignNode(CampaignNodeId targetNode) => !isEncounterSealed;

  @override
  Vector2 get playerSpawn => layout.spawnFor(entry).toVector2();

  @override
  late final Vector2 worldSize = layout.size;

  @override
  double get killPlaneY => layout.killPlaneY;

  List<TraversalSegment> get requiredTraversalSegments =>
      layout.requiredTraversalSegments;
  @override
  Iterable<Rect> get solidBounds => _surfaces
      .where((surface) => surface.isSolid)
      .map((surface) => surface.bounds);

  @override
  Vector2? surfaceDisplacementFor(Rect playerBounds) {
    for (final surface in _surfaces) {
      final displacement = surface.supportDisplacementFor(playerBounds);
      if (displacement != null) return displacement;
    }
    return null;
  }

  @override
  Vector2? surfaceVelocityFor(Rect playerBounds) {
    for (final surface in _surfaces) {
      final velocity = surface.supportVelocityFor(playerBounds);
      if (velocity != null) return velocity;
    }
    return null;
  }

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
    if (isBossIntroActive) {
      final bossPosition =
          _boss?.position ?? _anchorVector(RegionalCampaignAnchorId.bossSpawn);
      return Vector2(bossPosition.x, math.max(270, bossPosition.y - 170));
    }
    final boss = _boss;
    if (_bossEncounterStarted && boss != null && boss.isActive) {
      return Vector2(
        playerPosition.x * .58 + boss.position.x * .42,
        math.max(270, playerPosition.y * .55 + boss.position.y * .45 - 145),
      );
    }
    final director = _encounterDirector;
    final encounter = layout.encounter;
    if (director?.usesCombatCamera ?? false) {
      if (encounter == null) {
        throw StateError('$nodeId is missing its encounter camera contract.');
      }
      PlatformerEnemyComponent? nearest;
      var nearestDistance = double.infinity;
      for (final enemy in activeEncounterEnemies) {
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
    return !isBossRoom
        ? Vector2(playerPosition.x, playerPosition.y - 68)
        : Vector2(480, 270);
  }

  @override
  double cameraZoomFor(Vector2 playerPosition) {
    if (isBossIntroActive) return .88;
    if (_bossEncounterStarted && (_boss?.isActive ?? false)) return .96;
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
    await _addRoomFeatures();
    await _addTerrainPulseRoute();
    await _addServiceRoomFeatures();
    if (nodeId == firstNode) {
      final checkpoint = CampaignCheckpointComponent(
        position: _anchorVector(RegionalCampaignAnchorId.checkpoint),
        isActive: game.campaignExploration.checkpointNodeId == campaignNodeId,
        onActivated: () => game.activateCampaignCheckpoint(campaignNodeId),
      );
      _checkpoint = checkpoint;
      await add(checkpoint);
    }
    if (isBossRoom) {
      await _addBossEncounter();
    } else {
      await _addRoomObjective();
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

  Future<void> _addTerrainPulseRoute() async {
    final pulse = layout.terrainPulse;
    if (pulse == null) return;
    final bridge = TerrainPulseBridgeComponent(
      position: Vector2(pulse.bridgeBounds.left, pulse.bridgeBounds.top),
      size: Vector2(pulse.bridgeBounds.width, pulse.bridgeBounds.height),
      style: surfaceStyle,
    );
    final node = TerrainPulseNodeComponent(
      position: pulse.nodePosition.toVector2(),
      nodeId: pulse.routeId,
      onActivated: bridge.activate,
      accentColor: accentColor,
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
    if (nodeId == firstNode) {
      final station = CampaignRepairStationComponent(
        position: _anchorVector(RegionalCampaignAnchorId.repairStation),
        used: progress.repairStationUsed,
        onUsed: () => progress.repairStationUsed = true,
        accentColor: accentColor,
      );
      _repairStation = station;
      await add(station);
    }
    if (nodeId == thirdNode) {
      final terminal = LoadoutEventTerminalComponent(
        position: _anchorVector(RegionalCampaignAnchorId.loadoutEvent),
        resolved: progress.loadoutEventResolved,
        eventId: isTemporal
            ? CampaignLoadoutEventId.temporalHall
            : CampaignLoadoutEventId.collisionArchive,
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
    final components = <Component>[];
    final dynamicSurfaces = <PlatformSurfaceComponent>[];
    for (final feature in layout.features) {
      Component? component;
      switch (feature.kind) {
        case RegionalCampaignFeatureKind.movingPlatform:
          component = MovingPlatformComponent(
            start: feature.position.toVector2(),
            end: feature.end!.toVector2(),
            size: feature.size.toVector2(),
            periodSeconds: feature.periodSeconds!,
            style: surfaceStyle,
          );
        case RegionalCampaignFeatureKind.rewindPlatform:
          component = RewindPlatformComponent(
            timeline: feature.timeline
                .map((point) => point.toVector2())
                .toList(growable: false),
            size: feature.size.toVector2(),
            periodSeconds: feature.periodSeconds!,
            style: surfaceStyle,
          );
        case RegionalCampaignFeatureKind.mergingPlatform:
          component = _trackObjectiveMergePlatform(
            MergingPlatformComponent(
              position: feature.position.toVector2(),
              size: feature.size.toVector2(),
              periodSeconds: feature.periodSeconds!,
              style: surfaceStyle,
            ),
          );
        case RegionalCampaignFeatureKind.conveyorPlatform:
          component = ConveyorPlatformComponent(
            position: feature.position.toVector2(),
            size: feature.size.toVector2(),
            direction: feature.direction!,
            style: surfaceStyle,
          );
        case RegionalCampaignFeatureKind.breakablePlatform:
          component = BreakablePlatformComponent(
            position: feature.position.toVector2(),
            size: feature.size.toVector2(),
            breakDelay: feature.breakDelay!,
            restoreDelay: feature.restoreDelay!,
            style: surfaceStyle,
          );
        case RegionalCampaignFeatureKind.bossSafePlatform:
          throw StateError(
            '$nodeId bossSafePlatform must be authored in bossMechanics.',
          );
        case RegionalCampaignFeatureKind.jumpPad:
          component = JumpPadComponent(
            position: feature.position.toVector2(),
            style: surfaceStyle,
          );
        case RegionalCampaignFeatureKind.pulsingLaser:
          final sourceId = feature.sourceId!;
          if (_shouldAddObjectiveHazard(sourceId)) {
            component = _trackObjectiveHazard(
              PulsingLaserComponent(
                position: feature.position.toVector2(),
                size: feature.size.toVector2(),
                sourceId: sourceId,
                activeSeconds: feature.activeSeconds!,
                inactiveSeconds: feature.inactiveSeconds!,
                phaseOffset: feature.phaseOffset,
                style: surfaceStyle,
              ),
              sourceId,
            );
          }
        case RegionalCampaignFeatureKind.crusherHazard:
          final sourceId = feature.sourceId!;
          if (_shouldAddObjectiveHazard(sourceId)) {
            component = _trackObjectiveHazard(
              CrusherHazardComponent(
                start: feature.position.toVector2(),
                end: feature.end!.toVector2(),
                size: feature.size.toVector2(),
                sourceId: sourceId,
                periodSeconds: feature.periodSeconds!,
                style: surfaceStyle,
              ),
              sourceId,
            );
          }
        case RegionalCampaignFeatureKind.spikeHazard:
          component = RoomHazardComponent(
            position: feature.position.toVector2(),
            size: feature.size.toVector2(),
            style: RoomHazardStyle.spikes,
            surfaceStyle: surfaceStyle,
            sourceId: feature.sourceId!,
          );
        case RegionalCampaignFeatureKind.bossSeal:
          // Boss seals are stateful gates and are mounted by _addBossEncounter.
          break;
      }
      if (component == null) continue;
      components.add(component);
      if (component is PlatformSurfaceComponent) {
        dynamicSurfaces.add(component);
      }
    }
    _surfaces.addAll(dynamicSurfaces);
    await addAll(components);
  }

  Future<void> _addRoomObjective() async {
    final spec = roomObjectiveSpec;
    final alreadyComplete = roomObjectiveComplete;
    for (var index = 0; index < layout.objectiveNodes.length; index += 1) {
      final node = CampaignRoomObjectiveComponent(
        position: layout.objectiveNodes[index].toVector2(),
        nodeIndex: index,
        activationOrdinal: spec.mode == RegionalRoomObjectiveMode.ordered
            ? spec.activationOrdinalFor(index)
            : null,
        visualStyle: spec.visualStyle,
        labelLocalizationKey: spec.interactionLocalizationKey,
        accentColor: accentColor,
        activated: alreadyComplete,
        onInteract: _onObjectiveNodeInteracted,
      );
      _objectiveNodes.add(node);
      await add(node);
    }
  }

  CampaignRoomObjectiveInteractionResult _onObjectiveNodeInteracted(
    int nodeIndex,
  ) {
    if (roomObjectiveComplete ||
        _activatedObjectiveNodeIds.contains(nodeIndex)) {
      return CampaignRoomObjectiveInteractionResult.alreadyActivated;
    }

    final spec = roomObjectiveSpec;
    switch (spec.mode) {
      case RegionalRoomObjectiveMode.ordered:
        final expectedIndex =
            spec.activationOrder[_activatedObjectiveNodeIds.length];
        if (nodeIndex != expectedIndex) {
          final restartsSequence = nodeIndex == spec.activationOrder.first;
          _resetObjectiveSequence(markRejected: !restartsSequence);
          if (!restartsSequence) {
            game.triggerImpactFeedback();
            return CampaignRoomObjectiveInteractionResult.reset;
          }
        }
      case RegionalRoomObjectiveMode.anyOrder:
        break;
      case RegionalRoomObjectiveMode.timedAnyOrder:
        if (_activatedObjectiveNodeIds.isEmpty) {
          _objectiveTimeRemaining = spec.timeLimitSeconds!;
        }
    }

    final wouldComplete =
        _activatedObjectiveNodeIds.length + 1 >= spec.requiredNodeCount;
    if (wouldComplete && !_isObjectiveCompletionWindowOpen(spec)) {
      game.triggerImpactFeedback();
      return CampaignRoomObjectiveInteractionResult.rejected;
    }

    _activatedObjectiveNodeIds.add(nodeIndex);
    _syncObjectiveNodes();
    unawaited(game.audio.playPatchPulse());
    if (_activatedObjectiveNodeIds.length < spec.requiredNodeCount) {
      game.publishUiSnapshot(force: true);
      return CampaignRoomObjectiveInteractionResult.activated;
    }

    _completeRoomObjective();
    return CampaignRoomObjectiveInteractionResult.completed;
  }

  bool _isObjectiveCompletionWindowOpen(RegionalRoomObjectiveSpec spec) =>
      switch (spec.completionWindow) {
        RegionalRoomObjectiveCompletionWindow.none => true,
        RegionalRoomObjectiveCompletionWindow.hazardInactive =>
          !(_objectiveLaser?.isActive ?? true),
        RegionalRoomObjectiveCompletionWindow.platformMerged =>
          _objectiveMergePlatform?.isMerged ?? false,
      };

  void _resetObjectiveSequence({bool markRejected = true}) {
    _activatedObjectiveNodeIds.clear();
    _objectiveTimeRemaining = 0;
    for (final node in _objectiveNodes) {
      node.syncActivated(false);
      if (markRejected) node.markRejected();
    }
    game.publishUiSnapshot(force: true);
  }

  void _syncObjectiveNodes() {
    for (final node in _objectiveNodes) {
      node.syncActivated(_activatedObjectiveNodeIds.contains(node.nodeIndex));
    }
  }

  void _completeRoomObjective() {
    if (!progress.completedObjectiveIds.add(encounterId)) return;
    _objectiveTimeRemaining = 0;
    for (final node in _objectiveNodes) {
      node.syncActivated(true);
    }
    _objectiveHazard?.removeFromParent();
    _objectiveHazard = null;
    _objectiveLaser = null;
    _objectiveMergePlatform?.lockMerged();
    _encounterDirector?.notifyCompletionGateSatisfied();
    if (_encounterDirector?.isCleared ?? false) {
      unawaited(_spawnClearedRoomDoors());
    }
    unawaited(game.audio.playCheckpoint());
    game.triggerImpactFeedback();
    unawaited(_showRoomObjectiveComplete());
    game.publishUiSnapshot(force: true);
  }

  Future<void> _showRoomObjectiveComplete() async {
    await add(
      BossNameCardComponent(
        center: game.world.player.position + Vector2(0, -145),
        title: game.localization.text('objective.roomTaskComplete'),
        subtitle: game.localization.text(
          roomObjectiveSpec.completionLocalizationKey,
        ),
        accentColor: const Color(0xFF45F3A6),
        style: BossNameCardStyle.victory,
        duration: 2.4,
      ),
    );
  }

  bool _shouldAddObjectiveHazard(String sourceId) =>
      roomObjectiveSpec.disabledHazardSourceId != sourceId ||
      !roomObjectiveComplete;

  T _trackObjectiveHazard<T extends Component>(T component, String sourceId) {
    if (roomObjectiveSpec.disabledHazardSourceId == sourceId) {
      _objectiveHazard = component;
      if (component is PulsingLaserComponent) _objectiveLaser = component;
    }
    return component;
  }

  MergingPlatformComponent _trackObjectiveMergePlatform(
    MergingPlatformComponent component,
  ) {
    _objectiveMergePlatform = component;
    if (roomObjectiveComplete) component.lockMerged();
    return component;
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
      completionGateSatisfied: roomObjectiveComplete,
      reverseWaves: entry == CampaignNodeEntry.east,
      onWaveActivated: _activateEncounterWave,
      onClearBeatStarted: _commitEncounterClear,
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
      identity: bossArenaIdentity,
      initiallyCleared: progress.bossDefeated,
    );
    _bossArenaPresentation = arenaPresentation;
    await add(arenaPresentation);
    if (!progress.bossDefeated) {
      final seals = layout.features
          .where(
            (feature) => feature.kind == RegionalCampaignFeatureKind.bossSeal,
          )
          .map(
            (feature) => BossSealGateComponent(
              position: feature.position.toVector2(),
              size: feature.size.toVector2(),
              style: surfaceStyle,
            ),
          )
          .toList(growable: false);
      _bossSeals.addAll(seals);
      _surfaces.addAll(seals);
      await addAll(seals);
      await _syncBossMechanics(1);
      final boss = CampaignChapterBossComponent(
        position: _anchorVector(RegionalCampaignAnchorId.bossSpawn),
        kind: bossKind,
        arenaBounds: layout.bossArenaBounds,
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

  Future<void> _syncBossMechanics(int? phase) async {
    if (!isBossRoom || _bossMechanicsDisposed) return;
    final epoch = ++_bossMechanicEpoch;
    _activeBossMechanicPhase = phase;
    final desired = phase == null
        ? const <String, RegionalCampaignBossMechanicSpec>{}
        : <String, RegionalCampaignBossMechanicSpec>{
            for (final mechanic in layout.bossMechanics)
              if (mechanic.isActiveInPhase(phase)) mechanic.id: mechanic,
          };

    for (final id
        in _bossMechanicComponents.keys
            .where((id) => !desired.containsKey(id))
            .toList(growable: false)) {
      final component = _bossMechanicComponents.remove(id);
      final surface = _bossMechanicSurfaces.remove(id);
      if (surface != null) _surfaces.remove(surface);
      if (component != null && !component.isRemoving) {
        component.removeFromParent();
      }
    }

    for (final entry in desired.entries) {
      if (_bossMechanicComponents.containsKey(entry.key)) continue;
      final component = _buildBossMechanic(entry.value.feature);
      _bossMechanicComponents[entry.key] = component;
      if (component is PlatformSurfaceComponent) {
        _bossMechanicSurfaces[entry.key] = component;
        _surfaces.add(component);
      }
      await add(component);
      if (epoch != _bossMechanicEpoch) {
        if (identical(_bossMechanicComponents[entry.key], component)) {
          _bossMechanicComponents.remove(entry.key);
        }
        if (identical(_bossMechanicSurfaces[entry.key], component)) {
          final surface = _bossMechanicSurfaces.remove(entry.key);
          if (surface != null) _surfaces.remove(surface);
        }
        if (!component.isRemoving) component.removeFromParent();
        if (!_bossMechanicsDisposed) {
          unawaited(_syncBossMechanics(_activeBossMechanicPhase));
        }
        return;
      }
    }
    game.publishUiSnapshot(force: true);
  }

  Component _buildBossMechanic(RegionalCampaignFeatureSpec feature) {
    switch (feature.kind) {
      case RegionalCampaignFeatureKind.bossSafePlatform:
        return PlatformSurfaceComponent(
          position: feature.position.toVector2(),
          size: feature.size.toVector2(),
          style: surfaceStyle,
          renderArtwork: true,
        );
      case RegionalCampaignFeatureKind.movingPlatform:
        return MovingPlatformComponent(
          start: feature.position.toVector2(),
          end: feature.end!.toVector2(),
          size: feature.size.toVector2(),
          periodSeconds: feature.periodSeconds!,
          style: surfaceStyle,
        );
      case RegionalCampaignFeatureKind.rewindPlatform:
        return RewindPlatformComponent(
          timeline: feature.timeline
              .map((point) => point.toVector2())
              .toList(growable: false),
          size: feature.size.toVector2(),
          periodSeconds: feature.periodSeconds!,
          style: surfaceStyle,
        );
      case RegionalCampaignFeatureKind.mergingPlatform:
        return MergingPlatformComponent(
          position: feature.position.toVector2(),
          size: feature.size.toVector2(),
          periodSeconds: feature.periodSeconds!,
          style: surfaceStyle,
        );
      case RegionalCampaignFeatureKind.conveyorPlatform:
        return ConveyorPlatformComponent(
          position: feature.position.toVector2(),
          size: feature.size.toVector2(),
          direction: feature.direction!,
          style: surfaceStyle,
        );
      case RegionalCampaignFeatureKind.pulsingLaser:
        return PulsingLaserComponent(
          position: feature.position.toVector2(),
          size: feature.size.toVector2(),
          sourceId: feature.sourceId!,
          activeSeconds: feature.activeSeconds!,
          inactiveSeconds: feature.inactiveSeconds!,
          phaseOffset: feature.phaseOffset,
          startupGraceSeconds: 1.1,
          style: surfaceStyle,
        );
      case RegionalCampaignFeatureKind.breakablePlatform ||
          RegionalCampaignFeatureKind.jumpPad ||
          RegionalCampaignFeatureKind.crusherHazard ||
          RegionalCampaignFeatureKind.spikeHazard ||
          RegionalCampaignFeatureKind.bossSeal:
        throw StateError(
          '$nodeId cannot mount ${feature.kind.name} as a boss mechanic.',
        );
    }
  }

  Future<void> _spawnAvailableDoors() async {
    if (!isBossRoom) {
      await _spawnBackDoors();
      await _spawnForwardDoor();
      if (roomExitUnlocked) await _spawnClearedRoomDoors();
      return;
    }
    if (progress.bossDefeated) await _spawnBackDoors();
    if (progress.bossDefeated && progress.patchApplied) {
      if (nodeId == CampaignNodeId.chronoJailer) {
        await _spawnDoor(
          target: CampaignNodeId.collisionCompression,
          position: _anchorVector(RegionalCampaignAnchorId.regionBranchDoor),
          labelLocalizationKey: 'interaction.enterCollisionArchive',
          targetEntry: CampaignNodeEntry.west,
        );
      }
      await _spawnHubLiftDoor();
    }
  }

  Future<void> _spawnBackDoors() async {
    final previous = switch (nodeId) {
      CampaignNodeId.temporalAscent => CampaignNodeId.overflowWarden,
      CampaignNodeId.collisionCompression => CampaignNodeId.chronoJailer,
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
      labelLocalizationKey: nodeId == firstNode && isTemporal
          ? 'interaction.returnOverflowJunction'
          : 'interaction.previousRoom',
      targetEntry: CampaignNodeEntry.east,
    );
    if (nodeId == firstNode &&
        game.campaignExploration.unlockedShortcutIds.contains(hubAccessId)) {
      await _spawnDoor(
        target: CampaignNodeId.bootSector,
        position: _anchorVector(RegionalCampaignAnchorId.hubShortcutDoor),
        labelLocalizationKey: 'interaction.returnBootSector',
        targetEntry: CampaignNodeEntry.east,
        color: accentColor,
      );
    }
  }

  Future<void> _spawnForwardDoor() async {
    final target = CampaignWorldGraph.linearNextNode[nodeId];
    if (target == null) {
      throw StateError('Regional node has no forward route: $nodeId');
    }
    await _spawnDoor(
      target: target,
      position: _eastDoorPosition,
      labelLocalizationKey: nodeId == thirdNode
          ? 'interaction.enterBossRoom'
          : 'interaction.nextRoom',
      targetEntry: CampaignNodeEntry.west,
      isUnlockedResolver: () => roomExitUnlocked,
      lockedLabelLocalizationKeyResolver: () {
        if (!progress.clearedEncounterIds.contains(encounterId)) {
          return 'interaction.clearThreats';
        }
        if (!progress.completedObjectiveIds.contains(encounterId)) {
          return 'interaction.completeRoomTask';
        }
        return 'interaction.completePreviousRooms';
      },
      onLockedInteract: _onRoomExitLocked,
    );
  }

  Future<void> _spawnClearedRoomDoors() async {
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
      position: _anchorVector(RegionalCampaignAnchorId.secretDoor),
      labelLocalizationKey: labelLocalizationKey,
      targetEntry: CampaignNodeEntry.west,
      color: accentColor,
    );
  }

  Future<void> _spawnHubLiftDoor() => _spawnDoor(
    target: CampaignNodeId.bootSector,
    position: _anchorVector(RegionalCampaignAnchorId.hubLift),
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
    bool Function()? isUnlockedResolver,
    String Function()? lockedLabelLocalizationKeyResolver,
    VoidCallback? onLockedInteract,
  }) async {
    if (_doors.containsKey(target)) return;
    final encounterGuarded = !isBossRoom;
    final effectiveUnlockedResolver = encounterGuarded
        ? () => !isEncounterSealed && (isUnlockedResolver?.call() ?? true)
        : isUnlockedResolver;
    final effectiveLockedLabelResolver = encounterGuarded
        ? () => isEncounterSealed
              ? encounterPhase == CampaignEncounterPhase.objectiveHold
                    ? 'interaction.completeRoomTask'
                    : 'interaction.clearThreats'
              : lockedLabelLocalizationKeyResolver?.call() ??
                    'interaction.routeLocked'
        : lockedLabelLocalizationKeyResolver;
    final door = CampaignDoorComponent(
      position: position,
      labelLocalizationKey: labelLocalizationKey,
      accentColor: color ?? accentColor,
      onInteract: () => game.travelToCampaignNode(target, entry: targetEntry),
      isUnlockedResolver: effectiveUnlockedResolver,
      lockedLabelLocalizationKeyResolver: effectiveLockedLabelResolver,
      onLockedInteract: encounterGuarded
          ? onLockedInteract ?? _onRoomExitLocked
          : onLockedInteract,
    );
    _doors[target] = door;
    await add(door);
  }

  void _onRoomExitLocked() {
    game.triggerImpactFeedback();
    game.publishUiSnapshot(force: true);
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

  void _commitEncounterClear() {
    if (!progress.clearedEncounterIds.add(encounterId)) return;
    if (game.runItems.contains(RunItemId.conduitHeart)) {
      game.world.player.restoreIntegrity(1);
    }
    game.publishUiSnapshot(force: true);
  }

  void _finishEncounterClear() {
    if (roomObjectiveComplete) unawaited(_spawnClearedRoomDoors());
    game.triggerImpactFeedback();
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
      center: Vector2(worldSize.x / 2, math.max(145, worldSize.y * .2)),
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
    if (!_playedBossVictoryAudio) {
      _playedBossVictoryAudio = true;
      unawaited(game.audio.playStoryBossVictory(bossAudioIdentity));
    }
    for (final seal in _bossSeals) {
      seal.unlock();
    }
    unawaited(_syncBossMechanics(null));
    unawaited(_showCoreSignatureCard());
    unawaited(_spawnBackDoors());
    unawaited(_spawnBossReward());
    game.publishUiSnapshot(force: true);
  }

  Future<void> _spawnBossReward() async {
    if (_bossReward != null || progress.bossRewardClaimed) return;
    final reward = ItemPedestalComponent(
      position: _anchorVector(RegionalCampaignAnchorId.bossReward),
      item: bossRewardItem,
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
    final regionKey = isTemporal
        ? 'room.temporalHall'
        : 'room.collisionArchive';
    final abilityKey = isTemporal
        ? 'ability.airDash.name'
        : 'ability.terrainPulse.name';
    await add(
      BossNameCardComponent(
        center: Vector2(worldSize.x / 2, math.max(145, worldSize.y * .2)),
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
    final mechanicPhase = switch (phase) {
      CampaignChapterBossPhase.intro || CampaignChapterBossPhase.phaseOne => 1,
      CampaignChapterBossPhase.phaseTwo => 2,
      CampaignChapterBossPhase.phaseThree => 3,
      CampaignChapterBossPhase.dormant ||
      CampaignChapterBossPhase.defeated => null,
    };
    unawaited(_syncBossMechanics(mechanicPhase));
    switch (phase) {
      case CampaignChapterBossPhase.dormant:
        break;
      case CampaignChapterBossPhase.intro:
        _bossArenaPresentation?.beginIntro();
        if (!_playedBossIntroAudio) {
          _playedBossIntroAudio = true;
          unawaited(game.audio.playStoryBossIntro(bossAudioIdentity));
        }
      case CampaignChapterBossPhase.phaseOne:
        _bossArenaPresentation?.beginPhaseOne();
        _playBossPhaseAudioOnce(1);
      case CampaignChapterBossPhase.phaseTwo:
        _bossArenaPresentation?.beginPhaseTwo();
        _playBossPhaseAudioOnce(2);
      case CampaignChapterBossPhase.phaseThree:
        _bossArenaPresentation?.beginPhaseThree();
        _playBossPhaseAudioOnce(3);
      case CampaignChapterBossPhase.defeated:
        _bossArenaPresentation?.markCleared();
    }
  }

  void _playBossPhaseAudioOnce(int phase) {
    if (!_playedBossAudioPhases.add(phase)) return;
    unawaited(game.audio.playStoryBossPhase(bossAudioIdentity, phase: phase));
  }

  Future<void> _spawnExitTerminal() async {
    if (_exitTerminal != null ||
        progress.patchApplied ||
        !progress.bossRewardClaimed) {
      return;
    }
    final terminal = PatchExitTerminalComponent(
      position: _anchorVector(RegionalCampaignAnchorId.exitTerminal),
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
    for (final node in _objectiveNodes) {
      if (node.tryActivate(player)) return true;
    }
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
    if (game.world.isReady && !isBossRoom) {
      final director = _encounterDirector;
      if (director != null) {
        final player = game.world.player.position;
        director.tryTrigger(Offset(player.x, player.y));
        director.update(game.clock.realDt);
      }
    }
    if (!isBossRoom &&
        roomObjectiveSpec.mode == RegionalRoomObjectiveMode.timedAnyOrder &&
        !roomObjectiveComplete &&
        _activatedObjectiveNodeIds.isNotEmpty) {
      _objectiveTimeRemaining = math.max(
        0,
        _objectiveTimeRemaining - game.clock.simulationDt,
      );
      if (_objectiveTimeRemaining <= 0) {
        _resetObjectiveSequence();
        game.triggerImpactFeedback();
      }
    }
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
    _bossMechanicsDisposed = true;
    _bossMechanicEpoch += 1;
    game.setCinematicInputLocked(false);
    super.onRemove();
  }
}
