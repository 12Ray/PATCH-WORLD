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

    test('parry is queued once and number keys do not switch weapons', () {
      final input = InputController();
      input.handleKeyDown(LogicalKeyboardKey.shiftLeft);
      input.handleKeyDown(LogicalKeyboardKey.digit3);

      expect(input.consumeParry(), isTrue);
      expect(input.consumeParry(), isFalse);
      expect(input.consumeDashDirection(), isNull);
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
      input.queueDash(-1);
      input.queueInteract();
      expect(input.consumeAttack(), isTrue);
      expect(input.consumeParry(), isTrue);
      expect(input.consumeDashDirection(), -1);
      expect(input.consumeInteract(), isTrue);

      input.clearAll();
      expect(input.movementAxis.length2, 0);
    });

    test('same-direction double tap queues a dash inside 0.22 seconds', () {
      final input = InputController();

      input.handleKeyDown(LogicalKeyboardKey.keyD);
      input.advance(0.1);
      input.handleKeyDown(LogicalKeyboardKey.keyD);

      expect(input.consumeDashDirection(), 1);
      expect(input.consumeDashDirection(), isNull);
    });

    test('repeat and expired taps do not queue a dash', () {
      final input = InputController();

      input.handleKeyDown(LogicalKeyboardKey.keyA);
      input.handleKeyDown(LogicalKeyboardKey.keyA, isRepeat: true);
      expect(input.consumeDashDirection(), isNull);

      input.advance(0.23);
      input.handleKeyDown(LogicalKeyboardKey.keyA);
      expect(input.consumeDashDirection(), isNull);
    });
  });
}
