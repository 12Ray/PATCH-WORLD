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
import 'package:patch_world/game/core/input_controller.dart';
import 'package:patch_world/game/core/game_clock.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/core/run_metrics.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:patch_world/game/rooms/room_two_controller.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/enemy_tempo_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';
import 'package:patch_world/game/systems/patch_effects_system.dart';
import 'package:patch_world/game/systems/player_pattern_tracker.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:patch_world/game/survival/survival_patch_modifiers.dart';
import 'package:patch_world/game/survival/survival_playtest_telemetry.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';
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
  static const String survivalQaBuild = String.fromEnvironment(
    'SURVIVAL_QA_BUILD',
    defaultValue: '',
  );

  final RoomId initialRoom;

  final InputController input = InputController();
  final RunState runState = RunState();
  final RunMetrics runMetrics = RunMetrics();
  final SurvivalRunState survivalRun = SurvivalRunState();
  final RuleEngine ruleEngine = RuleEngine();
  final GameClock clock = GameClock();
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
  final ValueNotifier<RunSummary?> completedRun = ValueNotifier<RunSummary?>(
    null,
  );
  final ValueNotifier<PatchDefinition?> patchNotice =
      ValueNotifier<PatchDefinition?>(null);

  late final CombatSystem combatSystem;
  late final PatchEffectsSystem patchEffects;
  late final EnemyTempoSystem enemyTempo;
  late final DuplicateFaultSystem duplicateFault;
  RoomId currentRoom;
  PatchWorldMode mode;
  PatchSelectionRequest? pendingPatchSelection;
  SurvivalUpgradeRequest? pendingSurvivalUpgrade;
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
  String _settingsReturnOverlay = OverlayIds.pause;
  String _creditsReturnOverlay = OverlayIds.title;

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
      bestScore = await settingsService.loadBestScore();
      bestSurvivalScore = await settingsService.loadBestSurvivalScore();
      bestSurvivalTime = await settingsService.loadBestSurvivalTime();
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
    await super.onLoad();
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
      input.handleKeyDown(event.logicalKey);
      if ((event.logicalKey == LogicalKeyboardKey.escape ||
              event.logicalKey == LogicalKeyboardKey.keyP) &&
          pendingPatchSelection == null) {
        _togglePause();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
  }

  void startRun() => unawaited(_startCampaignRun());

  Future<void> _startCampaignRun() async {
    await ready();
    mode = PatchWorldMode.campaign;
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
  }

  void startSurvivalRun() => unawaited(_startSurvivalRun());

  Future<void> _startSurvivalRun() async {
    await ready();
    unawaited(audio.unlockFromUserGesture());
    mode = PatchWorldMode.survival;
    runState.reset();
    survivalRun.reset();
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
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      activeRoom.showComboMilestone(survivalRun.combo);
    }
    publishUiSnapshot(force: true);
    if (leveledUp && pendingSurvivalUpgrade == null) {
      _openSurvivalUpgrade();
    }
  }

  void recordSurvivalHit() {
    if (mode != PatchWorldMode.survival) return;
    survivalRun.recordHit();
    publishUiSnapshot(force: true);
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
        '${localization.text('hud.dataSurge')} // PULSE +1',
      );
    }
    publishUiSnapshot(force: true);
  }

  SurvivalSessionSummary get survivalSessionSummary =>
      SurvivalSessionSummary.fromPatchRuns(
        survivalSessionHistory.map((result) => result.patchTiers.keys.toSet()),
      );

  void _openSurvivalUpgrade() {
    final choices = SurvivalUpgradeCatalog.choicesForLevel(
      survivalRun.level,
      patchTiers: survivalRun.patchTiers,
    );
    if (choices.isEmpty) {
      survivalRun.recordMaxedBuildLevel();
      final activeRoom = world.activeRoom;
      if (activeRoom is SurvivalArenaController) {
        activeRoom.showPatchPowerDemo('BUILD MAXED // +250');
      }
      return;
    }
    pendingSurvivalUpgrade = SurvivalUpgradeRequest(
      level: survivalRun.level,
      choices: choices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.survivalUpgrade);
  }

  void selectSurvivalUpgrade(String patchId) {
    final request = pendingSurvivalUpgrade;
    if (request == null) return;
    PatchDefinition? patch;
    for (final choice in request.choices) {
      if (choice.id == patchId) patch = choice;
    }
    if (patch == null) return;
    runState.selectPatch(patch.id);
    survivalRun.upgradePatch(
      patch.id,
      riskTier: SurvivalUpgradeCatalog.riskTierFor(patch),
    );
    pendingSurvivalUpgrade = null;
    overlays.remove(OverlayIds.survivalUpgrade);
    input.clearAll();
    publishUiSnapshot(force: true);
    final activeRoom = world.activeRoom;
    if (activeRoom is SurvivalArenaController) {
      activeRoom.showPatchPowerDemo(patch.title);
    }
    resumeEngine();
  }

  void queuePointerAttack() {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null) {
      input.queueAttack();
    }
  }

  void queueTouchAttack() => queuePointerAttack();

  void queueTouchInteract() {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null) {
      input.queueInteract();
    }
  }

  void setTouchMovement(double x, double y) {
    if (!paused &&
        !_roomTransitionInProgress &&
        pendingPatchSelection == null) {
      input.setVirtualMovement(x, y);
    }
  }

  void clearTouchMovement() => input.clearVirtualMovement();

  void triggerImpactFeedback() {
    if (settings.value.screenShake == ScreenShakeSetting.off) return;
    _screenShakeRemaining =
        settings.value.screenShake == ScreenShakeSetting.reduced ? 0.08 : 0.14;
    _screenShakePhase = 0;
  }

  void _updateScreenShake(double dt) {
    const centerX = logicalWidth / 2;
    const centerY = logicalHeight / 2;
    if (_screenShakeRemaining <= 0) {
      camera.viewfinder.position.setValues(centerX, centerY);
      return;
    }
    _screenShakeRemaining = math.max(0, _screenShakeRemaining - dt);
    _screenShakePhase += dt * 95;
    final amplitude = settings.value.screenShake == ScreenShakeSetting.reduced
        ? 1.5
        : 3.2;
    camera.viewfinder.position.setValues(
      centerX + math.sin(_screenShakePhase) * amplitude,
      centerY + math.cos(_screenShakePhase * 1.7) * amplitude,
    );
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
    final movement = input.movementAxis;
    final hasGameplayIntent = input.hasGameplayIntent;
    final activeRoom = world.activeRoom;
    final survivalTempo = activeRoom is SurvivalArenaController
        ? activeRoom.enemySpeedMultiplier
        : 1.0;
    final survivalQaTempo = mode == PatchWorldMode.survival
        ? survivalQaTimeScale
        : 1.0;
    enemyTempo.update(dt);
    if (mode == PatchWorldMode.survival &&
        survivalModifiers.frameOverclockOnBurstEnd &&
        enemyTempo.didFrameBurstEnd) {
      survivalRun.triggerFrameOverclock();
    }
    clock.beginFrame(
      realDt: dt,
      simulationAdvances:
          currentRoom != RoomId.temporalHall || hasGameplayIntent,
      enemySpeedMultiplier:
          enemyTempo.speedMultiplier *
          survivalTempo *
          survivalQaTempo *
          (settings.value.assistMode ? 0.85 : 1),
    );
    runMetrics.update(clock.realDt);
    _updateScreenShake(clock.realDt);
    world.player.setMovementInput(movement);
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
      playerPosition: world.player.position,
    );
    if (input.consumeAttack()) {
      patternTracker.recordAttack();
      world.player.tryAttack();
    }
    if (input.consumeInteract()) world.player.tryInteract();
    _uiPublishAccumulator += clock.realDt;
    if (_uiPublishAccumulator >= 0.10) {
      _uiPublishAccumulator = 0;
      publishUiSnapshot();
    }
    super.update(dt);
  }

  void openRoomOnePatchSelection() {
    if (pendingPatchSelection != null) {
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

  void selectPatch(String patchId) {
    unawaited(_selectPatchAndContinue(patchId));
  }

  Future<void> _selectPatchAndContinue(String patchId) async {
    final request = pendingPatchSelection;
    if (request == null ||
        !request.choices.any((PatchDefinition item) => item.id == patchId)) {
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
        currentRoom = RoomId.temporalHall;
        await world.loadRoom(currentRoom);
      } else if (request.roomId == 'temporal-hall') {
        enemyTempo.resetForRoomRestart();
        patchEffects.resetTransientForRoomTransition();
        currentRoom = RoomId.collisionArchive;
        await world.loadRoom(currentRoom);
      } else if (request.roomId == 'collision-archive') {
        enemyTempo.resetForRoomRestart();
        patchEffects.resetTransientForRoomTransition();
        currentRoom = RoomId.optimizerCore;
        await world.loadRoom(currentRoom);
        unawaited(audio.startOptimizerBgm());
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
    if (pendingPatchSelection != null) return;
    pendingPatchSelection = const PatchSelectionRequest(
      roomId: 'temporal-hall',
      choices: PatchCatalog.roomTwoChoices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.patchSelection);
  }

  void openRoomThreePatchSelection() {
    if (pendingPatchSelection != null) return;
    pendingPatchSelection = const PatchSelectionRequest(
      roomId: 'collision-archive',
      choices: PatchCatalog.roomThreeChoices,
    );
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.patchSelection);
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
    runMetrics.reset();
    completedRun.value = null;
    _consecutiveRoomDeaths = 0;
    patternTracker.reset();
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    currentRoom = RoomId.damageLab;
    mode = PatchWorldMode.campaign;
    // Ending pauses Flame. Resume before awaiting component removal/addition,
    // otherwise the previous room can never finish its removal lifecycle.
    resumeEngine();
    await world.loadRoom(currentRoom);
    unawaited(audio.startArchiveBgm(restart: true));
    publishUiSnapshot(force: true);
    resumeEngine();
  }

  void returnToTitle() => unawaited(_returnToTitle());

  Future<void> _returnToTitle() async {
    overlays.remove(OverlayIds.ending);
    overlays.remove(OverlayIds.survivalResult);
    overlays.remove(OverlayIds.hud);
    overlays.remove(OverlayIds.touchControls);
    runState.reset();
    runMetrics.reset();
    completedRun.value = null;
    survivalResult.value = null;
    survivalRun.reset();
    pendingSurvivalUpgrade = null;
    overlays.remove(OverlayIds.survivalUpgrade);
    patternTracker.reset();
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    currentRoom = RoomId.damageLab;
    mode = PatchWorldMode.campaign;
    resumeEngine();
    await world.loadRoom(currentRoom);
    unawaited(audio.startArchiveBgm(restart: true));
    publishUiSnapshot(force: true);
    overlays.add(OverlayIds.title);
  }

  void openPauseMenu() {
    if (paused || pendingPatchSelection != null) {
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

  Future<void> _changeLanguageAndApplySettings(GameSettings next) async {
    try {
      await localization.load(next.languageCode);
    } catch (_) {
      // The selected code is still persisted so a repaired asset works later.
    }
    _applySettings(next);
  }

  void _applySettings(GameSettings next) {
    settings.value = next;
    audio
      ..setBgmVolume(next.bgmVolume)
      ..setSfxVolume(next.sfxVolume);
    if (world.isReady) {
      world.player.maxIntegrity = next.assistMode ? 6 : 5;
      world.player.integrity = world.player.integrity.clamp(
        0,
        world.player.maxIntegrity,
      );
    }
    unawaited(settingsService.save(next));
    publishUiSnapshot(force: true);
  }

  void restartRoomFromPauseMenu() {
    overlays.remove(OverlayIds.pause);
    resumeEngine();
    requestRoomRestart(causeId: 'manual.restart');
  }

  void handlePlayerDefeat({required String causeId}) {
    if (mode == PatchWorldMode.survival) {
      _handleSurvivalDefeat();
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

  void _handleSurvivalDefeat() {
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
    );
    survivalSessionHistory.add(result);
    if (survivalSessionHistory.length > 5) {
      survivalSessionHistory.removeAt(0);
    }
    survivalResult.value = result;
    input.clearAll();
    pendingSurvivalUpgrade = null;
    overlays.remove(OverlayIds.survivalUpgrade);
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
    pendingSurvivalUpgrade = null;
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
      runState.reset();
      pendingSurvivalUpgrade = null;
      overlays.remove(OverlayIds.survivalUpgrade);
    }
    await world.restartCurrentRoom();
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
    final survivalRoom = activeRoom is SurvivalArenaController
        ? activeRoom
        : null;
    final pattern = patternTracker.snapshot;
    final next = UiSnapshot(
      integrity: world.player.integrity,
      maxIntegrity: world.player.maxIntegrity,
      roomLabel: switch (currentRoom) {
        RoomId.damageLab => localization.text('room.damageLab'),
        RoomId.temporalHall => localization.text('room.temporalHall'),
        RoomId.collisionArchive => localization.text('room.collisionArchive'),
        RoomId.optimizerCore => localization.text('room.optimizerCore'),
        RoomId.survivalArena => localization.text('room.survivalArena'),
      },
      anomalyLabel: switch (currentRoom) {
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
        RoomId.damageLab => localization.text(
          'objective.damageLab',
          parameters: <String, Object>{
            'count': activeRoom is RoomOneController
                ? activeRoom.overflowCount
                : 0,
          },
        ),
        RoomId.temporalHall => localization.text(
          'objective.temporalHall',
          parameters: <String, Object>{
            'count': activeRoom is RoomTwoController
                ? activeRoom.activatedTerminalCount
                : 0,
          },
        ),
        RoomId.collisionArchive => localization.text(
          'objective.collisionArchive',
        ),
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
        RoomId.survivalArena => localization.text(
          'objective.survivalArena',
          parameters: <String, Object>{
            'time': survivalRun.elapsedSeconds.floor(),
            'kills': survivalRun.kills,
            'score': survivalRun.score,
          },
        ),
      },
      selectedPatchIds: runState.selectedPatchIds,
      survivalLevel: mode == PatchWorldMode.survival ? survivalRun.level : null,
      survivalExperience: mode == PatchWorldMode.survival
          ? survivalRun.experience
          : null,
      survivalExperienceToNext: mode == PatchWorldMode.survival
          ? survivalRun.experienceToNext
          : null,
      survivalCombo: mode == PatchWorldMode.survival ? survivalRun.combo : null,
      survivalOverclock:
          mode == PatchWorldMode.survival && survivalRun.overclockActive,
      survivalDataCharge: mode == PatchWorldMode.survival
          ? world.player.dataShardCharge
          : null,
      survivalDataSurge:
          mode == PatchWorldMode.survival && survivalRun.dataSurgeActive,
      motionVentReady:
          mode == PatchWorldMode.survival && patchEffects.motionVentCharged,
      normalizedHeat: patchEffects.normalizedHeat,
      echoPulseCount: patchEffects.echoPulseCount,
      frameBurstPhase: burst?.phase,
      frameBurstProgress: burst?.phaseProgress,
      bossHealth: boss?.health ?? survivalRoom?.milestoneBossHealth,
      bossMaxHealth: boss == null ? survivalRoom?.milestoneBossMaxHealth : 20,
      bossStability: boss?.phase.name == 'perfect'
          ? boss?.stability.current
          : null,
      patternConfidence: boss == null ? null : pattern.confidence,
      bossPhase: boss?.phase.name ?? survivalRoom?.milestoneBossLabel,
    );
    if (force || uiSnapshot.value != next) {
      uiSnapshot.value = next;
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
