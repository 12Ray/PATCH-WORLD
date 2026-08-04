import 'package:flame/camera.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:patch_world/game/core/input_controller.dart';
import 'package:patch_world/game/patch_world.dart';

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
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _togglePause();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.handled;
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
