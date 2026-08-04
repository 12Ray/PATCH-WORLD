import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';

void main() {
  test('survival score rewards time, kills, elites, and chosen risk', () {
    final state = SurvivalRunState()..addRiskTier(3);
    state.update(60);
    state.recordKill();
    state.recordKill(elite: true);

    expect(state.riskMultiplier, closeTo(1.36, 0.001));
    expect(state.score, ((600 + 50 + 250) * 1.36).round());
  });

  test('kills level up and combo window grows with flow', () {
    final state = SurvivalRunState();
    for (var index = 0; index < 6; index += 1) {
      state.recordKill();
    }
    expect(state.level, 2);
    expect(state.combo, 6);

    state.recordHit();
    expect(state.combo, 3);
    expect(state.comboRemaining, closeTo(3.12, 0.001));
    state.update(3.13);
    expect(state.combo, 0);
    expect(state.maxCombo, 6);
  });

  test('flow state multiplies full kill value at combo thresholds', () {
    final state = SurvivalRunState();
    for (var index = 0; index < 4; index += 1) {
      state.recordKill();
    }
    expect(state.flowMultiplier, 1);
    expect(state.score, 100);

    state.recordKill();
    expect(state.flowMultiplier, 2);
    expect(state.score, 150);
    expect(state.comboRemaining, closeTo(3.20, 0.001));

    for (var index = 0; index < 5; index += 1) {
      state.recordKill();
    }
    expect(state.flowMultiplier, 3);
    expect(state.score, 425);

    state.recordKill(elite: true);
    expect(state.score, 1250);
  });

  test('flow milestones pay stable data at five ten and twenty', () {
    expect(SurvivalRunState.flowDataRewardForCombo(4), 0);
    expect(SurvivalRunState.flowDataRewardForCombo(5), 1);
    expect(SurvivalRunState.flowDataRewardForCombo(10), 1);
    expect(SurvivalRunState.flowDataRewardForCombo(20), 2);
    expect(SurvivalRunState.flowDataRewardForCombo(21), 0);
    expect(SurvivalRunState.flowDataRewardForCombo(40), 2);
  });

  test('result snapshot preserves run data after the live state resets', () {
    final state = SurvivalRunState()
      ..elapsedSeconds = 91.8
      ..upgradePatch('patch.motion_tax', riskTier: 1);
    state.recordKill(elite: true);
    final result = SurvivalResultSnapshot.fromRun(
      state,
      isBestScore: true,
      isBestTime: true,
    );

    state.reset();
    expect(result.formattedTime, '1:31');
    expect(result.eliteKills, 1);
    expect(result.maxCombo, 1);
    expect(result.patchTiers, <String, int>{'patch.motion_tax': 1});
    expect(result.firstPatchId, 'patch.motion_tax');
    expect(result.meaningfulEventCount, 2);
    expect(result.longestQuietSeconds, 91.8);
    expect(result.hasPacingGap, isTrue);
  });

  test('reward multiplier grants bonus experience and score', () {
    final state = SurvivalRunState();
    state.recordKill(rewardMultiplier: 2);
    expect(state.kills, 1);
    expect(state.experience, 2);
    expect(state.bonusScore, 25);
    expect(state.score, 50);
  });

  test('recent kill rate only measures the latest twenty-second window', () {
    final state = SurvivalRunState()..elapsedSeconds = 5;
    state.recordKill();
    state.recordKill();
    expect(state.recentKillsPerSecond(), closeTo(0.4, 0.001));

    state.elapsedSeconds = 26;
    state.recordKill();
    expect(state.recentKillsPerSecond(), closeTo(0.05, 0.001));
  });

  test('patch tiers cap at three and reset with the run', () {
    final state = SurvivalRunState();
    expect(state.upgradePatch('patch.test', riskTier: 2), 1);
    expect(state.upgradePatch('patch.test', riskTier: 2), 2);
    expect(state.upgradePatch('patch.test', riskTier: 2), 3);
    expect(state.upgradePatch('patch.test', riskTier: 2), 3);
    expect(state.riskTierTotal, 6);

    state.reset();
    expect(state.patchTier('patch.test'), 0);
    expect(state.riskTierTotal, 0);
  });

  test('level choices rotate deterministically through the patch catalog', () {
    final levelTwo = SurvivalUpgradeCatalog.choicesForLevel(2);
    final levelThree = SurvivalUpgradeCatalog.choicesForLevel(3);
    expect(levelTwo, hasLength(3));
    expect(levelThree, hasLength(3));
    expect(levelTwo.first.id, isNot(levelThree.first.id));
  });

  test('max-tier patches are excluded from future choices', () {
    final maxed = <String, int>{
      SurvivalUpgradeCatalog.all.first.id: 3,
      SurvivalUpgradeCatalog.all[1].id: 3,
      SurvivalUpgradeCatalog.all[2].id: 3,
    };
    final choices = SurvivalUpgradeCatalog.choicesForLevel(
      2,
      patchTiers: maxed,
    );
    expect(choices, hasLength(3));
    expect(choices.any((patch) => maxed.containsKey(patch.id)), isFalse);
  });

  test('overclock timers expire independently', () {
    final state = SurvivalRunState()
      ..triggerTurboOverclock()
      ..triggerFrameOverclock();
    expect(state.overclockActive, isTrue);
    expect(state.overclockCooldownMultiplier, 0.65);
    state.update(1.51);
    expect(state.overclockActive, isFalse);
  });

  test('data surge grants a two second damage and cooldown window', () {
    final state = SurvivalRunState()..triggerDataSurge();

    expect(state.dataSurgeActive, isTrue);
    expect(state.dataSurgeDamageBonus, 1);
    expect(state.dataSurgeCooldownMultiplier, 0.70);
    state.update(2.01);
    expect(state.dataSurgeActive, isFalse);
    expect(state.dataSurgeDamageBonus, 0);
    expect(state.dataSurgeCooldownMultiplier, 1);
  });
}
