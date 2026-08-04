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

  int get duplicateRewardMultiplier => duplicateFaultTier >= 3
      ? 3
      : duplicateFaultTier > 0
      ? 2
      : 1;

  bool get phaseWallsLeak => phaseLeakTier > 0;

  bool get motionVentEnabled => motionTaxTier >= 2;
  int get overheatBurstDamage => motionTaxTier >= 3 ? 2 : 0;

  bool get echoPullsTargets => retaliationEchoTier >= 2;
  int get echoDamage => retaliationEchoTier >= 3 ? 2 : 1;
  bool get echoDamagesPlayer => retaliationEchoTier < 3;

  int get turboBonusShardInterval => hostileTurboTier >= 2 ? 3 : 0;
  bool get turboOverclockOnKill => hostileTurboTier >= 3;

  bool get frameOverclockOnBurstEnd => frameBurstTier >= 2;
  int get frameOverclockDamageBonus => frameBurstTier >= 3 ? 1 : 0;

  double get phaseOpenMoveMultiplier => phaseLeakTier >= 2 ? 1.20 : 1;
  bool get phaseOpenGuard => phaseLeakTier >= 3;

  int get duplicateBurstDamage => duplicateFaultTier >= 3
      ? 2
      : duplicateFaultTier >= 2
      ? 1
      : 0;
  double get duplicateBurstRadius => duplicateFaultTier >= 3 ? 90 : 70;
}
