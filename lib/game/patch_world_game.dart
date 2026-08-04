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
import 'package:patch_world/game/patch_world.dart';
import 'package:patch_world/game/rules/anomalies/damage_sign_inverted_rule.dart';
import 'package:patch_world/game/rules/game_rule.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_engine.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/combat_system.dart';

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

  late final CombatSystem combatSystem;
  RoomId currentRoom = RoomId.damageLab;
  PatchSelectionRequest? pendingPatchSelection;

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
    await super.onLoad();
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
  }

  @override
  void update(double dt) {
    if (world.isReady) {
      world.player.setMovementInput(input.movementAxis);
      if (input.consumeAttack()) {
        world.player.tryAttack();
      }
      if (input.consumeInteract()) {
        world.player.tryInteract();
      }
    }
    super.update(dt);
  }

  void _togglePause() {
    if (paused) {
      resumeEngine();
    } else {
      input.clearTransientActions();
      pauseEngine();
    }
  }
}
