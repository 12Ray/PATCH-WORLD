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
      spawnEcho: (_, _) {},
      spawnFriendlyBurst: (_, _, _, {excludedEntityId}) {},
      damagePlayer: (amount, causeId) => damage += amount,
    );
    system.update(playerStatusDt: 9, isPlayerMoving: true, motionTaxTier: 1);
    expect(damage, 1);
  });

  test('retaliation echo requests spawn at fourth pulse position', () {
    final runState = RunState()..selectPatch(RuleIds.retaliationEcho);
    Vector2? spawnedPosition;
    final system = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (position, _) => spawnedPosition = position,
      spawnFriendlyBurst: (_, _, _, {excludedEntityId}) {},
      damagePlayer: (_, _) {},
    );
    for (var i = 0; i < 4; i += 1) {
      system.onPatchPulseEmitted(Vector2(10 + i.toDouble(), 20));
    }
    expect(spawnedPosition, Vector2(13, 20));
  });

  test('tier two motion tax charges and consumes a vent pulse', () {
    final runState = RunState()..selectPatch(RuleIds.motionTax);
    final system = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (_, _) {},
      spawnFriendlyBurst: (_, _, _, {excludedEntityId}) {},
      damagePlayer: (_, _) {},
    );

    system.update(
      playerStatusDt: 0.76,
      isPlayerMoving: false,
      motionTaxTier: 2,
    );
    expect(system.motionVentCharged, isTrue);
    expect(system.consumeMotionVentCharge(), isTrue);
    expect(system.consumeMotionVentCharge(), isFalse);
  });

  test('ghost vent can charge while the player is moving', () {
    final runState = RunState()..selectPatch(RuleIds.motionTax);
    final system = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (_, _) {},
      spawnFriendlyBurst: (_, _, _, {excludedEntityId}) {},
      damagePlayer: (_, _) {},
    );

    system.update(
      playerStatusDt: 0.76,
      isPlayerMoving: true,
      motionTaxTier: 2,
      allowMovingVentCharge: true,
    );
    expect(system.motionVentCharged, isTrue);
  });

  test('tier three motion tax releases a burst on overheat', () {
    final runState = RunState()..selectPatch(RuleIds.motionTax);
    var burstDamage = 0;
    final system = PatchEffectsSystem(
      runState: runState,
      spawnEcho: (_, _) {},
      spawnFriendlyBurst: (_, damage, _, {excludedEntityId}) {
        burstDamage = damage;
      },
      damagePlayer: (_, _) {},
    );

    system.update(
      playerStatusDt: 9,
      isPlayerMoving: true,
      motionTaxTier: 3,
      playerPosition: Vector2.zero(),
    );
    expect(burstDamage, 2);
  });
}
