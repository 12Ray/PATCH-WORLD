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
      input.handleKeyDown(LogicalKeyboardKey.space);

      expect(input.consumeAttack(), isTrue);
      expect(input.consumeAttack(), isFalse);
    });

    test('interact is consumed only once', () {
      final input = InputController();
      input.handleKeyDown(LogicalKeyboardKey.keyE);

      expect(input.consumeInteract(), isTrue);
      expect(input.consumeInteract(), isFalse);
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
      input.queueAttack();
      input.queueInteract();
      expect(input.consumeAttack(), isTrue);
      expect(input.consumeInteract(), isTrue);

      input.clearAll();
      expect(input.movementAxis.length2, 0);
    });
  });
}
