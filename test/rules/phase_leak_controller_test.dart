import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/systems/phase_leak_controller.dart';

void main() {
  test('cycles solid, warning, open, solid', () {
    final controller = PhaseLeakController();
    expect(controller.update(6), isTrue);
    expect(controller.phase, PhaseLeakPhase.warning);
    expect(controller.update(0.6), isTrue);
    expect(controller.phase, PhaseLeakPhase.open);
    expect(controller.update(1.5), isTrue);
    expect(controller.phase, PhaseLeakPhase.solid);
  });
}
