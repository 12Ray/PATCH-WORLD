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
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/enemy_tempo_system.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';
import 'package:patch_world/game/systems/patch_effects_system.dart';
import 'package:patch_world/game/systems/player_pattern_tracker.dart';
import 'package:patch_world/services/audio_service.dart';
import 'package:patch_world/services/game_settings.dart';
import 'package:patch_world/services/localization_service.dart';
import 'package:patch_world/services/settings_service.dart';

final class PatchWorldGame extends FlameGame<PatchWorld>
    with HasCollisionDetection, KeyboardEvents {
  PatchWorldGame({this.initialRoom = RoomId.damageLab})
    : currentRoom = initialRoom,
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

  final RoomId initialRoom;

  final InputController input = InputController();
  final RunState runState = RunState();
  final RunMetrics runMetrics = RunMetrics();
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
  PatchSelectionRequest? pendingPatchSelection;
  double _uiPublishAccumulator = 0;
  bool _roomRestartRequested = false;
  dart_async.Timer? _defeatRestartTimer;
  dart_async.Timer? _patchNoticeTimer;
  int _consecutiveRoomDeaths = 0;
  int bestScore = 0;
  double _screenShakeRemaining = 0;
  double _screenShakePhase = 0;
  String _settingsReturnOverlay = OverlayIds.pause;
  String _creditsReturnOverlay = OverlayIds.title;

  RuleContext get ruleContext => RuleContext(
    roomId: currentRoom,
    selectedPatchIds: runState.selectedPatchIds.toSet(),
  );

  @override
  Future<void> onLoad() async {
    var loadedSettings = const GameSettings();
    try {
      loadedSettings = await settingsService.load();
      bestScore = await settingsService.loadBestScore();
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
      spawnEcho: (position) {
        unawaited(world.spawnRetaliationEcho(position));
      },
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

  void startRun() {
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

  void queuePointerAttack() {
    if (!paused && pendingPatchSelection == null) input.queueAttack();
  }

  void queueTouchAttack() => queuePointerAttack();

  void queueTouchInteract() {
    if (!paused && pendingPatchSelection == null) input.queueInteract();
  }

  void setTouchMovement(double x, double y) {
    if (!paused && pendingPatchSelection == null) {
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
    enemyTempo.update(dt);
    clock.beginFrame(
      realDt: dt,
      simulationAdvances:
          currentRoom != RoomId.temporalHall || hasGameplayIntent,
      enemySpeedMultiplier:
          enemyTempo.speedMultiplier * (settings.value.assistMode ? 0.85 : 1),
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
    await world.loadRoom(currentRoom);
    unawaited(audio.startArchiveBgm(restart: true));
    publishUiSnapshot(force: true);
    resumeEngine();
  }

  void returnToTitle() => unawaited(_returnToTitle());

  Future<void> _returnToTitle() async {
    overlays.remove(OverlayIds.ending);
    overlays.remove(OverlayIds.hud);
    overlays.remove(OverlayIds.touchControls);
    runState.reset();
    runMetrics.reset();
    completedRun.value = null;
    patternTracker.reset();
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    currentRoom = RoomId.damageLab;
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
    final pattern = patternTracker.snapshot;
    final next = UiSnapshot(
      integrity: world.player.integrity,
      maxIntegrity: world.player.maxIntegrity,
      roomLabel: switch (currentRoom) {
        RoomId.damageLab => localization.text('room.damageLab'),
        RoomId.temporalHall => localization.text('room.temporalHall'),
        RoomId.collisionArchive => localization.text('room.collisionArchive'),
        RoomId.optimizerCore => localization.text('room.optimizerCore'),
      },
      anomalyLabel: switch (currentRoom) {
        RoomId.damageLab =>
          ruleEngine.containsRule(RuleIds.damageSignInverted)
              ? localization.text('rule.damageInverted')
              : localization.text('rule.damageNormalized'),
        RoomId.temporalHall => localization.text('rule.timeOnInput'),
        RoomId.collisionArchive => localization.text('rule.collisionMerge'),
        RoomId.optimizerCore => localization.text('rule.patternAnalysis'),
      },
      selectedPatchIds: runState.selectedPatchIds,
      normalizedHeat: patchEffects.normalizedHeat,
      echoPulseCount: patchEffects.echoPulseCount,
      frameBurstPhase: burst?.phase,
      frameBurstProgress: burst?.phaseProgress,
      bossHealth: boss?.health,
      bossMaxHealth: boss == null ? null : 20,
      bossStability: boss?.phase.name == 'perfect'
          ? boss?.stability.current
          : null,
      patternConfidence: boss == null ? null : pattern.confidence,
      bossPhase: boss?.phase.name,
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
