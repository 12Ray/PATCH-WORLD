import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/input_controller.dart';

void main() {
  group('InputController', () {
    test('normalizes diagonal movement', () {
      final input = InputController();
      input.syncPressedKeys(<LogicalKeyboardKey>{
        LogicalKeyboardKey.keyW,
        LogicalKeyboardKey.keyD,
      });

      expect(input.movementAxis.length, closeTo(1, 0.0001));
      expect(input.movementAxis.x, greaterThan(0));
      expect(input.movementAxis.y, lessThan(0));
    });

    test('attack is consumed only once', () {
      final input = InputController();
      input.handleKeyDown(LogicalKeyboardKey.keyJ);

      expect(input.consumeAttack(), isTrue);
      expect(input.consumeAttack(), isFalse);
    });

    test('interact is consumed only once', () {
      final input = InputController();
      input.handleKeyDown(LogicalKeyboardKey.keyL);

      expect(input.consumeInteract(), isTrue);
      expect(input.consumeInteract(), isFalse);
    });

    test('shift parries and K exposes special press hold and release', () {
      final input = InputController();
      input.handleKeyDown(LogicalKeyboardKey.shiftLeft);
      input.handleKeyDown(LogicalKeyboardKey.keyK);

      expect(input.consumeParry(), isTrue);
      expect(input.consumeParry(), isFalse);
      expect(input.consumeSpecialPressDirection(), 0);
      expect(input.consumeSpecialPressDirection(), isNull);
      expect(input.specialHeld, isTrue);
      input.handleKeyUp(LogicalKeyboardKey.keyK);
      expect(input.specialHeld, isFalse);
      expect(input.consumeSpecialRelease(), isTrue);
      expect(input.consumeSpecialRelease(), isFalse);
    });

    test('legacy action keys no longer queue J K L actions', () {
      final input = InputController();
      input.handleKeyDown(LogicalKeyboardKey.space);
      input.handleKeyDown(LogicalKeyboardKey.keyQ);
      input.handleKeyDown(LogicalKeyboardKey.keyE);
      input.handleKeyDown(LogicalKeyboardKey.enter);

      expect(input.consumeAttack(), isFalse);
      expect(input.consumeSpecialPressDirection(), isNull);
      expect(input.consumeInteract(), isFalse);
    });

    test('up queues a jump and exposes held state', () {
      final input = InputController();
      input.syncPressedKeys(<LogicalKeyboardKey>{LogicalKeyboardKey.keyW});
      input.handleKeyDown(LogicalKeyboardKey.keyW);

      expect(input.jumpHeld, isTrue);
      expect(input.consumeJump(), isTrue);
      expect(input.consumeJump(), isFalse);
    });

    test('supports arrow keys', () {
      final input = InputController();
      input.syncPressedKeys(<LogicalKeyboardKey>{LogicalKeyboardKey.arrowLeft});

      expect(input.movementAxis.x, -1);
      expect(input.movementAxis.y, 0);
    });

    test('supports touch movement and action queues', () {
      final input = InputController()..setVirtualMovement(1, -1);

      expect(input.movementAxis.length, closeTo(1, 0.0001));
      expect(input.jumpHeld, isTrue);
      expect(input.consumeJump(), isTrue);
      input.queueAttack();
      input.queueParry();
      input.queueSpecialPress(-1);
      input.queueInteract();
      expect(input.consumeAttack(), isTrue);
      expect(input.consumeParry(), isTrue);
      expect(input.consumeSpecialPressDirection(), -1);
      expect(input.specialHeld, isTrue);
      input.queueSpecialRelease();
      expect(input.consumeSpecialRelease(), isTrue);
      expect(input.consumeInteract(), isTrue);

      input.clearAll();
      expect(input.movementAxis.length2, 0);
    });

    test('same-direction double tap never queues a special ability', () {
      final input = InputController();

      input.handleKeyDown(LogicalKeyboardKey.keyD);
      input.handleKeyDown(LogicalKeyboardKey.keyD);

      expect(input.consumeSpecialPressDirection(), isNull);
    });

    test('K key repeat does not queue a second special press', () {
      final input = InputController();

      input.handleKeyDown(LogicalKeyboardKey.keyK);
      expect(input.consumeSpecialPressDirection(), 0);
      input.handleKeyDown(LogicalKeyboardKey.keyK, isRepeat: true);
      expect(input.consumeSpecialPressDirection(), isNull);
    });
  });
}
