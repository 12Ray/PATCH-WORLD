import 'dart:async' hide Timer;
import 'dart:async' as dart_async show Timer;
import 'dart:math' as math;

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_exploration_state.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/combat/combat_entity_budget.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/effects/weapon_impact_burst_component.dart';
import 'package:patch_world/game/core/input_controller.dart';
import 'package:patch_world/game/core/game_clock.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/core/run_metrics.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/rooms/damage_lab_room_status.dart';
import 'package:patch_world/game/rooms/maps/damage_lab_room_layout.dart';
import 'package:patch_world/game/rooms/maps/regional_campaign_room_layout.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/enemy_tempo_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';
import 'package:patch_world/game/systems/patch_effects_system.dart';
import 'package:patch_world/game/systems/player_pattern_tracker.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:patch_world/game/survival/survival_balance.dart';
import 'package:patch_world/game/survival/survival_balance_report.dart';
import 'package:patch_world/game/survival/survival_patch_modifiers.dart';
import 'package:patch_world/game/survival/survival_patch_fusions.dart';
import 'package:patch_world/game/survival/survival_playtest_telemetry.dart';
import 'package:patch_world/game/survival/survival_items.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';
import 'package:patch_world/game/survival/survival_weapon_build.dart';
import 'package:patch_world/services/audio_service.dart';
import 'package:patch_world/services/game_settings.dart';
import 'package:patch_world/services/localization_service.dart';
import 'package:patch_world/services/settings_service.dart';

