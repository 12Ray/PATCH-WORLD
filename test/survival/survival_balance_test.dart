import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/survival/survival_balance.dart';

void main() {
  test('difficulty stages cover the authored twenty-minute curve', () {
    expect(
      SurvivalBalanceCurve.stageForSecond(0),
      SurvivalDifficultyStage.boot,
    );
    expect(
      SurvivalBalanceCurve.stageForSecond(299),
      SurvivalDifficultyStage.boot,
    );
    expect(
      SurvivalBalanceCurve.stageForSecond(300),
      SurvivalDifficultyStage.escalation,
    );
    expect(
      SurvivalBalanceCurve.stageForSecond(719),
      SurvivalDifficultyStage.escalation,
    );
    expect(
      SurvivalBalanceCurve.stageForSecond(720),
      SurvivalDifficultyStage.crisis,
    );
    expect(
      SurvivalBalanceCurve.stageForSecond(1199),
      SurvivalDifficultyStage.crisis,
    );
    expect(
      SurvivalBalanceCurve.stageForSecond(1200),
      SurvivalDifficultyStage.endless,
    );
  });

  test('pressure rises while spawn intervals contract at stage boundaries', () {
    final profiles = <int>[
      0,
      299,
      300,
      719,
      720,
      1199,
      1200,
    ].map(SurvivalBalanceCurve.profileForSecond).toList();

    for (var index = 1; index < profiles.length; index += 1) {
      expect(
        profiles[index].threatPressure,
        greaterThan(profiles[index - 1].threatPressure),
      );
      expect(
        profiles[index].spawnIntervalSeconds,
        lessThanOrEqualTo(profiles[index - 1].spawnIntervalSeconds),
      );
    }
  });

  test('opening density fills the expanded arena without raising its cap', () {
    final profile = SurvivalBalanceCurve.profileForSecond(0);

    expect(profile.threatPressure, greaterThanOrEqualTo(4));
    expect(profile.spawnIntervalSeconds, lessThanOrEqualTo(3));
    expect(profile.activeEnemyCap, 24);
  });

  test('elite cadence accelerates in each authored stage', () {
    expect(
      SurvivalBalanceCurve.crossedEliteBetween(
        previousSecond: 89,
        currentSecond: 90,
      ),
      isTrue,
    );
    expect(
      SurvivalBalanceCurve.crossedEliteBetween(
        previousSecond: 374,
        currentSecond: 375,
      ),
      isTrue,
    );
    expect(
      SurvivalBalanceCurve.crossedEliteBetween(
        previousSecond: 779,
        currentSecond: 780,
      ),
      isTrue,
    );
    expect(
      SurvivalBalanceCurve.crossedEliteBetween(
        previousSecond: 1244,
        currentSecond: 1245,
      ),
      isTrue,
    );
  });

  test('three weapon baselines stay inside the target sustained DPS band', () {
    for (final weapon in PlayerWeapon.values) {
      final baseline = SurvivalWeaponBaseline.forWeapon(weapon);
      expect(
        (baseline.estimatedSustainedDps - baseline.targetSustainedDps).abs(),
        lessThan(.25),
        reason: weapon.name,
      );
      expect(baseline.estimatedSustainedDps, inInclusiveRange(4.4, 5.4));
    }
  });

  test('wave allocation cannot cross the active enemy cap', () {
    final profile = SurvivalBalanceCurve.profileForSecond(1199);
    final allocation = SurvivalSpawnAllocation.forWave(
      profile: profile,
      activeEnemies: profile.activeEnemyCap - 2,
      requestedCrawlers: 9,
      requestedSentinels: 4,
      requestedPhaseHounds: 3,
      activePhaseHounds: 0,
      activeAnomalies: 0,
      anomalyEligible: true,
    );

    expect(allocation.total, 2);
    expect(
      profile.activeEnemyCap - 2 + allocation.total,
      profile.activeEnemyCap,
    );
    expect(allocation.sentinels, 0);
    expect(allocation.phaseHounds, 0);
    expect(allocation.spawnAnomaly, isFalse);
  });

  test('wave allocation respects specialist caps before using a free slot', () {
    final profile = SurvivalBalanceCurve.profileForSecond(720);
    final allocation = SurvivalSpawnAllocation.forWave(
      profile: profile,
      activeEnemies: 0,
      requestedCrawlers: 1,
      requestedSentinels: 1,
      requestedPhaseHounds: 9,
      activePhaseHounds: profile.phaseHoundCap - 1,
      activeAnomalies: profile.anomalyCap,
      anomalyEligible: true,
    );

    expect(allocation.phaseHounds, 1);
    expect(allocation.spawnAnomaly, isFalse);
    expect(allocation.total, lessThanOrEqualTo(profile.activeEnemyCap));
  });
}
