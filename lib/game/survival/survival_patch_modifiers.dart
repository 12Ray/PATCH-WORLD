import 'package:patch_world/game/rules/rule_ids.dart';

final class SurvivalPatchModifiers {
  const SurvivalPatchModifiers(this.patchTiers);

  final Map<String, int> patchTiers;

  int tier(String patchId) => patchTiers[patchId] ?? 0;

  int get motionTaxTier => tier(RuleIds.motionTax);
  int get retaliationEchoTier => tier(RuleIds.retaliationEcho);
  int get hostileTurboTier => tier(RuleIds.hostileTurbo);
  int get frameBurstTier => tier(RuleIds.frameBurst);
  int get phaseLeakTier => tier(RuleIds.phaseLeak);
  int get duplicateFaultTier => tier(RuleIds.duplicateFault);

  int get pulseDamage => 1 + motionTaxTier;

  double get pulseRadiusMultiplier => 1 + motionTaxTier * 0.14;

  double get pulseCooldownMultiplier => frameBurstTier == 0
      ? 1
      : (1 - frameBurstTier * 0.18).clamp(0.46, 1).toDouble();

  int get killExperienceMultiplier => 1 + hostileTurboTier;

  int get duplicateRewardMultiplier => duplicateFaultTier == 0 ? 1 : 2;

  bool get phaseWallsLeak => phaseLeakTier > 0;
}
