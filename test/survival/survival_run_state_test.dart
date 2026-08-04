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

  test('kills level up and combo expires after three seconds', () {
    final state = SurvivalRunState();
    for (var index = 0; index < 6; index += 1) {
      state.recordKill();
    }
    expect(state.level, 2);
    expect(state.combo, 6);

    state.recordHit();
    expect(state.combo, 3);
    state.update(3.01);
    expect(state.combo, 0);
    expect(state.maxCombo, 6);
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
}
