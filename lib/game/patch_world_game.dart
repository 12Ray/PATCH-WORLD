import 'dart:async';

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
  PatchWorldGame()
    : super(
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

  final InputController input = InputController();
  final RunState runState = RunState();
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

  late final CombatSystem combatSystem;
  late final PatchEffectsSystem patchEffects;
  late final EnemyTempoSystem enemyTempo;
  late final DuplicateFaultSystem duplicateFault;
  RoomId currentRoom = RoomId.damageLab;
  PatchSelectionRequest? pendingPatchSelection;
  double _uiPublishAccumulator = 0;
  bool _roomRestartRequested = false;

  RuleContext get ruleContext => RuleContext(
    roomId: currentRoom,
    selectedPatchIds: runState.selectedPatchIds.toSet(),
  );

  @override
  Future<void> onLoad() async {
    try {
      settings.value = await settingsService.load();
    } catch (_) {
      settings.value = const GameSettings();
    }
    try {
      await localization.load(settings.value.languageCode);
    } catch (_) {
      // Missing localization must not prevent silent/offline play.
    }
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
      if (event.logicalKey == LogicalKeyboardKey.escape &&
          pendingPatchSelection == null) {
        _togglePause();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
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
      enemySpeedMultiplier: enemyTempo.speedMultiplier,
    );
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
    } else {
      throw StateError('Unknown patch room: ${request.roomId}');
    }
    publishUiSnapshot(force: true);
    resumeEngine();
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
    ruleEngine.removeRule(RuleIds.legacyDamageInverted);
    input.clearAll();
    pauseEngine();
    overlays.add(OverlayIds.ending);
  }

  void restartRun() => unawaited(_restartRun());

  Future<void> _restartRun() async {
    overlays.remove(OverlayIds.ending);
    runState.reset();
    patternTracker.reset();
    patchEffects.resetForRoomRestart();
    enemyTempo.resetForRoomRestart();
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    currentRoom = RoomId.damageLab;
    await world.loadRoom(currentRoom);
    publishUiSnapshot(force: true);
    resumeEngine();
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
    overlays.remove(OverlayIds.pause);
    overlays.add(OverlayIds.settings);
  }

  void closeSettings() {
    overlays.remove(OverlayIds.settings);
    overlays.add(OverlayIds.pause);
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
      world.player.maxIntegrity = next.assistMode ? 7 : 5;
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
        RoomId.damageLab => 'DAMAGE LAB',
        RoomId.temporalHall => 'TEMPORAL HALL',
        RoomId.collisionArchive => 'COLLISION ARCHIVE',
        RoomId.optimizerCore => 'OPTIMIZATION CORE',
      },
      anomalyLabel: switch (currentRoom) {
        RoomId.damageLab =>
          ruleEngine.containsRule(RuleIds.damageSignInverted)
              ? 'DAMAGE SIGN = -1'
              : 'DAMAGE NORMALIZED',
        RoomId.temporalHall => 'TIME ADVANCES WITH INTENT',
        RoomId.collisionArchive => 'COLLISION PRODUCES UNITY',
        RoomId.optimizerCore => 'PATTERN ANALYSIS ACTIVE',
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