final class PatchWorldGame extends FlameGame<PatchWorld>
    with HasCollisionDetection, KeyboardEvents {
  PatchWorldGame({this.initialRoom = RoomId.damageLab})
    : currentRoom = initialRoom,
      mode = initialRoom == RoomId.survivalArena
          ? PatchWorldMode.survival
          : PatchWorldMode.campaign,
      super(
        world: PatchWorld(),
        camera: CameraComponent.withFixedResolution(
          width: logicalWidth,
          height: logicalHeight,
          viewfinder: Viewfinder()..position = Vector2(480, 270),
        ),
      ) {
    pauseWhenBackgrounded = true;
  }

  static const double logicalWidth = 960;
  static const double logicalHeight = 540;
  static const List<String> campaignPrewarmAssetPaths = <String>[
    'rooms/damage-lab-environment-v3.webp',
    'rooms/damage-lab-maintenance-v1.webp',
    'rooms/damage-lab-hazard-v1.webp',
    'rooms/temporal-ascent-v1.webp',
    'rooms/temporal-fracture-v1.webp',
    'rooms/temporal-pendulum-v1.webp',
    'rooms/collision-compression-v1.webp',
    'rooms/collision-fracture-v1.webp',
    'rooms/collision-merge-v1.webp',
    'sprites/combat_v2/enemies/patch-mite.png',
    'sprites/combat_v2/enemies/checksum-hopper.png',
    'sprites/combat_v2/enemies/pulse-turret.png',
    'sprites/combat_v2/enemies/repair-leech.png',
    'sprites/combat_v2/enemies/overflow-warden.png',
    'sprites/combat_v2/enemies/tick-runner.png',
    'sprites/combat_v2/enemies/echo-bat.png',
    'sprites/combat_v2/enemies/delay-sniper.png',
    'sprites/combat_v2/enemies/rewind-skater.png',
    'sprites/combat_v2/enemies/chrono-jailer.png',
    'sprites/combat_v2/enemies/vector-ram.png',
    'sprites/combat_v2/enemies/polarity-drone.png',
    'sprites/combat_v2/enemies/phase-mimic.png',
    'sprites/combat_v2/enemies/shard-lobber.png',
    'sprites/combat_v2/enemies/kernel-chimera.png',
    'sprites/art_v3/enemies/patch-mite.png',
    'sprites/art_v3/enemies/checksum-hopper.png',
    'sprites/art_v3/enemies/pulse-turret.png',
    'sprites/art_v3/enemies/repair-leech.png',
    'sprites/art_v3/enemies/overflow-warden.png',
    'sprites/art_v3/enemies/tick-runner.png',
    'sprites/art_v3/enemies/echo-bat.png',
    'sprites/art_v3/enemies/delay-sniper.png',
    'sprites/art_v3/enemies/rewind-skater.png',
    'sprites/art_v3/enemies/chrono-jailer.png',
    'sprites/art_v3/enemies/vector-ram.png',
    'sprites/art_v3/enemies/polarity-drone.png',
    'sprites/art_v3/enemies/phase-mimic.png',
    'sprites/art_v3/enemies/shard-lobber.png',
    'sprites/art_v3/enemies/kernel-chimera.png',
    'sprites/combat_v2/projectiles/patch-mite.png',
    'sprites/combat_v2/projectiles/checksum-hopper.png',
    'sprites/combat_v2/projectiles/pulse-turret.png',
    'sprites/combat_v2/projectiles/repair-leech.png',
    'sprites/combat_v2/projectiles/overflow-warden.png',
    'sprites/combat_v2/projectiles/tick-runner.png',
    'sprites/combat_v2/projectiles/echo-bat.png',
    'sprites/combat_v2/projectiles/delay-sniper.png',
    'sprites/combat_v2/projectiles/rewind-skater.png',
    'sprites/combat_v2/projectiles/chrono-jailer.png',
    'sprites/combat_v2/projectiles/vector-ram.png',
    'sprites/combat_v2/projectiles/polarity-drone.png',
    'sprites/combat_v2/projectiles/phase-mimic.png',
    'sprites/combat_v2/projectiles/shard-lobber.png',
    'sprites/combat_v2/projectiles/kernel-chimera.png',
    'sprites/art_v3/boss/optimizer-analyze.png',
    'sprites/art_v3/boss/optimizer-predict.png',
    'sprites/art_v3/boss/optimizer-perfect.png',
    'sprites/art_v3/boss/optimizer-overflow.png',
    'sprites/survival_v1/enemies/rift-stalker.webp',
    'sprites/survival_v1/enemies/arc-warden.webp',
    'sprites/survival_v1/enemies/mine-layer.webp',
    'sprites/survival_v1/bosses/foundry-overseer.webp',
    'sprites/survival_v1/bosses/temporal-regent.webp',
    'sprites/survival_v1/bosses/collision-behemoth.webp',
    'sprites/survival_v1/bosses/nexus-core.webp',
  ];
  static const int survivalQaStartSecond = int.fromEnvironment(
    'SURVIVAL_START_SECOND',
    defaultValue: 0,
  );
  static const int survivalQaTimeScale = int.fromEnvironment(
    'SURVIVAL_QA_TIME_SCALE',
    defaultValue: 1,
  );
  static const bool survivalQaInvincible = bool.fromEnvironment(
    'SURVIVAL_QA_INVINCIBLE',
    defaultValue: false,
  );
  static const bool survivalQaCacheAtPlayer = bool.fromEnvironment(
    'SURVIVAL_QA_CACHE_AT_PLAYER',
    defaultValue: false,
  );
  static const String survivalQaBuild = String.fromEnvironment(
    'SURVIVAL_QA_BUILD',
    defaultValue: '',
  );
  static const int survivalQaStartCombo = int.fromEnvironment(
    'SURVIVAL_QA_START_COMBO',
    defaultValue: 0,
  );
  static const bool survivalQaPerfectDodgeDemo = bool.fromEnvironment(
    'SURVIVAL_QA_PERFECT_DODGE_DEMO',
    defaultValue: false,
  );
  static const bool survivalQaHoundBreakDemo = bool.fromEnvironment(
    'SURVIVAL_QA_HOUND_BREAK_DEMO',
    defaultValue: false,
  );
  static const bool survivalQaPhaseExecutionDemo = bool.fromEnvironment(
    'SURVIVAL_QA_PHASE_EXECUTION_DEMO',
    defaultValue: false,
  );
  static const bool survivalQaItemRewardDemo = bool.fromEnvironment(
    'SURVIVAL_QA_ITEM_REWARD_DEMO',
    defaultValue: false,
  );
  static const bool survivalQaEnemyArtDemo = bool.fromEnvironment(
    'SURVIVAL_QA_ENEMY_ART_DEMO',
    defaultValue: false,
  );
  static const bool survivalQaAutoAttack = bool.fromEnvironment(
    'SURVIVAL_QA_AUTO_ATTACK',
    defaultValue: false,
  );
  static const List<String> _runOverlayIds = <String>[
    OverlayIds.weaponSelection,
    OverlayIds.hud,
    OverlayIds.touchControls,
    OverlayIds.pause,
    OverlayIds.campaignMap,
    OverlayIds.buildSelection,
    OverlayIds.patchSelection,
    OverlayIds.patchApplied,
    OverlayIds.survivalUpgrade,
    OverlayIds.survivalWeaponUpgrade,
    OverlayIds.survivalItemReward,
    OverlayIds.survivalResult,
    OverlayIds.defeat,
    OverlayIds.runSummary,
    OverlayIds.ending,
    OverlayIds.settings,
    OverlayIds.credits,
  ];

  final RoomId initialRoom;

  final InputController input = InputController();
  final RunState runState = RunState();
  final RunMetrics runMetrics = RunMetrics();
  final CampaignWorldGraph campaignWorld = CampaignWorldGraph.standard();
  final CampaignExplorationState campaignExploration =
      CampaignExplorationState();
  final DamageLabFloorState damageLabProgress = DamageLabFloorState();
  final CampaignFloorState temporalHallProgress = CampaignFloorState();
  final CampaignFloorState collisionArchiveProgress = CampaignFloorState();
  final RunItemState runItems = RunItemState();
  final WeaponBuildState weaponBuild = WeaponBuildState();
  final SurvivalRunState survivalRun = SurvivalRunState();
  final SurvivalWeaponBuildState survivalWeaponBuild =
      SurvivalWeaponBuildState();
  final SurvivalItemBuildState survivalItems = SurvivalItemBuildState();
  final Set<CampaignTraversalAbility> survivalMetaAbilities =
      <CampaignTraversalAbility>{};
  final RuleEngine ruleEngine = RuleEngine();
  final GameClock clock = GameClock();
  final CombatEntityBudget combatEntityBudget = CombatEntityBudget();
  final PlayerPatternTracker patternTracker = PlayerPatternTracker();
  final AudioService audio = AudioService();
  final LocalizationService localization = LocalizationService();
  final SettingsService settingsService = SettingsService();
  final ValueNotifier<GameSettings> settings = ValueNotifier<GameSettings>(
    const GameSettings(),
  );
  final ValueNotifier<UiSnapshot> uiSnapshot = ValueNotifier<UiSnapshot>(
    UiSnapshot.initial(),
  );
  final ValueNotifier<DefeatSnapshot?> defeatSnapshot =
      ValueNotifier<DefeatSnapshot?>(null);
  final ValueNotifier<SurvivalResultSnapshot?> survivalResult =
      ValueNotifier<SurvivalResultSnapshot?>(null);
  final List<SurvivalResultSnapshot> survivalSessionHistory =
      <SurvivalResultSnapshot>[];
  final List<SurvivalPlaytestRecord> survivalPlaytestHistory =
      <SurvivalPlaytestRecord>[];
  final ValueNotifier<RunSummary?> completedRun = ValueNotifier<RunSummary?>(
    null,
  );
  final ValueNotifier<PatchDefinition?> patchNotice =
      ValueNotifier<PatchDefinition?>(null);

  late final CombatSystem combatSystem;
  late final PatchEffectsSystem patchEffects;
  late final EnemyTempoSystem enemyTempo;
  late final DuplicateFaultSystem duplicateFault;
  late final DamageLabRoomLayoutCatalog damageLabRoomLayouts;
  late final RegionalCampaignRoomLayoutCatalog regionalRoomLayouts;
  RoomId currentRoom;
  PatchWorldMode mode;
  PatchSelectionRequest? pendingPatchSelection;
  WeaponBuildSelectionRequest? pendingWeaponBuildSelection;
  SurvivalUpgradeRequest? pendingSurvivalUpgrade;
  SurvivalWeaponUpgradeRequest? pendingSurvivalWeaponUpgrade;
  SurvivalItemRewardRequest? pendingSurvivalItemReward;
  final List<SurvivalItemRewardSource> _queuedSurvivalItemRewards =
      <SurvivalItemRewardSource>[];
  bool _roomTransitionInProgress = false;
  double _uiPublishAccumulator = 0;
  bool _roomRestartRequested = false;
  dart_async.Timer? _defeatRestartTimer;
  dart_async.Timer? _patchNoticeTimer;
  int _consecutiveRoomDeaths = 0;
  int bestScore = 0;
  int bestSurvivalScore = 0;
  double bestSurvivalTime = 0;
  double _screenShakeRemaining = 0;
  double _screenShakePhase = 0;
  double _screenShakeIntensity = 1;
  double _combatSlowMotionRemaining = 0;
  double _combatSlowMotionScale = 1;
  double _weaponImpactFeedbackCooldown = 0;
  double _survivalQaAutoAttackRemaining = 0;
  double _horizontalCameraLead = 0;
  final Vector2 _cameraFollowPosition = Vector2(480, 270);
  Component? _cameraFollowRoom;
  String _settingsReturnOverlay = OverlayIds.pause;
  String _creditsReturnOverlay = OverlayIds.title;
  PlayerWeapon? _selectedRunWeapon;
  bool _weaponSelectionForSurvival = false;
  bool _cinematicInputLocked = false;
  bool _returnToTitleInProgress = false;

  PlayerWeapon? get selectedRunWeapon => _selectedRunWeapon;
  bool get weaponSelectionForSurvival => _weaponSelectionForSurvival;
  bool get isRoomTransitionInProgress => _roomTransitionInProgress;
  bool get isOptimizerGateReady =>
      campaignExploration.hasAllCoreSignatures &&
      damageLabProgress.patchApplied &&
      temporalHallProgress.patchApplied &&
      collisionArchiveProgress.patchApplied;

  CampaignNodeId get _campaignStartNode => switch (initialRoom) {
    RoomId.bootSector => CampaignNodeId.bootSector,
    RoomId.damageLab => CampaignWorldGraph.damageMainPath.first,
    RoomId.temporalHall => CampaignWorldGraph.temporalMainPath.first,
    RoomId.collisionArchive => CampaignWorldGraph.collisionMainPath.first,
    RoomId.optimizerCore => CampaignNodeId.optimizerCore,
    _ => CampaignNodeId.bootSector,
  };

  RoomId _roomIdForCampaignNode(CampaignNodeId nodeId) => switch (nodeId) {
    CampaignNodeId.bootSector => RoomId.bootSector,
    CampaignNodeId.damageWorkshop ||
    CampaignNodeId.damageAssembly ||
    CampaignNodeId.damageOverflow ||
    CampaignNodeId.overflowWarden ||
    CampaignNodeId.damageDashCache ||
    CampaignNodeId.damageUpperArchive ||
    CampaignNodeId.damageTurretControl => RoomId.damageLab,
    CampaignNodeId.temporalAscent ||
    CampaignNodeId.temporalFracture ||
    CampaignNodeId.temporalPendulum ||
    CampaignNodeId.chronoJailer ||
    CampaignNodeId.temporalDashRift ||
    CampaignNodeId.temporalUpperLoop ||
    CampaignNodeId.temporalRelayControl => RoomId.temporalHall,
    CampaignNodeId.collisionCompression ||
    CampaignNodeId.collisionFracture ||
    CampaignNodeId.collisionMerge ||
    CampaignNodeId.kernelChimera ||
    CampaignNodeId.collisionVectorCache ||
    CampaignNodeId.collisionUpperMatrix ||
    CampaignNodeId.collisionPrismControl => RoomId.collisionArchive,
    CampaignNodeId.optimizerCore => RoomId.optimizerCore,
  };

  Future<void> _loadCampaignStartNode() async {
    currentRoom = _roomIdForCampaignNode(_campaignStartNode);
    await world.loadCampaignNode(
      _campaignStartNode,
      entry: CampaignNodeEntry.west,
    );
  }

  void setCinematicInputLocked(bool value) {
    if (_cinematicInputLocked == value) return;
    _cinematicInputLocked = value;
    input.clearAll();
    if (value && world.isReady) {
      world.player.setMovementInput(Vector2.zero());
      world.player.setJumpHeld(false);
    }
  }

  RuleContext get ruleContext => RuleContext(
    roomId: currentRoom,
    selectedPatchIds: runState.selectedPatchIds.toSet(),
  );

  SurvivalPatchModifiers get survivalModifiers =>
      SurvivalPatchModifiers(survivalRun.patchTiers);

  @override
  Future<void> onLoad() async {
    var loadedSettings = const GameSettings();
    try {
      loadedSettings = await settingsService.load();
      if (!LocalizationService.supports(loadedSettings.languageCode)) {
        loadedSettings = loadedSettings.copyWith(
          languageCode: LocalizationService.fallbackLanguageCode,
        );
      }
      bestScore = await settingsService.loadBestScore();
      bestSurvivalScore = await settingsService.loadBestSurvivalScore();
      bestSurvivalTime = await settingsService.loadBestSurvivalTime();
      survivalMetaAbilities
        ..clear()
        ..addAll(await settingsService.loadSurvivalAbilityUnlocks());
      survivalPlaytestHistory
        ..clear()
        ..addAll(await settingsService.loadSurvivalPlaytestRecords());
    } catch (_) {
      loadedSettings = const GameSettings();
    }
    try {
      await localization.load(loadedSettings.languageCode);
    } catch (_) {
      // Missing localization must not prevent silent/offline play.
    }
    settings.value = loadedSettings;
    unawaited(audio.preloadSafely());
    audio
      ..setBgmVolume(settings.value.bgmVolume)
      ..setSfxVolume(settings.value.sfxVolume);
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    duplicateFault = DuplicateFaultSystem(
      runState: runState,
      spawnDuplicate:
          ({required archetype, required position, required sourceEntityId}) {
            unawaited(
              world.spawnDuplicate(
                archetype: archetype,
                position: position,
                sourceEntityId: sourceEntityId,
              ),
            );
          },
    );
    combatSystem = CombatSystem(
      ruleEngine: ruleEngine,
      contextProvider: () => ruleContext,
      onPlayerDamageCommitted: duplicateFault.onPlayerDamageCommitted,
    );
    patchEffects = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (position, tier) {
        unawaited(world.spawnRetaliationEcho(position, tier));
      },
      spawnFriendlyBurst: (position, damage, radius, {excludedEntityId}) =>
          unawaited(
            world.spawnFriendlyErrorBurst(
              position,
              damage: damage,
              radius: radius,
              excludedEntityId: excludedEntityId,
            ),
          ),
      damagePlayer: (amount, causeId) {
        if (world.isReady) {
          world.player.takeDamage(amount, causeId: causeId);
        }
      },
    );
    enemyTempo = EnemyTempoSystem(runState: runState);
    damageLabRoomLayouts = await DamageLabRoomLayoutCatalog.load();
    regionalRoomLayouts = await RegionalCampaignRoomLayoutCatalog.load();
    await super.onLoad();
    unawaited(_prewarmCampaignArt());
    publishUiSnapshot(force: true);
    pauseEngine();
  }

  @override
  Color backgroundColor() => const Color(0xFF05070D);

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    input.syncPressedKeys(keysPressed);
    if (event is KeyDownEvent) {
      unawaited(audio.unlockFromUserGesture());
      final choiceIndex = survivalChoiceIndexForKey(event.logicalKey);
      if (choiceIndex != null && hasPendingSurvivalChoice) {
        selectPendingSurvivalChoiceAt(choiceIndex);
        return KeyEventResult.handled;
      }
      input.handleKeyDown(event.logicalKey);
      if (event.logicalKey == LogicalKeyboardKey.keyM &&
          mode == PatchWorldMode.campaign &&
          world.isReady &&
          pendingPatchSelection == null &&
          pendingWeaponBuildSelection == null &&
          pendingSurvivalUpgrade == null &&
          pendingSurvivalWeaponUpgrade == null) {
        _toggleCampaignMap();
        return KeyEventResult.handled;
      }
      if ((event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.keyP) &&
          pendingPatchSelection == null &&
          pendingWeaponBuildSelection == null) {
        if (overlays.isActive(OverlayIds.campaignMap)) {
          closeCampaignMap();
          return KeyEventResult.handled;
        }
        _togglePause();
        return KeyEventResult.handled;
      }
    } else if (event is KeyUpEvent) {
      input.handleKeyUp(event.logicalKey);
    }
    return KeyEventResult.handled;
  }

  bool get hasPendingSurvivalChoice =>
      pendingSurvivalUpgrade != null ||
      pendingSurvivalWeaponUpgrade != null ||
      pendingSurvivalItemReward != null;

  static int? survivalChoiceIndexForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyJ) return 0;
    if (key == LogicalKeyboardKey.keyK) return 1;
    if (key == LogicalKeyboardKey.keyL) return 2;
    return null;
  }

  bool selectPendingSurvivalChoiceAt(int index) {
    if (index < 0) return false;
    final patchRequest = pendingSurvivalUpgrade;
    if (patchRequest != null) {
      if (index >= patchRequest.choices.length) return false;
      selectSurvivalUpgrade(patchRequest.choices[index].id);
      return true;
    }
    final weaponRequest = pendingSurvivalWeaponUpgrade;
    if (weaponRequest != null) {
      if (index >= weaponRequest.choices.length) return false;
      selectSurvivalWeaponUpgrade(weaponRequest.choices[index]);
      return true;
    }
    final itemRequest = pendingSurvivalItemReward;
    if (itemRequest != null) {
      if (index >= itemRequest.choices.length) return false;
      selectSurvivalItem(itemRequest.choices[index]);
      return true;
    }
    return false;
  }

  void openWeaponSelection() {
    _weaponSelectionForSurvival = false;
    input.clearAll();
    overlays.remove(OverlayIds.title);
    overlays.add(OverlayIds.weaponSelection);
    pauseEngine();
  }

  void openSurvivalWeaponSelection() {
    _weaponSelectionForSurvival = true;
    input.clearAll();
    overlays.remove(OverlayIds.title);
    overlays.add(OverlayIds.weaponSelection);
    pauseEngine();
  }

  void cancelWeaponSelection() {
    overlays.remove(OverlayIds.weaponSelection);
    overlays.add(OverlayIds.title);
  }

  Future<void> selectStartingWeapon(PlayerWeapon weapon) async {
    _selectedRunWeapon = weapon;
    weaponBuild.reset();
    overlays.remove(OverlayIds.weaponSelection);
    if (_weaponSelectionForSurvival) {
      // Optional presentation assets continue warming in the background. A
      // slow or stalled web decode must never strand the player on a blank
      // screen after the selection overlay has already closed.
      await _startSurvivalRun(weapon, waitForVisuals: false);
      return;
    }
    await _startCampaignRun(weapon, waitForVisuals: false);
  }

  void startRun() {
    final weapon = _selectedRunWeapon ?? PlayerWeapon.sword;
    _selectedRunWeapon = weapon;
    unawaited(_startCampaignRun(weapon, waitForVisuals: false));
  }

  Future<void> _startCampaignRun(
    PlayerWeapon weapon, {
    bool waitForVisuals = true,
  }) async {
    await ready();
    if (waitForVisuals) await world.player.visualLoadAttempted;
    mode = PatchWorldMode.campaign;
    campaignExploration.reset();
    world.player.configureLoadout(
      weapon,
      assistMode: settings.value.assistMode,
    );
    unawaited(audio.unlockFromUserGesture());
    runMetrics.reset();
    completedRun.value = null;
    overlays.remove(OverlayIds.title);
    if (!overlays.isActive(OverlayIds.hud)) overlays.add(OverlayIds.hud);
    if (!overlays.isActive(OverlayIds.touchControls)) {
      overlays.add(OverlayIds.touchControls);
    }
    input.clearAll();
    resumeEngine();
    await _loadCampaignStartNode();
    syncCampaignExploration();
    publishUiSnapshot(force: true);
  }

  Future<void> _prewarmCampaignArt() async {
    await Future.wait(
      campaignPrewarmAssetPaths.map((assetPath) async {
        try {
          await images.load(assetPath);
        } catch (_) {
          // Procedural fallbacks keep the run playable if optional art is
          // missing. Successful images stay cached for hitch-free first use.
        }
      }),
    );
  }

  void startSurvivalRun([PlayerWeapon? weapon]) => unawaited(
    _startSurvivalRun(
      weapon ?? _selectedRunWeapon ?? PlayerWeapon.sword,
      waitForVisuals: false,
    ),
  );

  Future<void> _startSurvivalRun(
    PlayerWeapon weapon, {
    bool waitForVisuals = true,
  }) async {
    await ready();
    if (waitForVisuals) await world.player.visualLoadAttempted;
    unawaited(audio.unlockFromUserGesture());
    mode = PatchWorldMode.survival;
    _selectedRunWeapon = weapon;
    _weaponSelectionForSurvival = true;
    world.player.configureLoadout(
      weapon,
      assistMode: settings.value.assistMode,
    );
    runState.reset();
    campaignExploration.reset();
    damageLabProgress.reset();
    temporalHallProgress.reset();
    collisionArchiveProgress.reset();
    runItems.reset();
    weaponBuild.reset();
    survivalWeaponBuild.reset();
    survivalItems.reset();
    survivalRun.reset();
    pendingSurvivalItemReward = null;
    _queuedSurvivalItemRewards.clear();
    if (survivalQaStartCombo > 0) {
      survivalRun.seedComboForQa(survivalQaStartCombo);
    }
    survivalResult.value = null;
    survivalRun.elapsedSeconds = survivalQaStartSecond.toDouble();
    _applySurvivalQaBuild();
    completedRun.value = null;
    ruleEngine.setRules(const <GameRule>[]);
    overlays.remove(OverlayIds.title);
    if (!overlays.isActive(OverlayIds.hud)) overlays.add(OverlayIds.hud);
    if (!overlays.isActive(OverlayIds.touchControls)) {
      overlays.add(OverlayIds.touchControls);
    }
    input.clearAll();
    currentRoom = RoomId.survivalArena;
    resumeEngine();
    // A survival run must always receive a fresh director timeline. This also
    // keeps QA start-second builds from replaying every earlier milestone.
    await world.loadRoom(currentRoom);
    if (survivalQaItemRewardDemo) {
      queueSurvivalItemReward(SurvivalItemRewardSource.regionBoss);
    }
    if (survivalQaPerfectDodgeDemo) {
      recordSurvivalPerfectDodge(world.player.position.clone());
    }
    if (survivalQaHoundBreakDemo) {
      recordSurvivalHoundBreak(world.player.position.clone());
    }
    if (survivalQaPhaseExecutionDemo) {
      recordSurvivalHoundBreak(
        world.player.position.clone(),
        phaseExecution: true,
      );
    }
    publishUiSnapshot(force: true);
  }

  void _applySurvivalQaBuild() {
    if (survivalQaBuild.isEmpty) return;
    for (final entry in survivalQaBuild.split(',')) {
      final parts = entry.split(':');
      if (parts.length != 2) continue;
      final requestedTier = int.tryParse(parts[1])?.clamp(1, 3);
      if (requestedTier == null) continue;
      PatchDefinition? patch;
      for (final candidate in SurvivalUpgradeCatalog.all) {
        if (candidate.id == parts[0] ||
            candidate.id.split('.').last == parts[0]) {
          patch = candidate;
          break;
        }
      }
      if (patch == null) continue;
      runState.selectPatch(patch.id);
      for (var tier = 0; tier < requestedTier; tier += 1) {
        survivalRun.upgradePatch(
          patch.id,
          riskTier: SurvivalUpgradeCatalog.riskTierFor(patch),
        );
      }
    }
  }

  void recordSurvivalKill({
    bool elite = false,
    bool miniBoss = false,
    int rewardMultiplier = 1,
  }) {
    if (mode != PatchWorldMode.survival) return;
    final comboBefore = survivalRun.combo;
    final leveledUp = survivalRun.recordKill(
      elite: elite,
      miniBoss: miniBoss,
      rewardMultiplier:
          rewardMultiplier * survivalModifiers.killExperienceMultiplier,
    );
    final modifiers = survivalModifiers;
    if (modifiers.turboBonusShardInterval case final int interval
        when interval > 0 && survivalRun.kills % interval == 0) {
      world.spawnDataShards(world.player.position, count: 1);
    }
    if (modifiers.turboOverclockOnKill) {
      survivalRun.triggerTurboOverclock();
    }
    final flowDataReward = SurvivalRunState.flowDataRewardForCombo(
      survivalRun.combo,
    );
    final criticalFlowTriggered =
        survivalRun.combo > comboBefore && survivalRun.combo % 20 == 0;
    if (flowDataReward > 0) {
      world.spawnDataShards(
        world.player.position,
        count: flowDataReward,
        alternatingCorruption: false,
      );
    }
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      activeRoom.registerRegionEventKill();
      if (criticalFlowTriggered) {
        activeRoom.showCriticalFlow();
      } else {
        activeRoom.showComboMilestone(
          survivalRun.combo,
          flowMultiplier: survivalRun.flowMultiplier,
          dataReward: flowDataReward,
        );
      }
      if (flowDataReward > 0 && survivalRun.combo >= 10) {
        triggerImpactFeedback();
      }
      if (criticalFlowTriggered) {
        world.spawnCriticalFlowRing(world.player.position);
        triggerImpactFeedback();
      }
    }
    publishUiSnapshot(force: true);
    if (leveledUp && pendingSurvivalUpgrade == null) {
      _openSurvivalUpgrade();
    }
  }

  int recordSurvivalKillAt(
    Vector2 position, {
    bool elite = false,
    bool miniBoss = false,
    int rewardMultiplier = 1,
  }) {
    if (mode != PatchWorldMode.survival) return 0;
    final scoreBefore = survivalRun.score;
    recordSurvivalKill(
      elite: elite,
      miniBoss: miniBoss,
      rewardMultiplier: rewardMultiplier,
    );
    final gainedScore = math.max(0, survivalRun.score - scoreBefore);
    world.spawnSurvivalScorePopup(
      position,
      score: gainedScore,
      elite: elite,
      miniBoss: miniBoss,
    );
    if (elite || miniBoss) triggerImpactFeedback();
    return gainedScore;
  }

  void recordSurvivalHit({String causeId = 'unknown', int amount = 1}) {
    if (mode != PatchWorldMode.survival) return;
    survivalRun.recordHit(causeId: causeId, amount: amount);
    publishUiSnapshot(force: true);
  }

  int recordSurvivalPerfectDodge(Vector2 position) {
    if (mode != PatchWorldMode.survival) return 0;
    final scoreBefore = survivalRun.score;
    survivalRun.recordPerfectDodge();
    final gainedScore = math.max(0, survivalRun.score - scoreBefore);
    world.spawnDataShards(position, count: 1, alternatingCorruption: false);
    world.spawnPerfectDodgeBurst(position, score: gainedScore);
    publishUiSnapshot(force: true);
    return gainedScore;
  }

  int recordSurvivalHoundBreak(
    Vector2 position, {
    bool phaseExecution = false,
  }) {
    if (mode != PatchWorldMode.survival) return 0;
    final scoreBefore = survivalRun.score;
    survivalRun.recordHoundBreak();
    if (phaseExecution) survivalRun.recordPhaseExecution();
    final gainedScore = math.max(0, survivalRun.score - scoreBefore);
    world.spawnDataShards(
      position,
      count: phaseExecution ? 2 : 1,
      alternatingCorruption: false,
    );
    if (phaseExecution) {
      world.spawnPhaseExecutionBurst(position, score: gainedScore);
    } else {
      world.spawnHoundBreakBurst(position, score: gainedScore);
    }
    triggerImpactFeedback();
    publishUiSnapshot(force: true);
    return gainedScore;
  }

  void recordSurvivalMilestone(SurvivalMeaningfulEvent event) {
    if (mode != PatchWorldMode.survival) return;
    survivalRun.telemetry.record(survivalRun.elapsedSeconds, event);
  }

  void triggerSurvivalDataSurge(Vector2 position) {
    if (mode != PatchWorldMode.survival) return;
    survivalRun.triggerDataSurge();
    world.spawnDataSurgeRing(position);
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      activeRoom.showPatchPowerDemo(
        '${localization.text('hud.dataSurge')} // '
        '${localization.text('survivalAlert.weaponDamageBonus')}',
      );
    }
    publishUiSnapshot(force: true);
  }

  SurvivalSessionSummary get survivalSessionSummary {
    final persistedEntries = survivalPlaytestHistory.map(
      (record) => SurvivalSessionEntry(
        patchIds: record.patchIds,
        weapon: record.weapon,
      ),
    );
    final inMemoryEntries = survivalSessionHistory.map(
      (result) => SurvivalSessionEntry(
        patchIds: result.patchTiers.keys.toSet(),
        weapon: result.selectedWeapon,
      ),
    );
    return SurvivalSessionSummary.fromEntries(
      survivalPlaytestHistory.isEmpty ? inMemoryEntries : persistedEntries,
    );
  }

  SurvivalBalanceReport get survivalBalanceReport =>
      SurvivalBalanceReport.fromRecords(survivalPlaytestHistory);

  bool _openSurvivalUpgrade() {
    while (survivalRun.hasPendingUpgrade) {
      final upgradeLevel = survivalRun.takePendingUpgradeLevel()!;
      final choices = SurvivalUpgradeCatalog.choicesForLevel(
        upgradeLevel,
        patchTiers: survivalRun.patchTiers,
      );
      if (choices.isEmpty) {
        survivalRun.recordMaxedBuildLevel();
        final activeRoom = world.activeRoom;
        if (activeRoom is SurvivalArenaController) {
          activeRoom.showPatchPowerDemo(
            localization.text(
              'survivalAlert.buildMaxed',
              parameters: const <String, Object>{'score': 250},
            ),
          );
        }
        continue;
      }
      pendingSurvivalUpgrade = SurvivalUpgradeRequest(
        level: upgradeLevel,
        choices: choices,
      );
      input.clearAll();
      pauseEngine();
      overlays.add(OverlayIds.survivalUpgrade);
      return true;
    }
    return false;
  }

  bool get canRerouteSurvivalUpgrade {
    final request = pendingSurvivalUpgrade;
    if (request == null || survivalRun.reroutesRemaining <= 0) return false;
    final rerouted = SurvivalUpgradeCatalog.reroutedChoicesForLevel(
      level: request.level,
      currentChoices: request.choices,
      patchTiers: survivalRun.patchTiers,
    );
    return !_samePatchChoices(request.choices, rerouted);
  }

  bool rerouteSurvivalUpgrade() {
    final request = pendingSurvivalUpgrade;
    if (request == null || survivalRun.reroutesRemaining <= 0) return false;
    final rerouted = SurvivalUpgradeCatalog.reroutedChoicesForLevel(
      level: request.level,
      currentChoices: request.choices,
      patchTiers: survivalRun.patchTiers,
    );
    if (_samePatchChoices(request.choices, rerouted)) return false;
    if (!survivalRun.consumeReroute()) return false;
    pendingSurvivalUpgrade = SurvivalUpgradeRequest(
      level: request.level,
      choices: rerouted,
    );
    return true;
  }

  bool _samePatchChoices(
    List<PatchDefinition> left,
    List<PatchDefinition> right,
  ) {
    if (left.length != right.length) return false;
    final leftIds = left.map((patch) => patch.id).toSet();
    return right.every((patch) => leftIds.contains(patch.id));
  }

  bool selectSurvivalUpgrade(String patchId) {
    final request = pendingSurvivalUpgrade;
    if (request == null) return false;
    PatchDefinition? patch;
    for (final choice in request.choices) {
      if (choice.id == patchId) patch = choice;
    }
    if (patch == null) return false;
    final fusionsBefore = survivalModifiers.activeFusionIds;
    runState.selectPatch(patch.id);
    survivalRun.upgradePatch(
      patch.id,
      riskTier: SurvivalUpgradeCatalog.riskTierFor(patch),
    );
    final unlockedFusions = SurvivalPatchFusions.newlyUnlocked(
      before: fusionsBefore,
      after: survivalModifiers.activeFusionIds,
    );
    pendingSurvivalUpgrade = null;
    input.clearAll();
    publishUiSnapshot(force: true);
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      if (unlockedFusions case [final fusionId, ...]) {
        survivalRun.telemetry.record(
          survivalRun.elapsedSeconds,
          SurvivalMeaningfulEvent.fusionUnlocked,
        );
        activeRoom.showFusionOnline(localization.text('$fusionId.title'));
      } else {
        activeRoom.showPatchPowerDemo(patch.title);
      }
    }
    if (request.level % 3 == 0 && _openSurvivalWeaponUpgrade(request.level)) {
      overlays.remove(OverlayIds.survivalUpgrade);
      return true;
    }
    if (_openSurvivalUpgrade()) return true;
    if (_openNextSurvivalItemReward()) {
      overlays.remove(OverlayIds.survivalUpgrade);
      return true;
    }
    overlays.remove(OverlayIds.survivalUpgrade);
    resumeEngine();
    return false;
  }

  bool _openSurvivalWeaponUpgrade(int level) {
    final weapon = _selectedRunWeapon ?? world.player.selectedWeapon;
    final choices = survivalWeaponBuild.choicesFor(weapon);
    if (choices.isEmpty) return false;
    pendingSurvivalWeaponUpgrade = SurvivalWeaponUpgradeRequest(
      level: level,
      choices: choices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.survivalWeaponUpgrade);
    return true;
  }

  bool selectSurvivalWeaponUpgrade(SurvivalWeaponUpgradeId id) {
    final request = pendingSurvivalWeaponUpgrade;
    if (request == null || !request.choices.contains(id)) return false;
    final nextTier = survivalWeaponBuild.upgrade(id);
    pendingSurvivalWeaponUpgrade = null;
    overlays.remove(OverlayIds.survivalWeaponUpgrade);
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      activeRoom.showWeaponBuildOnline(
        localization.text('${id.id}.title'),
        tier: nextTier,
      );
    }
    publishUiSnapshot(force: true);
    if (_openSurvivalUpgrade()) return true;
    if (_openNextSurvivalItemReward()) return true;
    resumeEngine();
    return false;
  }

  void queueSurvivalItemReward(SurvivalItemRewardSource source) {
    if (mode != PatchWorldMode.survival || survivalResult.value != null) return;
    _queuedSurvivalItemRewards.add(source);
    _openNextSurvivalItemReward();
  }

  bool _openNextSurvivalItemReward() {
    if (mode != PatchWorldMode.survival ||
        survivalResult.value != null ||
        pendingSurvivalUpgrade != null ||
        pendingSurvivalWeaponUpgrade != null ||
        pendingSurvivalItemReward != null) {
      return false;
    }
    final weapon = _selectedRunWeapon ?? world.player.selectedWeapon;
    while (_queuedSurvivalItemRewards.isNotEmpty) {
      final source = _queuedSurvivalItemRewards.removeAt(0);
      final choices = survivalItems.choices(
        weapon: weapon,
        unlockedAbilities: survivalMetaAbilities,
      );
      survivalItems.advanceReward();
      if (choices.isEmpty) {
        survivalRun.bonusScore += 500;
        continue;
      }
      pendingSurvivalItemReward = SurvivalItemRewardRequest(
        source: source,
        choices: choices,
      );
      input.clearAll();
      pauseEngine();
      overlays.add(OverlayIds.survivalItemReward);
      publishUiSnapshot(force: true);
      return true;
    }
    return false;
  }

  bool selectSurvivalItem(SurvivalItemId id) {
    final request = pendingSurvivalItemReward;
    if (request == null || !request.choices.contains(id)) return false;
    final synergiesBefore = survivalItems.activeSynergyTiers.values.fold<int>(
      0,
      (total, tier) => total + tier,
    );
    if (!survivalItems.acquire(id)) return false;
    final synergiesAfter = survivalItems.activeSynergyTiers.values.fold<int>(
      0,
      (total, tier) => total + tier,
    );
    survivalRun.recordSurvivalItemAcquired(
      newSynergies: math.max(0, synergiesAfter - synergiesBefore),
    );
    pendingSurvivalItemReward = null;
    overlays.remove(OverlayIds.survivalItemReward);
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      activeRoom.showWeaponBuildOnline(
        localization.text(
          '${SurvivalItemCatalog.definition(id).localizationPrefix}.title',
        ),
        tier: survivalItems.items.length,
      );
    }
    publishUiSnapshot(force: true);
    if (_openSurvivalUpgrade()) return true;
    if (_openNextSurvivalItemReward()) return true;
    resumeEngine();
    return true;
  }

  void queuePointerAttack() {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null &&
        pendingWeaponBuildSelection == null) {
      input.queueAttack();
    }
  }

  void queueTouchAttack() => queuePointerAttack();

  void queueTouchParry() {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null &&
        pendingWeaponBuildSelection == null) {
      input.queueParry();
    }
  }

  void beginTouchSpecialAbility() {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null &&
        pendingWeaponBuildSelection == null &&
        world.isReady) {
      input.queueSpecialPress(world.player.facingDirection);
    }
  }

  void endTouchSpecialAbility() => input.queueSpecialRelease();

  void queueTouchInteract() {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null &&
        pendingWeaponBuildSelection == null) {
      input.queueInteract();
    }
  }

  void setTouchMovement(double x, double y) {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null &&
        pendingWeaponBuildSelection == null) {
      input.setVirtualMovement(x, y);
    }
  }

  void clearTouchMovement() => input.clearVirtualMovement();

  void triggerImpactFeedback({double intensity = 1}) {
    if (settings.value.screenShake == ScreenShakeSetting.off) return;
    _screenShakeRemaining =
        settings.value.screenShake == ScreenShakeSetting.reduced ? 0.08 : 0.14;
    _screenShakePhase = 0;
    _screenShakeIntensity = intensity.clamp(.35, 1.8).toDouble();
  }

  void triggerPlayerWeaponImpactFeedback({
    required String sourceId,
    required Vector2 position,
    required Vector2 direction,
    required int damage,
  }) {
    if (mode != PatchWorldMode.survival || !world.isReady) return;
    final weapon = switch (sourceId) {
      final id when id.contains('.sword.') => PlayerWeapon.sword,
      final id when id.contains('.gauntlet.') => PlayerWeapon.gauntlet,
      final id when id.contains('.gun.') => PlayerWeapon.gun,
      _ => null,
    };
    if (weapon == null) return;
    final heavy =
        damage >= 3 ||
        sourceId.contains('Counter') ||
        sourceId.contains('groundSlam') ||
        sourceId.contains('quakeCore') ||
        sourceId.contains('protocolVolley');
    unawaited(
      world.tryAddCombatEffect(
        WeaponImpactBurstComponent(
          position: position.clone(),
          weapon: weapon,
          direction: direction,
          heavy: heavy,
        ),
      ),
    );
    if (_weaponImpactFeedbackCooldown > 0) return;
    _weaponImpactFeedbackCooldown = .035;
    final intensity = switch (weapon) {
      PlayerWeapon.sword => heavy ? 1.15 : .78,
      PlayerWeapon.gauntlet => heavy ? 1.5 : 1.0,
      PlayerWeapon.gun => heavy ? .95 : .58,
    };
    triggerImpactFeedback(intensity: intensity);
    triggerCombatSlowMotion(
      duration: switch (weapon) {
        PlayerWeapon.sword => heavy ? .065 : .042,
        PlayerWeapon.gauntlet => heavy ? .085 : .058,
        PlayerWeapon.gun => heavy ? .045 : .024,
      },
      scale: switch (weapon) {
        PlayerWeapon.sword => .22,
        PlayerWeapon.gauntlet => .12,
        PlayerWeapon.gun => .38,
      },
    );
    unawaited(audio.playWeaponImpact(weapon, heavy: heavy));
  }

  void triggerCombatSlowMotion({double duration = .38, double scale = .28}) {
    _combatSlowMotionRemaining = math.max(
      _combatSlowMotionRemaining,
      duration.clamp(0, 1.2).toDouble(),
    );
    _combatSlowMotionScale = math.min(
      _combatSlowMotionScale,
      scale.clamp(.1, 1).toDouble(),
    );
  }

  void _updateScreenShake(double dt) {
    final activeRoom = world.activeRoom;
    final platformRoom = activeRoom is PlatformerRoomGeometry
        ? activeRoom as PlatformerRoomGeometry
        : null;
    final cameraTarget = switch (activeRoom) {
      PlatformerRoomCameraTarget room => room.cameraTargetFor(
        world.player.position,
      ),
      _ => world.player.position,
    };
    final desiredHorizontalLead = switch (activeRoom) {
      PlatformerRoomCameraLead room =>
        room.horizontalCameraLead * world.player.facingDirection,
      _ => 0.0,
    };
    final cameraLeadBlend = 1 - math.exp(-dt * 4.2);
    _horizontalCameraLead +=
        (desiredHorizontalLead - _horizontalCameraLead) * cameraLeadBlend;
    if ((_horizontalCameraLead - desiredHorizontalLead).abs() < .05) {
      _horizontalCameraLead = desiredHorizontalLead;
    }
    final composedCameraTarget = Vector2(
      cameraTarget.x + _horizontalCameraLead,
      cameraTarget.y,
    );
    final targetZoom = switch (activeRoom) {
      PlatformerRoomCameraZoom room => room.cameraZoomFor(
        world.player.position,
      ),
      _ => 1.0,
    }.clamp(0.9, 1.4).toDouble();
    final zoomBlend = 1 - math.exp(-dt * 5.5);
    final nextZoom =
        camera.viewfinder.zoom +
        (targetZoom - camera.viewfinder.zoom) * zoomBlend;
    camera.viewfinder.zoom = (nextZoom - targetZoom).abs() < .001
        ? targetZoom
        : nextZoom;
    final halfVisibleWidth = logicalWidth / (camera.viewfinder.zoom * 2);
    final halfVisibleHeight = logicalHeight / (camera.viewfinder.zoom * 2);
    final desiredCenterX = platformRoom != null
        ? platformRoom.worldSize.x <= halfVisibleWidth * 2
              ? platformRoom.worldSize.x / 2
              : composedCameraTarget.x
                    .clamp(
                      halfVisibleWidth,
                      platformRoom.worldSize.x - halfVisibleWidth,
                    )
                    .toDouble()
        : logicalWidth / 2;
    final desiredCenterY = platformRoom != null
        ? platformRoom.worldSize.y <= halfVisibleHeight * 2
              ? platformRoom.worldSize.y / 2
              : composedCameraTarget.y
                    .clamp(
                      halfVisibleHeight,
                      platformRoom.worldSize.y - halfVisibleHeight,
                    )
                    .toDouble()
        : logicalHeight / 2;
    final followPolicy = activeRoom is PlatformerRoomCameraFollow
        ? activeRoom as PlatformerRoomCameraFollow
        : null;
    if (!identical(_cameraFollowRoom, activeRoom)) {
      _cameraFollowRoom = activeRoom;
      _cameraFollowPosition.setValues(desiredCenterX, desiredCenterY);
    } else if (followPolicy != null) {
      final deadZoneCenterX = _cameraCenterOutsideDeadZone(
        current: _cameraFollowPosition.x,
        target: desiredCenterX,
        radius: followPolicy.horizontalCameraDeadZone,
      );
      final deadZoneCenterY = _cameraCenterOutsideDeadZone(
        current: _cameraFollowPosition.y,
        target: desiredCenterY,
        radius: followPolicy.verticalCameraDeadZone,
      );
      final followBlend =
          1 - math.exp(-dt * followPolicy.cameraFollowResponsiveness);
      _cameraFollowPosition.setValues(
        _cameraFollowPosition.x +
            (deadZoneCenterX - _cameraFollowPosition.x) * followBlend,
        _cameraFollowPosition.y +
            (deadZoneCenterY - _cameraFollowPosition.y) * followBlend,
      );
    } else {
      _cameraFollowPosition.setValues(desiredCenterX, desiredCenterY);
    }
    final playerCameraSafety = activeRoom is PlatformerRoomPlayerCameraSafety
        ? activeRoom as PlatformerRoomPlayerCameraSafety
        : null;
    if ((playerCameraSafety?.keepsPlayerInsideHorizontalSafeArea ?? true) &&
        platformRoom != null &&
        platformRoom.worldSize.x > halfVisibleWidth * 2) {
      _cameraFollowPosition.x = clampPlatformerCameraCenterToPlayer(
        currentCenter: _cameraFollowPosition.x,
        playerCoordinate: world.player.position.x,
        halfVisibleExtent: halfVisibleWidth,
        safeInset: 120 / camera.viewfinder.zoom,
        minimumCenter: halfVisibleWidth,
        maximumCenter: platformRoom.worldSize.x - halfVisibleWidth,
      );
    }
    if (_screenShakeRemaining <= 0) {
      _screenShakeIntensity = 1;
      camera.viewfinder.position = _cameraFollowPosition.clone();
      return;
    }
    _screenShakeRemaining = math.max(0, _screenShakeRemaining - dt);
    _screenShakePhase += dt * 95;
    final amplitude =
        (settings.value.screenShake == ScreenShakeSetting.reduced ? 1.5 : 3.2) *
        _screenShakeIntensity;
    camera.viewfinder.position = Vector2(
      _cameraFollowPosition.x + math.sin(_screenShakePhase) * amplitude,
      _cameraFollowPosition.y + math.cos(_screenShakePhase * 1.7) * amplitude,
    );
  }

  double _cameraCenterOutsideDeadZone({
    required double current,
    required double target,
    required double radius,
  }) {
    if (radius <= 0) return target;
    if (target < current - radius) return target + radius;
    if (target > current + radius) return target - radius;
    return current;
  }

  @override
  void update(double dt) {
    if (!world.isReady) {
      clock.beginFrame(
        realDt: dt,
        simulationAdvances: true,
        enemySpeedMultiplier: 1,
      );
      super.update(dt);
      return;
    }
    if (survivalQaAutoAttack && mode == PatchWorldMode.survival) {
      _survivalQaAutoAttackRemaining -= dt;
      if (_survivalQaAutoAttackRemaining <= 0) {
        _survivalQaAutoAttackRemaining = .08;
        input.queueAttack();
      }
    }
    _weaponImpactFeedbackCooldown = math.max(
      0,
      _weaponImpactFeedbackCooldown - dt.clamp(0, 1 / 15),
    );
    final movement = _cinematicInputLocked
        ? Vector2.zero()
        : input.movementAxis;
    final hasGameplayIntent = !_cinematicInputLocked && input.hasGameplayIntent;
    final hasActivePlayerAction =
        !_cinematicInputLocked && world.player.hasActiveWeaponAction;
    final activeRoom = world.activeRoom;
    final survivalTempo = activeRoom is SurvivalArenaController
        ? activeRoom.enemySpeedMultiplier
        : 1.0;
    final survivalQaTempo = mode == PatchWorldMode.survival
        ? survivalQaTimeScale
        : 1.0;
    enemyTempo.update(dt);
    final combatTimeScale = _combatSlowMotionRemaining > 0
        ? _combatSlowMotionScale
        : 1.0;
    _combatSlowMotionRemaining = math.max(
      0,
      _combatSlowMotionRemaining - dt.clamp(0, 1 / 15),
    );
    if (_combatSlowMotionRemaining <= 0) _combatSlowMotionScale = 1;
    if (mode == PatchWorldMode.survival &&
        survivalModifiers.frameOverclockOnBurstEnd &&
        enemyTempo.didFrameBurstEnd) {
      survivalRun.triggerFrameOverclock();
    }
    clock.beginFrame(
      realDt: dt,
      simulationAdvances:
          currentRoom != RoomId.temporalHall ||
          hasGameplayIntent ||
          hasActivePlayerAction,
      enemySpeedMultiplier:
          enemyTempo.speedMultiplier *
          survivalTempo *
          survivalQaTempo *
          (settings.value.assistMode ? 0.85 : 1),
      simulationSpeedMultiplier: combatTimeScale,
    );
    runMetrics.update(clock.realDt);
    world.player.setMovementInput(movement);
    world.player.setJumpHeld(!_cinematicInputLocked && input.jumpHeld);
    world.player.setSpecialAbilityHeld(
      !_cinematicInputLocked && input.specialHeld,
    );
    if (!_cinematicInputLocked && input.consumeJump()) {
      world.player.queueJump();
    }
    if (!_cinematicInputLocked) {
      if (input.consumeSpecialPressDirection() case final double direction) {
        world.player.beginSpecialAbility(direction);
      }
      if (input.consumeSpecialRelease()) world.player.endSpecialAbility();
    }
    patternTracker.update(clock.realDt);
    if (movement.length2 > 0) {
      patternTracker.recordMovement(movement.x, movement.y);
    }
    patchEffects.update(
      playerStatusDt: clock.playerStatusDt,
      isPlayerMoving: movement.length2 > 0,
      motionTaxTier: mode == PatchWorldMode.survival
          ? survivalModifiers.motionTaxTier
          : 0,
      allowMovingVentCharge:
          mode == PatchWorldMode.survival &&
          survivalModifiers.ghostVentFusion &&
          activeRoom is SurvivalArenaController &&
          activeRoom.isPhaseWindowOpen,
      playerPosition: world.player.position,
    );
    if (!_cinematicInputLocked && input.consumeAttack()) {
      patternTracker.recordAttack();
      world.player.tryAttack();
    }
    if (!_cinematicInputLocked && input.consumeParry()) world.player.tryParry();
    if (!_cinematicInputLocked && input.consumeInteract()) {
      world.player.tryInteract();
    }
    _uiPublishAccumulator += clock.realDt;
    if (_uiPublishAccumulator >= 0.10) {
      _uiPublishAccumulator = 0;
      syncCampaignExploration();
      publishUiSnapshot();
    }
    super.update(dt);
    _updateScreenShake(clock.realDt);
  }

  void openRoomOnePatchSelection() {
    if (!_canOpenChapterPatchSelection(
      bossNode: CampaignNodeId.overflowWarden,
      bossDefeated: damageLabProgress.bossDefeated,
      bossRewardClaimed: damageLabProgress.bossRewardClaimed,
      patchApplied: damageLabProgress.patchApplied,
    )) {
      return;
    }
    pendingPatchSelection = const PatchSelectionRequest(
      roomId: 'damage-lab',
      choices: PatchCatalog.roomOneChoices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.patchSelection);
  }

  void openRoomOneBuildSelection(int encounterId) {
    if (mode != PatchWorldMode.campaign ||
        encounterId < 0 ||
        encounterId > 2 ||
        pendingWeaponBuildSelection != null ||
        pendingPatchSelection != null ||
        damageLabProgress.claimedBuildRewardIds.contains(encounterId)) {
      return;
    }
    final weapon = _selectedRunWeapon ?? world.player.selectedWeapon;
    final choices = WeaponBuildCatalog.choicesFor(weapon)
        .where((upgrade) => weaponBuild.canUpgrade(upgrade, weapon))
        .toList(growable: false);
    if (choices.isEmpty) return;
    pendingWeaponBuildSelection = WeaponBuildSelectionRequest(
      encounterId: encounterId,
      weapon: weapon,
      choices: choices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.buildSelection);
  }

  bool selectRoomOneBuildUpgrade(WeaponBuildUpgradeId upgradeId) {
    final request = pendingWeaponBuildSelection;
    if (request == null || !request.choices.contains(upgradeId)) return false;
    if (!weaponBuild.upgrade(upgradeId, request.weapon)) return false;
    damageLabProgress.claimedBuildRewardIds.add(request.encounterId);
    pendingWeaponBuildSelection = null;
    overlays.remove(OverlayIds.buildSelection);
    input.clearAll();
    publishUiSnapshot(force: true);
    resumeEngine();
    return true;
  }

  void selectPatch(String patchId) {
    unawaited(_selectPatchAndContinue(patchId));
  }

  bool travelToCampaignNode(
    CampaignNodeId targetNode, {
    required CampaignNodeEntry entry,
  }) {
    if (!canTravelToCampaignNode(targetNode)) return false;
    unawaited(
      Future<void>.microtask(
        () => _travelToCampaignNode(targetNode, entry: entry),
      ),
    );
    return true;
  }

  /// Checks the directional door/map progression gate without scheduling a
  /// room transition. This is also the single predicate used by direct travel.
  bool canTravelToCampaignNode(
    CampaignNodeId targetNode, {
    PlayerWeapon? weapon,
  }) {
    if (mode != PatchWorldMode.campaign || _roomTransitionInProgress) {
      return false;
    }
    syncCampaignExploration();
    final currentNode = campaignExploration.currentNode;
    if (currentNode == null || currentNode == targetNode) return false;
    final activeRoom = world.activeRoom;
    if (activeRoom is CampaignNodeTravelGuard &&
        !(activeRoom as CampaignNodeTravelGuard).canLeaveCampaignNode(
          targetNode,
        )) {
      return false;
    }
    CampaignWorldConnection connection;
    try {
      connection = campaignWorld.connectionBetween(currentNode, targetNode);
    } on StateError {
      return false;
    }
    return _campaignConnectionPermits(
      connection,
      from: currentNode,
      to: targetNode,
      weapon:
          weapon ??
          _selectedRunWeapon ??
          (world.isReady ? world.player.selectedWeapon : PlayerWeapon.sword),
    );
  }

  bool isCampaignConnectionUnlocked(
    CampaignWorldConnection connection, {
    PlayerWeapon? weapon,
  }) => _campaignConnectionPermits(
    connection,
    from: connection.from,
    to: connection.to,
    weapon:
        weapon ??
        _selectedRunWeapon ??
        (world.isReady ? world.player.selectedWeapon : PlayerWeapon.sword),
  );

  bool _campaignConnectionPermits(
    CampaignWorldConnection connection, {
    required CampaignNodeId from,
    required CampaignNodeId to,
    required PlayerWeapon weapon,
  }) =>
      campaignExploration.canTraverse(
        connection,
        weapon: weapon,
        optimizerGateReady: isOptimizerGateReady,
      ) &&
      _campaignProgressPermits(from, to);

  bool _campaignProgressPermits(
    CampaignNodeId currentNode,
    CampaignNodeId targetNode,
  ) {
    if (currentNode == CampaignNodeId.damageWorkshop &&
        targetNode == CampaignNodeId.damageAssembly) {
      return damageLabProgress.clearedEncounterIds.contains(0);
    }
    if (currentNode == CampaignNodeId.damageAssembly &&
        targetNode == CampaignNodeId.damageOverflow) {
      return damageLabProgress.clearedEncounterIds.contains(1);
    }
    if (currentNode == CampaignNodeId.damageAssembly &&
        const <CampaignNodeId>{
          CampaignNodeId.damageDashCache,
          CampaignNodeId.damageUpperArchive,
          CampaignNodeId.damageTurretControl,
        }.contains(targetNode)) {
      return damageLabProgress.clearedEncounterIds.contains(1);
    }
    if (currentNode == CampaignNodeId.damageOverflow &&
        targetNode == CampaignNodeId.overflowWarden) {
      return damageLabProgress.allEncountersCleared;
    }
    if (currentNode == CampaignNodeId.overflowWarden &&
        targetNode == CampaignNodeId.damageOverflow) {
      return damageLabProgress.bossDefeated;
    }
    if (currentNode == CampaignNodeId.overflowWarden &&
        targetNode == CampaignNodeId.temporalAscent) {
      return damageLabProgress.bossDefeated && damageLabProgress.patchApplied;
    }
    if (currentNode == CampaignNodeId.bootSector &&
        targetNode == CampaignNodeId.temporalAscent) {
      return damageLabProgress.patchApplied;
    }
    if (currentNode == CampaignNodeId.temporalAscent &&
        targetNode == CampaignNodeId.temporalFracture) {
      return temporalHallProgress.isRoomComplete(0);
    }
    if (currentNode == CampaignNodeId.temporalFracture &&
        targetNode == CampaignNodeId.temporalPendulum) {
      return temporalHallProgress.isRoomComplete(1);
    }
    if (currentNode == CampaignNodeId.temporalFracture &&
        const <CampaignNodeId>{
          CampaignNodeId.temporalDashRift,
          CampaignNodeId.temporalUpperLoop,
          CampaignNodeId.temporalRelayControl,
        }.contains(targetNode)) {
      return temporalHallProgress.isRoomComplete(1);
    }
    if (currentNode == CampaignNodeId.temporalPendulum &&
        targetNode == CampaignNodeId.chronoJailer) {
      return temporalHallProgress.allRoomsComplete;
    }
    if (currentNode == CampaignNodeId.chronoJailer &&
        targetNode == CampaignNodeId.temporalPendulum) {
      return temporalHallProgress.bossDefeated;
    }
    if (currentNode == CampaignNodeId.chronoJailer &&
        targetNode == CampaignNodeId.bootSector) {
      return temporalHallProgress.bossDefeated &&
          temporalHallProgress.patchApplied;
    }
    if (currentNode == CampaignNodeId.chronoJailer &&
        targetNode == CampaignNodeId.collisionCompression) {
      return temporalHallProgress.bossDefeated &&
          temporalHallProgress.patchApplied;
    }
    if (currentNode == CampaignNodeId.collisionCompression &&
        targetNode == CampaignNodeId.chronoJailer) {
      return temporalHallProgress.bossDefeated &&
          temporalHallProgress.patchApplied;
    }
    if (currentNode == CampaignNodeId.bootSector &&
        targetNode == CampaignNodeId.collisionCompression) {
      return temporalHallProgress.bossDefeated &&
          temporalHallProgress.patchApplied;
    }
    if (currentNode == CampaignNodeId.bootSector &&
        targetNode == CampaignNodeId.optimizerCore) {
      return isOptimizerGateReady;
    }
    if (currentNode == CampaignNodeId.collisionCompression &&
        targetNode == CampaignNodeId.collisionFracture) {
      return collisionArchiveProgress.isRoomComplete(0);
    }
    if (currentNode == CampaignNodeId.collisionFracture &&
        targetNode == CampaignNodeId.collisionMerge) {
      return collisionArchiveProgress.isRoomComplete(1);
    }
    if (currentNode == CampaignNodeId.collisionFracture &&
        const <CampaignNodeId>{
          CampaignNodeId.collisionVectorCache,
          CampaignNodeId.collisionUpperMatrix,
          CampaignNodeId.collisionPrismControl,
        }.contains(targetNode)) {
      return collisionArchiveProgress.isRoomComplete(1);
    }
    if (currentNode == CampaignNodeId.collisionMerge &&
        targetNode == CampaignNodeId.kernelChimera) {
      return collisionArchiveProgress.allRoomsComplete;
    }
    if (currentNode == CampaignNodeId.kernelChimera &&
        targetNode == CampaignNodeId.collisionMerge) {
      return collisionArchiveProgress.bossDefeated;
    }
    if (currentNode == CampaignNodeId.kernelChimera &&
        targetNode == CampaignNodeId.bootSector) {
      return collisionArchiveProgress.bossDefeated &&
          collisionArchiveProgress.patchApplied;
    }
    return true;
  }

  Future<void> _travelToCampaignNode(
    CampaignNodeId targetNode, {
    required CampaignNodeEntry entry,
  }) async {
    _roomTransitionInProgress = true;
    input.clearAll();
    resumeEngine();
    try {
      currentRoom = switch (campaignWorld.nodes[targetNode]!.region) {
        CampaignRegion.bootSector => RoomId.bootSector,
        CampaignRegion.damageLab => RoomId.damageLab,
        CampaignRegion.temporalHall => RoomId.temporalHall,
        CampaignRegion.collisionArchive => RoomId.collisionArchive,
        CampaignRegion.optimizerCore => RoomId.optimizerCore,
      };
      await world.loadCampaignNode(targetNode, entry: entry);
      if (targetNode == CampaignNodeId.optimizerCore) {
        unawaited(audio.startOptimizerBgm());
      }
      syncCampaignExploration();
      publishUiSnapshot(force: true);
    } finally {
      input.clearAll();
      _roomTransitionInProgress = false;
      resumeEngine();
    }
  }

  Future<void> _selectPatchAndContinue(String patchId) async {
    final request = pendingPatchSelection;
    if (request == null ||
        !request.choices.any((PatchDefinition item) => item.id == patchId) ||
        !_isChapterPatchReady(request.roomId)) {
      return;
    }
    runState.selectPatch(patchId);
    pendingPatchSelection = null;
    overlays.remove(OverlayIds.patchSelection);
    _roomTransitionInProgress = true;
    input.clearAll();
    // Flame finalizes component removal/addition on update frames. The patch
    // overlay pauses the engine, so resume before awaiting the room swap to
    // avoid deadlocking on `existing.removed`.
    resumeEngine();
    try {
      if (request.roomId == 'damage-lab') {
        ruleEngine.removeRule(RuleIds.damageSignInverted);
        patchEffects.resetTransientForRoomTransition();
        damageLabProgress.patchApplied = true;
        currentRoom = RoomId.damageLab;
        await world.loadCampaignNode(
          CampaignNodeId.overflowWarden,
          entry: CampaignNodeEntry.west,
        );
      } else if (request.roomId == 'temporal-hall') {
        enemyTempo.resetForRoomRestart();
        patchEffects.resetTransientForRoomTransition();
        temporalHallProgress.patchApplied = true;
        currentRoom = RoomId.temporalHall;
        await world.loadCampaignNode(
          CampaignNodeId.chronoJailer,
          entry: CampaignNodeEntry.west,
        );
      } else if (request.roomId == 'collision-archive') {
        enemyTempo.resetForRoomRestart();
        patchEffects.resetTransientForRoomTransition();
        collisionArchiveProgress.patchApplied = true;
        currentRoom = RoomId.collisionArchive;
        await world.loadCampaignNode(
          CampaignNodeId.kernelChimera,
          entry: CampaignNodeEntry.west,
        );
      } else {
        throw StateError('Unknown patch room: ${request.roomId}');
      }
    } finally {
      input.clearAll();
      _roomTransitionInProgress = false;
      resumeEngine();
    }
    _consecutiveRoomDeaths = 0;
    _showPatchAppliedNotice(
      request.choices.singleWhere((item) => item.id == patchId),
    );
    publishUiSnapshot(force: true);
    resumeEngine();
  }

  void _showPatchAppliedNotice(PatchDefinition patch) {
    _patchNoticeTimer?.cancel();
    patchNotice.value = patch;
    if (!overlays.isActive(OverlayIds.patchApplied)) {
      overlays.add(OverlayIds.patchApplied);
    }
    _patchNoticeTimer = dart_async.Timer(const Duration(seconds: 6), () {
      patchNotice.value = null;
      overlays.remove(OverlayIds.patchApplied);
    });
  }

  void openRoomTwoPatchSelection() {
    if (!_canOpenChapterPatchSelection(
      bossNode: CampaignNodeId.chronoJailer,
      bossDefeated: temporalHallProgress.bossDefeated,
      bossRewardClaimed: temporalHallProgress.bossRewardClaimed,
      patchApplied: temporalHallProgress.patchApplied,
    )) {
      return;
    }
    pendingPatchSelection = const PatchSelectionRequest(
      roomId: 'temporal-hall',
      choices: PatchCatalog.roomTwoChoices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.patchSelection);
  }

  void openRoomThreePatchSelection() {
    if (!_canOpenChapterPatchSelection(
      bossNode: CampaignNodeId.kernelChimera,
      bossDefeated: collisionArchiveProgress.bossDefeated,
      bossRewardClaimed: collisionArchiveProgress.bossRewardClaimed,
      patchApplied: collisionArchiveProgress.patchApplied,
    )) {
      return;
    }
    pendingPatchSelection = const PatchSelectionRequest(
      roomId: 'collision-archive',
      choices: PatchCatalog.roomThreeChoices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.patchSelection);
  }

  bool _canOpenChapterPatchSelection({
    required CampaignNodeId bossNode,
    required bool bossDefeated,
    required bool bossRewardClaimed,
    required bool patchApplied,
  }) {
    if (mode != PatchWorldMode.campaign ||
        pendingPatchSelection != null ||
        pendingWeaponBuildSelection != null ||
        _roomTransitionInProgress ||
        !bossDefeated ||
        !bossRewardClaimed ||
        patchApplied) {
      return false;
    }
    final activeRoom = world.activeRoom;
    return activeRoom is CampaignNodeRoom &&
        (activeRoom as CampaignNodeRoom).campaignNodeId == bossNode;
  }

  bool _isChapterPatchReady(String roomId) => switch (roomId) {
    'damage-lab' => _canApplyChapterPatch(
      CampaignNodeId.overflowWarden,
      damageLabProgress.bossDefeated,
      damageLabProgress.bossRewardClaimed,
      damageLabProgress.patchApplied,
    ),
    'temporal-hall' => _canApplyChapterPatch(
      CampaignNodeId.chronoJailer,
      temporalHallProgress.bossDefeated,
      temporalHallProgress.bossRewardClaimed,
      temporalHallProgress.patchApplied,
    ),
    'collision-archive' => _canApplyChapterPatch(
      CampaignNodeId.kernelChimera,
      collisionArchiveProgress.bossDefeated,
      collisionArchiveProgress.bossRewardClaimed,
      collisionArchiveProgress.patchApplied,
    ),
    _ => false,
  };

  bool _canApplyChapterPatch(
    CampaignNodeId bossNode,
    bool bossDefeated,
    bool bossRewardClaimed,
    bool patchApplied,
  ) {
    final activeRoom = world.activeRoom;
    return mode == PatchWorldMode.campaign &&
        !_roomTransitionInProgress &&
        bossDefeated &&
        bossRewardClaimed &&
        !patchApplied &&
        activeRoom is CampaignNodeRoom &&
        (activeRoom as CampaignNodeRoom).campaignNodeId == bossNode;
  }

  void showEnding() {
    runMetrics.recordOverflow();
    ruleEngine.removeRule(RuleIds.legacyDamageInverted);
    input.clearAll();
    pauseEngine();
    completedRun.value = null;
    overlays.add(OverlayIds.ending);
  }

  void chooseEnding(String endingId) {
    if (completedRun.value != null) return;
    final summary = runMetrics.finish(
      integrity: world.player.integrity,
      selectedPatchIds: runState.selectedPatchIds,
      selectedWeapon: mode == PatchWorldMode.campaign
          ? world.player.selectedWeapon
          : null,
      weaponBuildTiers: weaponBuild.tiers.map(
        (upgrade, tier) => MapEntry(upgrade.name, tier),
      ),
      dashCooldownRemaining: world.player.dashCooldownRemaining,
      airJumpsRemaining: world.player.airJumpsRemaining,
      endingId: endingId,
    );
    completedRun.value = summary;
    if (summary.score > bestScore) {
      bestScore = summary.score;
      unawaited(settingsService.saveBestScore(bestScore));
    }
  }

  void restartRun() => unawaited(_restartRun());

  Future<void> _restartRun() async {
    overlays.remove(OverlayIds.ending);
    if (!overlays.isActive(OverlayIds.touchControls)) {
      overlays.add(OverlayIds.touchControls);
    }
    runState.reset();
    campaignExploration.reset();
    damageLabProgress.reset();
    temporalHallProgress.reset();
    collisionArchiveProgress.reset();
    runItems.reset();
    weaponBuild.reset();
    runMetrics.reset();
    completedRun.value = null;
    _consecutiveRoomDeaths = 0;
    patternTracker.reset();
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    currentRoom = _roomIdForCampaignNode(_campaignStartNode);
    mode = PatchWorldMode.campaign;
    final weapon = _selectedRunWeapon ?? PlayerWeapon.sword;
    _selectedRunWeapon = weapon;
    world.player.configureLoadout(
      weapon,
      assistMode: settings.value.assistMode,
    );
    // Ending pauses Flame. Resume before awaiting component removal/addition,
    // otherwise the previous room can never finish its removal lifecycle.
    resumeEngine();
    await world.loadCampaignNode(
      _campaignStartNode,
      entry: CampaignNodeEntry.west,
    );
    unawaited(audio.startArchiveBgm(restart: true));
    publishUiSnapshot(force: true);
    resumeEngine();
  }

  void returnToTitle() {
    if (_returnToTitleInProgress || overlays.isActive(OverlayIds.title)) return;
    _returnToTitleInProgress = true;
    unawaited(_returnToTitle());
  }

  Future<void> _returnToTitle() async {
    try {
      input.clearAll();
      _cinematicInputLocked = false;
      _defeatRestartTimer?.cancel();
      _defeatRestartTimer = null;
      _patchNoticeTimer?.cancel();
      _patchNoticeTimer = null;
      patchNotice.value = null;
      defeatSnapshot.value = null;
      pendingPatchSelection = null;
      pendingWeaponBuildSelection = null;
      pendingSurvivalUpgrade = null;
      pendingSurvivalWeaponUpgrade = null;
      pendingSurvivalItemReward = null;
      _queuedSurvivalItemRewards.clear();
      for (final overlayId in _runOverlayIds) {
        overlays.remove(overlayId);
      }
      runState.reset();
      campaignExploration.reset();
      damageLabProgress.reset();
      temporalHallProgress.reset();
      collisionArchiveProgress.reset();
      runItems.reset();
      weaponBuild.reset();
      survivalWeaponBuild.reset();
      survivalItems.reset();
      runMetrics.reset();
      completedRun.value = null;
      survivalResult.value = null;
      survivalRun.reset();
      patternTracker.reset();
      patchEffects.resetForRoomRestart();
      enemyTempo.resetForRoomRestart();
      ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
      currentRoom = _roomIdForCampaignNode(_campaignStartNode);
      mode = PatchWorldMode.campaign;
      _selectedRunWeapon = null;
      _consecutiveRoomDeaths = 0;
      resumeEngine();
      await world.loadCampaignNode(
        _campaignStartNode,
        entry: CampaignNodeEntry.west,
      );
      unawaited(audio.startArchiveBgm(restart: true));
      publishUiSnapshot(force: true);
      overlays.add(OverlayIds.title);
      pauseEngine();
    } finally {
      _returnToTitleInProgress = false;
    }
  }

  void openPauseMenu() {
    if (paused ||
        pendingPatchSelection != null ||
        pendingWeaponBuildSelection != null) {
      return;
    }
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.pause);
  }

  void closePauseMenu() {
    overlays.remove(OverlayIds.pause);
    resumeEngine();
  }

  void openSettings() {
    _settingsReturnOverlay = OverlayIds.pause;
    overlays.remove(OverlayIds.pause);
    overlays.add(OverlayIds.settings);
  }

  void openSettingsFromTitle() {
    _settingsReturnOverlay = OverlayIds.title;
    overlays.remove(OverlayIds.title);
    overlays.add(OverlayIds.settings);
  }

  void closeSettings() {
    overlays.remove(OverlayIds.settings);
    overlays.add(_settingsReturnOverlay);
  }

  void openCreditsFromTitle() {
    _creditsReturnOverlay = OverlayIds.title;
    overlays.remove(OverlayIds.title);
    overlays.add(OverlayIds.credits);
  }

  void openCreditsFromPause() {
    _creditsReturnOverlay = OverlayIds.pause;
    overlays.remove(OverlayIds.pause);
    overlays.add(OverlayIds.credits);
  }

  void openCreditsFromEnding() {
    _creditsReturnOverlay = OverlayIds.ending;
    overlays.remove(OverlayIds.ending);
    overlays.add(OverlayIds.credits);
  }

  void closeCredits() {
    overlays.remove(OverlayIds.credits);
    overlays.add(_creditsReturnOverlay);
  }

  void updateSettings(GameSettings next) {
    final languageChanged = settings.value.languageCode != next.languageCode;
    if (languageChanged) {
      unawaited(_changeLanguageAndApplySettings(next));
      return;
    }
    _applySettings(next);
  }

  Future<void> completeInitialLanguageSelection(String languageCode) async {
    final safeCode = LocalizationService.supports(languageCode)
        ? languageCode
        : LocalizationService.fallbackLanguageCode;
    await localization.load(safeCode);
    final next = settings.value.copyWith(
      languageCode: safeCode,
      languageSetupComplete: true,
    );
    await settingsService.save(next);
    _applySettings(next, persist: false);
  }

  Future<void> _changeLanguageAndApplySettings(GameSettings next) async {
    try {
      await localization.load(next.languageCode);
    } catch (_) {
      // The selected code is still persisted so a repaired asset works later.
    }
    _applySettings(next);
  }

  void _applySettings(GameSettings next, {bool persist = true}) {
    settings.value = next;
    audio
      ..setBgmVolume(next.bgmVolume)
      ..setSfxVolume(next.sfxVolume);
    if (world.isReady) {
      world.refreshLocalizedText();
      world.player.configureLoadout(
        world.player.selectedWeapon,
        assistMode: next.assistMode,
        restoreIntegrity: false,
      );
    }
    if (persist) unawaited(settingsService.save(next));
    publishUiSnapshot(force: true);
  }

  void restartRoomFromPauseMenu() {
    overlays.remove(OverlayIds.pause);
    resumeEngine();
    requestRoomRestart(causeId: 'manual.restart');
  }

  void activateCampaignCheckpoint(CampaignNodeId nodeId) {
    final activeRoom = world.activeRoom;
    if (activeRoom is! CampaignNodeRoom ||
        (activeRoom as CampaignNodeRoom).campaignNodeId != nodeId) {
      return;
    }
    campaignExploration.activateCheckpoint(nodeId, campaignWorld);
    campaignExploration.revealRegion(
      campaignWorld.nodes[nodeId]!.region,
      campaignWorld,
    );
    world.player.restoreIntegrity(world.player.maxIntegrity);
    publishUiSnapshot(force: true);
  }

  void openCampaignMap({CampaignRegion? revealRegion}) {
    if (mode != PatchWorldMode.campaign || !world.isReady) return;
    if (revealRegion != null) {
      campaignExploration.revealRegion(revealRegion, campaignWorld);
    }
    input.clearAll();
    pauseEngine();
    if (!overlays.isActive(OverlayIds.campaignMap)) {
      overlays.add(OverlayIds.campaignMap);
    }
  }

  void closeCampaignMap() {
    overlays.remove(OverlayIds.campaignMap);
    input.clearAll();
    resumeEngine();
  }

  void _toggleCampaignMap() {
    if (overlays.isActive(OverlayIds.campaignMap)) {
      closeCampaignMap();
    } else if (!overlays.isActive(OverlayIds.pause)) {
      openCampaignMap();
    }
  }

  void handlePlayerDefeat({required String causeId}) {
    if (mode == PatchWorldMode.survival) {
      _handleSurvivalDefeat(causeId);
      return;
    }
    if (defeatSnapshot.value != null) return;
    runMetrics.recordDeath();
    _consecutiveRoomDeaths += 1;
    defeatSnapshot.value = DefeatSnapshot(
      causeId: causeId,
      deathStreak: _consecutiveRoomDeaths,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.defeat);
    _defeatRestartTimer?.cancel();
    _defeatRestartTimer = dart_async.Timer(
      const Duration(seconds: 2),
      restartDefeatedRoom,
    );
  }

  void _handleSurvivalDefeat(String causeId) {
    if (survivalResult.value != null) return;
    final score = survivalRun.score;
    final elapsedSeconds = survivalRun.elapsedSeconds;
    final isBestScore = score > bestSurvivalScore;
    final isBestTime = elapsedSeconds > bestSurvivalTime;
    if (isBestScore) {
      bestSurvivalScore = score;
      unawaited(settingsService.saveBestSurvivalScore(score));
    }
    if (isBestTime) {
      bestSurvivalTime = elapsedSeconds;
      unawaited(settingsService.saveBestSurvivalTime(elapsedSeconds));
    }
    final result = SurvivalResultSnapshot.fromRun(
      survivalRun,
      isBestScore: isBestScore,
      isBestTime: isBestTime,
      selectedWeapon: _selectedRunWeapon ?? world.player.selectedWeapon,
      weaponBuildTiers: survivalWeaponBuild.tiers.map(
        (id, tier) => MapEntry<String, int>(id.id, tier),
      ),
      itemIds: survivalItems.items.map((id) => id.name).toList(growable: false),
      itemSynergyTiers: survivalItems.activeSynergyTiers.map(
        (tag, tier) => MapEntry<String, int>(tag.name, tier),
      ),
      deathCauseId: causeId,
    );
    survivalSessionHistory.add(result);
    if (survivalSessionHistory.length > 5) {
      survivalSessionHistory.removeAt(0);
    }
    survivalPlaytestHistory.add(SurvivalPlaytestRecord.fromResult(result));
    if (survivalPlaytestHistory.length >
        SurvivalBalanceReport.maximumStoredRuns) {
      survivalPlaytestHistory.removeAt(0);
    }
    unawaited(
      settingsService.saveSurvivalPlaytestRecords(survivalPlaytestHistory),
    );
    survivalResult.value = result;
    input.clearAll();
    pendingSurvivalUpgrade = null;
    pendingSurvivalWeaponUpgrade = null;
    pendingSurvivalItemReward = null;
    _queuedSurvivalItemRewards.clear();
    overlays.remove(OverlayIds.survivalUpgrade);
    overlays.remove(OverlayIds.survivalWeaponUpgrade);
    overlays.remove(OverlayIds.survivalItemReward);
    pauseEngine();
    overlays.add(OverlayIds.survivalResult);
  }

  void retrySurvivalRun({bool keepStartingPatch = false}) =>
      unawaited(_retrySurvivalRun(keepStartingPatch: keepStartingPatch));

  Future<void> _retrySurvivalRun({required bool keepStartingPatch}) async {
    final retainedPatchId = keepStartingPatch
        ? survivalResult.value?.firstPatchId
        : null;
    overlays.remove(OverlayIds.survivalResult);
    survivalResult.value = null;
    runState.reset();
    survivalRun.reset();
    survivalWeaponBuild.reset();
    survivalItems.reset();
    pendingSurvivalUpgrade = null;
    pendingSurvivalWeaponUpgrade = null;
    pendingSurvivalItemReward = null;
    _queuedSurvivalItemRewards.clear();
    overlays.remove(OverlayIds.survivalUpgrade);
    overlays.remove(OverlayIds.survivalWeaponUpgrade);
    overlays.remove(OverlayIds.survivalItemReward);
    ruleEngine.setRules(const <GameRule>[]);
    if (retainedPatchId != null) {
      final patch = SurvivalUpgradeCatalog.all.singleWhere(
        (candidate) => candidate.id == retainedPatchId,
      );
      runState.selectPatch(patch.id);
      survivalRun.upgradePatch(
        patch.id,
        riskTier: SurvivalUpgradeCatalog.riskTierFor(patch),
      );
    }
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    input.clearAll();
    resumeEngine();
    await world.restartCurrentRoom();
    publishUiSnapshot(force: true);
    resumeEngine();
  }

  void restartDefeatedRoom() {
    if (defeatSnapshot.value == null) return;
    _defeatRestartTimer?.cancel();
    _defeatRestartTimer = null;
    defeatSnapshot.value = null;
    overlays.remove(OverlayIds.defeat);
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    unawaited(_reloadDefeatedRoom());
  }

  Future<void> _reloadDefeatedRoom() async {
    // Defeat also pauses Flame; room replacement needs update frames to
    // finalize the outgoing component's removal.
    resumeEngine();
    if (mode == PatchWorldMode.survival) {
      survivalRun.reset();
      survivalWeaponBuild.reset();
      survivalItems.reset();
      runState.reset();
      pendingSurvivalUpgrade = null;
      pendingSurvivalWeaponUpgrade = null;
      pendingSurvivalItemReward = null;
      _queuedSurvivalItemRewards.clear();
      overlays.remove(OverlayIds.survivalUpgrade);
      overlays.remove(OverlayIds.survivalWeaponUpgrade);
      overlays.remove(OverlayIds.survivalItemReward);
    }
    final checkpointNode = campaignExploration.checkpointNodeId;
    if (mode == PatchWorldMode.campaign && checkpointNode != null) {
      currentRoom = switch (campaignWorld.nodes[checkpointNode]!.region) {
        CampaignRegion.bootSector => RoomId.bootSector,
        CampaignRegion.damageLab => RoomId.damageLab,
        CampaignRegion.temporalHall => RoomId.temporalHall,
        CampaignRegion.collisionArchive => RoomId.collisionArchive,
        CampaignRegion.optimizerCore => RoomId.optimizerCore,
      };
      await world.loadCampaignNode(
        checkpointNode,
        entry: CampaignNodeEntry.west,
      );
    } else {
      await world.restartCurrentRoom();
    }
    publishUiSnapshot(force: true);
    resumeEngine();
  }

  void enableAssistAndRestart() {
    updateSettings(settings.value.copyWith(assistMode: true));
    restartDefeatedRoom();
  }

  void requestRoomRestart({required String causeId}) {
    if (_roomRestartRequested) {
      return;
    }
    _roomRestartRequested = true;
    input.clearAll();
    pauseEngine();
    Future<void>.delayed(const Duration(milliseconds: 900), () async {
      patchEffects.resetForRoomRestart();
      enemyTempo.resetForRoomRestart();
      // Room replacement needs active update frames to finish removals.
      resumeEngine();
      await world.restartCurrentRoom();
      _roomRestartRequested = false;
      publishUiSnapshot(force: true);
      resumeEngine();
    });
  }

  void publishUiSnapshot({bool force = false}) {
    if (!world.isReady) {
      return;
    }
    final burst = enemyTempo.frameBurstSnapshot;
    final boss = world.activeBoss;
    final activeRoom = world.activeRoom;
    final activeCampaignNode = activeRoom is CampaignNodeRoom
        ? (activeRoom as CampaignNodeRoom).campaignNodeId
        : null;
    final DamageLabRoomStatus? damageLabRoom = activeRoom is DamageLabRoomStatus
        ? activeRoom as DamageLabRoomStatus
        : null;
    final regionalRoom = activeRoom is RegionalCampaignNodeController
        ? activeRoom
        : null;
    final regionalTemporalRoom =
        regionalRoom?.region == CampaignRegion.temporalHall
        ? regionalRoom
        : null;
    final regionalCollisionRoom =
        regionalRoom?.region == CampaignRegion.collisionArchive
        ? regionalRoom
        : null;
    final regionalObjectiveLabel =
        regionalRoom != null && !regionalRoom.isBossRoom
        ? regionalRoom.roomObjectiveLabel
        : null;
    final survivalRoom = activeRoom is SurvivalArenaController
        ? activeRoom
        : null;
    final pattern = patternTracker.snapshot;
    final next = UiSnapshot(
      integrity: world.player.integrity,
      maxIntegrity: world.player.maxIntegrity,
      roomLabel: switch (activeCampaignNode) {
        CampaignNodeId.damageDashCache => localization.text(
          'room.damageDashCache',
        ),
        CampaignNodeId.damageUpperArchive => localization.text(
          'room.damageUpperArchive',
        ),
        CampaignNodeId.damageTurretControl => localization.text(
          'room.damageTurretControl',
        ),
        CampaignNodeId.temporalAscent => localization.text(
          'room.temporalAscent',
        ),
        CampaignNodeId.temporalFracture => localization.text(
          'room.temporalFracture',
        ),
        CampaignNodeId.temporalDashRift => localization.text(
          'room.temporalDashRift',
        ),
        CampaignNodeId.temporalUpperLoop => localization.text(
          'room.temporalUpperLoop',
        ),
        CampaignNodeId.temporalRelayControl => localization.text(
          'room.temporalRelayControl',
        ),
        CampaignNodeId.temporalPendulum => localization.text(
          'room.temporalPendulum',
        ),
        CampaignNodeId.chronoJailer => localization.text('room.chronoJailer'),
        CampaignNodeId.collisionCompression => localization.text(
          'room.collisionCompression',
        ),
        CampaignNodeId.collisionFracture => localization.text(
          'room.collisionFracture',
        ),
        CampaignNodeId.collisionVectorCache => localization.text(
          'room.collisionVectorCache',
        ),
        CampaignNodeId.collisionUpperMatrix => localization.text(
          'room.collisionUpperMatrix',
        ),
        CampaignNodeId.collisionPrismControl => localization.text(
          'room.collisionPrismControl',
        ),
        CampaignNodeId.collisionMerge => localization.text(
          'room.collisionMerge',
        ),
        CampaignNodeId.kernelChimera => localization.text('room.kernelChimera'),
        _ => switch (currentRoom) {
          RoomId.bootSector => localization.text('room.bootSector'),
          RoomId.damageLab => localization.text('room.damageLab'),
          RoomId.temporalHall => localization.text('room.temporalHall'),
          RoomId.collisionArchive => localization.text('room.collisionArchive'),
          RoomId.optimizerCore => localization.text('room.optimizerCore'),
          RoomId.survivalArena => localization.text('room.survivalArena'),
        },
      },
      anomalyLabel: switch (currentRoom) {
        RoomId.bootSector => localization.text('rule.systemStable'),
        RoomId.damageLab =>
          ruleEngine.containsRule(RuleIds.damageSignInverted)
              ? localization.text('rule.damageInverted')
              : localization.text('rule.damageNormalized'),
        RoomId.temporalHall => localization.text('rule.timeOnInput'),
        RoomId.collisionArchive => localization.text('rule.collisionMerge'),
        RoomId.optimizerCore => localization.text('rule.patternAnalysis'),
        RoomId.survivalArena => localization.text('rule.survivalEscalation'),
      },
      objectiveLabel: switch (currentRoom) {
        RoomId.bootSector => localization.text('objective.bootSector'),
        RoomId.damageLab => switch (activeCampaignNode) {
          CampaignNodeId.damageDashCache ||
          CampaignNodeId.damageUpperArchive ||
          CampaignNodeId.damageTurretControl => localization.text(
            'objective.damageSecret',
          ),
          _ => localization.text(
            damageLabRoom?.isCompleted == true
                ? 'objective.damageLabExit'
                : damageLabRoom?.currentCellNumber == 4
                ? 'objective.damageLabBoss'
                : 'objective.damageLab',
            parameters: <String, Object>{
              'room': damageLabRoom?.currentCellNumber ?? 1,
              'cleared': damageLabRoom?.clearedEncounterCount ?? 0,
              'records': damageLabRoom?.qaRecordCount ?? 0,
            },
          ),
        },
        RoomId.temporalHall => switch (activeCampaignNode) {
          CampaignNodeId.temporalDashRift ||
          CampaignNodeId.temporalUpperLoop ||
          CampaignNodeId.temporalRelayControl => localization.text(
            'objective.temporalSecret',
          ),
          _ =>
            regionalObjectiveLabel ??
                localization.text(
                  regionalTemporalRoom?.isCompleted == true
                      ? 'objective.temporalHallExit'
                      : regionalTemporalRoom?.currentCellNumber == 4
                      ? 'objective.temporalHallBoss'
                      : 'objective.temporalHall',
                  parameters: <String, Object>{
                    'room': regionalTemporalRoom?.currentCellNumber ?? 1,
                    'cleared': regionalTemporalRoom?.clearedEncounterCount ?? 0,
                    'records': regionalTemporalRoom?.recordCount ?? 0,
                  },
                ),
        },
        RoomId.collisionArchive => switch (activeCampaignNode) {
          CampaignNodeId.collisionVectorCache ||
          CampaignNodeId.collisionUpperMatrix ||
          CampaignNodeId.collisionPrismControl => localization.text(
            'objective.collisionSecret',
          ),
          _ =>
            regionalObjectiveLabel ??
                localization.text(
                  regionalCollisionRoom?.isCompleted == true
                      ? 'objective.collisionArchiveExit'
                      : regionalCollisionRoom?.currentCellNumber == 4
                      ? 'objective.collisionArchiveBoss'
                      : 'objective.collisionArchive',
                  parameters: <String, Object>{
                    'room': regionalCollisionRoom?.currentCellNumber ?? 1,
                    'cleared':
                        regionalCollisionRoom?.clearedEncounterCount ?? 0,
                    'records': regionalCollisionRoom?.recordCount ?? 0,
                  },
                ),
        },
        RoomId.optimizerCore => switch (boss?.phase.name) {
          'perfect' => localization.text(
            'objective.optimizerPerfect',
            parameters: <String, Object>{
              'stability': boss?.stability.current ?? 75,
            },
          ),
          'overflow' ||
          'defeated' => localization.text('objective.optimizerOverflow'),
          _ => localization.text('objective.optimizerDamage'),
        },
        RoomId.survivalArena =>
          survivalRoom?.survivalObjectiveLabel ??
              localization.text(
                'objective.survivalArena',
                parameters: <String, Object>{
                  'time': survivalRun.elapsedSeconds.floor(),
                  'kills': survivalRun.kills,
                  'score': survivalRun.score,
                  'stage': localization.text(
                    SurvivalDifficultyStage.boot.localizationKey,
                  ),
                },
              ),
      },
      selectedPatchIds: runState.selectedPatchIds,
      selectedWeapon: world.player.selectedWeapon,
      dashCooldownRemaining: mode == PatchWorldMode.survival
          ? world.player.survivalSpecialCooldownRemaining
          : world.player.dashCooldownRemaining,
      airJumpsRemaining: world.player.airJumpsRemaining,
      specialAbilityReady: world.player.specialAbilityReady,
      gauntletChargeSeconds: world.player.gauntletChargeSeconds,
      gunLaserRemaining: world.player.gunLaserRemaining,
      specialAbilityCooldownRemaining:
          world.player.campaignSpecialCooldownRemaining,
      survivalLevel: mode == PatchWorldMode.survival ? survivalRun.level : null,
      survivalExperience: mode == PatchWorldMode.survival
          ? survivalRun.experience
          : null,
      survivalExperienceToNext: mode == PatchWorldMode.survival
          ? survivalRun.experienceToNext
          : null,
      survivalCombo: mode == PatchWorldMode.survival ? survivalRun.combo : null,
      survivalComboProgress: mode == PatchWorldMode.survival
          ? survivalRun.comboProgress
          : 0,
      survivalCriticalFlowRemaining: mode == PatchWorldMode.survival
          ? survivalRun.criticalFlowRemaining
          : 0,
      survivalOverclock:
          mode == PatchWorldMode.survival && survivalRun.overclockActive,
      survivalDataCharge: mode == PatchWorldMode.survival
          ? world.player.dataShardCharge
          : null,
      survivalDataSurge:
          mode == PatchWorldMode.survival && survivalRun.dataSurgeActive,
      survivalFusionCount: mode == PatchWorldMode.survival
          ? survivalModifiers.activeFusionIds.length
          : 0,
      motionVentReady:
          mode == PatchWorldMode.survival && patchEffects.motionVentCharged,
      normalizedHeat: patchEffects.normalizedHeat,
      echoPulseCount: patchEffects.echoPulseCount,
      frameBurstPhase: burst?.phase,
      frameBurstProgress: burst?.phaseProgress,
      bossHealth:
          damageLabRoom?.bossHealth ??
          regionalRoom?.bossHealth ??
          boss?.health ??
          survivalRoom?.milestoneBossHealth,
      bossMaxHealth:
          damageLabRoom?.bossMaxHealth ??
          regionalRoom?.bossMaxHealth ??
          (boss == null ? survivalRoom?.milestoneBossMaxHealth : 20),
      bossStability: boss?.phase.name == 'perfect'
          ? boss?.stability.current
          : null,
      patternConfidence: boss == null ? null : pattern.confidence,
      bossPhase:
          damageLabRoom?.bossPhaseKey ??
          regionalRoom?.bossPhaseKey ??
          boss?.phase.name ??
          survivalRoom?.milestoneBossLabel,
    );
    if (force || uiSnapshot.value != next) {
      uiSnapshot.value = next;
    }
  }

  /// Synchronizes exploration from the independently loaded scene itself.
  void syncCampaignExploration() {
    if (mode != PatchWorldMode.campaign || !world.isReady) return;
    final activeRoom = world.activeRoom;
    final nodeId = activeRoom is CampaignNodeRoom
        ? (activeRoom as CampaignNodeRoom).campaignNodeId
        : null;
    if (nodeId != null) campaignExploration.enterNode(nodeId, campaignWorld);

    if (damageLabProgress.bossDefeated) {
      campaignExploration.collectCoreSignature(CampaignRegion.damageLab);
    }
    if (damageLabProgress.patchApplied) {
      campaignExploration.unlockShortcut(
        CampaignWorldGraph.temporalHubAccessId,
      );
    }
    if (temporalHallProgress.bossDefeated) {
      campaignExploration
        ..collectCoreSignature(CampaignRegion.temporalHall)
        ..unlockShortcut(CampaignWorldGraph.temporalHubLiftId);
    }
    if (temporalHallProgress.patchApplied) {
      campaignExploration.unlockShortcut(
        CampaignWorldGraph.collisionHubAccessId,
      );
    }
    if (collisionArchiveProgress.bossDefeated) {
      campaignExploration
        ..collectCoreSignature(CampaignRegion.collisionArchive)
        ..unlockShortcut(CampaignWorldGraph.collisionHubLiftId);
    }
    final newSurvivalUnlocks = campaignExploration.unlockedTraversalAbilities
        .difference(survivalMetaAbilities);
    if (newSurvivalUnlocks.isNotEmpty) {
      survivalMetaAbilities.addAll(newSurvivalUnlocks);
      unawaited(
        settingsService.saveSurvivalAbilityUnlocks(survivalMetaAbilities),
      );
    }
  }

  void _togglePause() {
    if (overlays.isActive(OverlayIds.pause)) {
      closePauseMenu();
    } else {
      openPauseMenu();
    }
  }
}
