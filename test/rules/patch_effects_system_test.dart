import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/patch_effects_system.dart';

void main() {
  test('motion tax requests player damage on overheat', () {
    final runState = RunState()..selectPatch(RuleIds.motionTax);
    var damage = 0;
    final system = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (_) {},
      damagePlayer: (amount, causeId) => damage += amount,
    );
    system.update(playerStatusDt: 9, isPlayerMoving: true);
    expect(damage, 1);
  });

  test('retaliation echo requests spawn at fourth pulse position', () {
    final runState = RunState()..selectPatch(RuleIds.retaliationEcho);
    Vector2? spawnedPosition;
    final system = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (position) => spawnedPosition = position,
      damagePlayer: (_, _) {},
    );
    for (var i = 0; i < 4; i += 1) {
      system.onPatchPulseEmitted(Vector2(10 + i.toDouble(), 20));
    }
    expect(spawnedPosition, Vector2(13, 20));
  });
}
