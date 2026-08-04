import 'dart:async';

import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/core/input_controller.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/core/ui_snapshot.dart';
import 'package:patch_world/game/patch_world.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/combat_system.dart';
import 'package:patch_world/game/systems/patch_effects_system.dart';

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
  final ValueNotifier<UiSnapshot> uiSnapshot = ValueNotifier<UiSnapshot>(
    UiSnapshot.initial(),
  );

  late final CombatSystem combatSystem;
  late final PatchEffectsSystem patchEffects;
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
    ruleEngine.setRules(const <GameRule>[DamageSignInvertedRule()]);
    combatSystem = CombatSystem(
      ruleEngine: ruleEngine,
      contextProvider: () => ruleContext,
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
    if (world.isReady) {
      final movement = input.movementAxis;
      world.player.setMovementInput(movement);
      patchEffects.update(
        playerStatusDt: dt,
        isPlayerMoving: movement.length2 > 0,
      );
      if (input.consumeAttack()) {
        world.player.tryAttack();
      }
      if (input.consumeInteract()) {
        world.player.tryInteract();
      }
      _uiPublishAccumulator += dt;
      if (_uiPublishAccumulator >= 0.10) {
        _uiPublishAccumulator = 0;
        publishUiSnapshot();
      }
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
    final request = pendingPatchSelection;
    if (request == null ||
        !request.choices.any((PatchDefinition item) => item.id == patchId)) {
      return;
    }
    runState.selectPatch(patchId);
    ruleEngine.removeRule(RuleIds.damageSignInverted);
    pendingPatchSelection = null;
    overlays.remove(OverlayIds.patchSelection);
    resumeEngine();
    unawaited(world.showPostPatchSandbox());
    publishUiSnapshot(force: true);
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
