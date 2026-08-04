import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/survival/survival_patch_modifiers.dart';

void main() {
  test('no patches preserves the campaign combat baseline', () {
    const modifiers = SurvivalPatchModifiers(<String, int>{});
    expect(modifiers.pulseDamage, 1);
    expect(modifiers.pulseRadiusMultiplier, 1);
    expect(modifiers.pulseCooldownMultiplier, 1);
    expect(modifiers.killExperienceMultiplier, 1);
    expect(modifiers.phaseWallsLeak, isFalse);
  });

  test('tier one patches expose a benefit alongside their risk', () {
    const modifiers = SurvivalPatchModifiers(<String, int>{
      RuleIds.motionTax: 1,
      RuleIds.hostileTurbo: 1,
      RuleIds.frameBurst: 1,
      RuleIds.phaseLeak: 1,
      RuleIds.duplicateFault: 1,
    });
    expect(modifiers.pulseDamage, 2);
    expect(modifiers.pulseRadiusMultiplier, closeTo(1.14, 0.001));
    expect(modifiers.pulseCooldownMultiplier, closeTo(0.82, 0.001));
    expect(modifiers.killExperienceMultiplier, 2);
    expect(modifiers.duplicateRewardMultiplier, 2);
    expect(modifiers.phaseWallsLeak, isTrue);
  });

  test('higher tiers scale without breaking cooldown bounds', () {
    const modifiers = SurvivalPatchModifiers(<String, int>{
      RuleIds.motionTax: 3,
      RuleIds.frameBurst: 3,
    });
    expect(modifiers.pulseDamage, 4);
    expect(modifiers.pulseRadiusMultiplier, closeTo(1.42, 0.001));
    expect(modifiers.pulseCooldownMultiplier, closeTo(0.46, 0.001));
    expect(modifiers.motionVentEnabled, isTrue);
    expect(modifiers.overheatBurstDamage, 2);
    expect(modifiers.frameOverclockDamageBonus, 1);
  });

  test('tier three side effects convert into offensive tools', () {
    const modifiers = SurvivalPatchModifiers(<String, int>{
      RuleIds.retaliationEcho: 3,
      RuleIds.hostileTurbo: 3,
      RuleIds.phaseLeak: 3,
      RuleIds.duplicateFault: 3,
    });
    expect(modifiers.echoPullsTargets, isTrue);
    expect(modifiers.echoDamage, 2);
    expect(modifiers.echoDamagesPlayer, isFalse);
    expect(modifiers.turboOverclockOnKill, isTrue);
    expect(modifiers.phaseOpenGuard, isTrue);
    expect(modifiers.duplicateBurstDamage, 2);
    expect(modifiers.duplicateRewardMultiplier, 3);
  });
}
