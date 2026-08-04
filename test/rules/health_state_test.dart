import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/health_state.dart';

void main() {
  test('healing beyond max reaches overflow threshold', () {
    final health = HealthState(max: 3, current: 2, overflowMargin: 2);
    expect(health.applyHealing(1), HealthMutation.healed);
    expect(health.current, 3);
    expect(health.applyHealing(1), HealthMutation.healed);
    expect(health.current, 4);
    expect(health.applyHealing(1), HealthMutation.overflowed);
    expect(health.current, 5);
    expect(health.isOverflowed, isTrue);
  });

  test('normal damage still defeats target', () {
    final health = HealthState(max: 3, current: 3);
    expect(health.applyDamage(1), HealthMutation.damaged);
    expect(health.applyDamage(2), HealthMutation.defeated);
    expect(health.current, 0);
  });
}
