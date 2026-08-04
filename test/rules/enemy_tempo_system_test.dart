import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/enemy_tempo_system.dart';

void main() {
  test('hostile turbo applies a constant twenty percent multiplier', () {
    final state = RunState()..selectPatch(RuleIds.hostileTurbo);
    expect(EnemyTempoSystem(runState: state).speedMultiplier, 1.2);
  });

  test('frame burst applies its multiplier only during active phase', () {
    final state = RunState()..selectPatch(RuleIds.frameBurst);
    final system = EnemyTempoSystem(runState: state);
    system.update(5);
    expect(system.speedMultiplier, 1);
    system.update(0.7);
    expect(system.speedMultiplier, 2);
    system.update(0.6);
    expect(system.speedMultiplier, 1);
  });
}
