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

  test('critical flow activates at chain twenties and resets safely', () {
    final state = SurvivalRunState();
    state.seedComboForQa(19);
    expect(state.criticalFlowActive, isFalse);

    state.recordKill();
    expect(state.combo, 20);
    expect(state.criticalFlowRemaining, SurvivalRunState.criticalFlowDuration);
    expect(state.criticalFlowDamageBonus, 1);
    expect(state.criticalFlowCooldownMultiplier, 0.75);
    expect(state.comboProgress, 1);

    state.update(2);
    expect(state.criticalFlowProgress, closeTo(0.6, 0.001));
    for (var index = 0; index < 20; index += 1) {
      state.recordKill();
    }
    expect(state.combo, 40);
    expect(state.criticalFlowRemaining, SurvivalRunState.criticalFlowDuration);

    state.update(SurvivalRunState.criticalFlowDuration + 0.01);
    expect(state.criticalFlowActive, isFalse);
    expect(state.criticalFlowDamageBonus, 0);
    expect(state.criticalFlowCooldownMultiplier, 1);

    state.recordKill();
    state.reset();
    expect(state.criticalFlowRemaining, 0);
    expect(state.comboProgress, 0);
  });

  test('reroute starts once, refills on mini-bosses, and resets', () {
    final state = SurvivalRunState();
    expect(state.reroutesRemaining, 1);
    expect(state.consumeReroute(), isTrue);
    expect(state.consumeReroute(), isFalse);

    state.recordKill(miniBoss: true);
    expect(state.reroutesRemaining, 1);
    state.grantReroute();
    state.grantReroute();
    expect(state.reroutesRemaining, SurvivalRunState.maxReroutes);

    state.reset();
    expect(state.reroutesRemaining, 1);
  });

  test('multi-level rewards queue every earned patch draft in order', () {
    final state = SurvivalRunState();
    expect(state.recordKill(miniBoss: true), isTrue);
    expect(state.level, 3);
    expect(state.pendingUpgradeCount, 2);
    expect(state.takePendingUpgradeLevel(), 2);
    expect(state.takePendingUpgradeLevel(), 3);
    expect(state.takePendingUpgradeLevel(), isNull);

    state.recordKill(miniBoss: true, rewardMultiplier: 3);
    expect(state.pendingUpgradeCount, greaterThan(1));
    state.reset();
    expect(state.pendingUpgradeCount, 0);
  });

  test('volatile caches reward flow and preserve run recall', () {
    final state = SurvivalRunState();
    state.recordHotCacheSpawned();
    expect(state.recordHotCacheCollected(), 400);
    for (var index = 0; index < 5; index += 1) {
      state.recordKill();
    }
    state.recordHotCacheSpawned();
    expect(state.flowMultiplier, 2);
    final bonusBeforeFlowCache = state.bonusScore;
    expect(state.recordHotCacheCollected(), 800);
    expect(state.bonusScore - bonusBeforeFlowCache, 800);
    for (var index = 0; index < 5; index += 1) {
      state.recordKill();
    }
    state.recordHotCacheSpawned();
    expect(state.flowMultiplier, 3);
    expect(state.recordHotCacheCollected(), 1200);
    for (var index = 0; index < 10; index += 1) {
      state.recordKill();
    }
    state.recordHotCacheSpawned();
    expect(state.flowMultiplier, 4);
    expect(state.recordHotCacheCollected(), 1600);
    state.recordHotCacheSpawned();
    state.recordHotCacheExpired();
    final snapshot = SurvivalResultSnapshot.fromRun(
      state,
      isBestScore: false,
      isBestTime: false,
    );
    expect(snapshot.hotCachesSpawned, 5);
    expect(snapshot.hotCachesCollected, 4);
    expect(state.hotCachesExpired, 1);
    expect(state.bonusScore, greaterThanOrEqualTo(1200));

    state.reset();
    expect(state.hotCachesSpawned, 0);
    expect(state.hotCachesCollected, 0);
    expect(state.hotCachesExpired, 0);
  });

  test('reroute prioritizes a different non-maxed patch offer', () {
    final firstOffer = SurvivalUpgradeCatalog.choicesForLevel(2);
    final rerouted = SurvivalUpgradeCatalog.reroutedChoicesForLevel(
      level: 2,
      currentChoices: firstOffer,
    );
    expect(rerouted, hasLength(3));
    expect(
      rerouted
          .map((patch) => patch.id)
          .toSet()
          .intersection(firstOffer.map((patch) => patch.id).toSet()),
      isEmpty,
    );

    final maxedPatchId = rerouted.first.id;
    final filtered = SurvivalUpgradeCatalog.reroutedChoicesForLevel(
      level: 2,
      currentChoices: firstOffer,
      patchTiers: <String, int>{maxedPatchId: 3},
    );
    expect(filtered.any((patch) => patch.id == maxedPatchId), isFalse);
    expect(
      filtered.map((patch) => patch.id).toSet(),
      isNot(equals(firstOffer.map((patch) => patch.id).toSet())),
    );
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
