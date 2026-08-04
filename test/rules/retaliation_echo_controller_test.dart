import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/systems/retaliation_echo_controller.dart';

void main() {
  test('creates an echo on every fourth pulse', () {
    final controller = RetaliationEchoController();
    expect(controller.recordPulse(), isFalse);
    expect(controller.recordPulse(), isFalse);
    expect(controller.recordPulse(), isFalse);
    expect(controller.recordPulse(), isTrue);
    expect(controller.pulseCount, 0);
  });

  test('reset clears a partial counter', () {
    final controller = RetaliationEchoController();
    controller.recordPulse();
    controller.recordPulse();
    controller.reset();
    expect(controller.pulseCount, 0);
  });
}
