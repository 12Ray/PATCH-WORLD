import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/systems/frame_burst_controller.dart';

void main() {
  test('cycles normal, warning, active, normal', () {
    final controller = FrameBurstController();
    controller.update(5);
    expect(controller.phase, FrameBurstPhase.warning);
    controller.update(0.7);
    expect(controller.phase, FrameBurstPhase.active);
    expect(controller.speedMultiplier, 2);
    controller.update(0.6);
    expect(controller.phase, FrameBurstPhase.normal);
  });
}
