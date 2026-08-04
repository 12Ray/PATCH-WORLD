import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/systems/motion_tax_controller.dart';

void main() {
  test('builds heat while moving and cools while stopped', () {
    final controller = MotionTaxController();
    controller.update(dt: 2, isMoving: true);
    expect(controller.heat, 24);
    controller.update(dt: 0.5, isMoving: false);
    expect(controller.heat, 9);
  });

  test('overheat requests damage once and resets heat to 40', () {
    final controller = MotionTaxController(heatGainPerSecond: 100);
    final result = controller.update(dt: 1, isMoving: true);
    expect(result.didOverheat, isTrue);
    expect(controller.heat, 40);
  });

  test('heat never becomes negative', () {
    final controller = MotionTaxController();
    controller.update(dt: 10, isMoving: false);
    expect(controller.heat, 0);
  });
}
