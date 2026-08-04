import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/stability_state.dart';

void main() {
  test('four healing pulses overflow stability from 75', () {
    final state = StabilityState();
    for (var i = 0; i < 4; i += 1) {
      state.addHealingUnit(1);
    }
    expect(state.current, 150);
    expect(state.isOverflowed, isTrue);
  });

  test('failed attempt resets to perfect phase start', () {
    final state = StabilityState()..addHealingUnit(2);
    state.resetPerfectPhase();
    expect(state.current, 75);
  });
}
