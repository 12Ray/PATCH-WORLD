import 'dart:math' as math;

import 'package:patch_world/game/combat/player_weapon.dart';

enum SurvivalDifficultyStage { boot, escalation, crisis, endless }

extension SurvivalDifficultyStageSpec on SurvivalDifficultyStage {
  int get startSecond => switch (this) {
    SurvivalDifficultyStage.boot => 0,
    SurvivalDifficultyStage.escalation => 300,
    SurvivalDifficultyStage.crisis => 720,
    SurvivalDifficultyStage.endless => 1200,
  };

  int? get endSecond => switch (this) {
    SurvivalDifficultyStage.boot => 300,
    SurvivalDifficultyStage.escalation => 720,
    SurvivalDifficultyStage.crisis => 1200,
    SurvivalDifficultyStage.endless => null,
  };

  int get eliteIntervalSeconds => switch (this) {
    SurvivalDifficultyStage.boot => 90,
    SurvivalDifficultyStage.escalation => 75,
    SurvivalDifficultyStage.crisis => 60,
    SurvivalDifficultyStage.endless => 45,
  };

  String get localizationKey => 'survivalStage.$name';
}

final class SurvivalDifficultyProfile {
  const SurvivalDifficultyProfile({
    required this.stage,
    required this.threatPressure,
    required this.spawnIntervalSeconds,
    required this.activeEnemyCap,
    required this.crawlerCap,
    required this.sentinelCap,
    required this.phaseHoundCap,
    required this.anomalyCap,
    required this.enemySpeedMultiplier,
    required this.endlessTier,
  });

  final SurvivalDifficultyStage stage;
  final double threatPressure;
  final double spawnIntervalSeconds;
  final int activeEnemyCap;
  final int crawlerCap;
  final int sentinelCap;
  final int phaseHoundCap;
  final int anomalyCap;
  final double enemySpeedMultiplier;
  final int endlessTier;
}

final class SurvivalSpawnAllocation {
  const SurvivalSpawnAllocation({
    required this.crawlers,
    required this.sentinels,
    required this.phaseHounds,
    required this.spawnAnomaly,
  });

  factory SurvivalSpawnAllocation.forWave({
    required SurvivalDifficultyProfile profile,
    required int activeEnemies,
    required int requestedCrawlers,
    required int requestedSentinels,
    required int requestedPhaseHounds,
    required int activePhaseHounds,
    required int activeAnomalies,
    required bool anomalyEligible,
  }) {
    var remaining = math.max(0, profile.activeEnemyCap - activeEnemies);
    final crawlers = math.min(
      remaining,
      requestedCrawlers.clamp(1, profile.crawlerCap),
    );
    remaining -= crawlers;
    final sentinels = math.min(
      remaining,
      requestedSentinels.clamp(0, profile.sentinelCap),
    );
    remaining -= sentinels;
    final phaseHounds = math.min(
      remaining,
      math.min(
        requestedPhaseHounds,
        math.max(0, profile.phaseHoundCap - activePhaseHounds),
      ),
    );
    remaining -= phaseHounds;
    final spawnAnomaly =
        anomalyEligible &&
        remaining > 0 &&
        activeAnomalies < profile.anomalyCap;
    return SurvivalSpawnAllocation(
      crawlers: crawlers,
      sentinels: sentinels,
      phaseHounds: phaseHounds,
      spawnAnomaly: spawnAnomaly,
    );
  }

  final int crawlers;
  final int sentinels;
  final int phaseHounds;
  final bool spawnAnomaly;

  int get total => crawlers + sentinels + phaseHounds + (spawnAnomaly ? 1 : 0);
}

/// Single source of truth for the intended 20-minute survival curve.
///
/// The first three stages are authored vertical-slice targets. Endless scaling
/// only begins after the player has survived the complete 20-minute run.
abstract final class SurvivalBalanceCurve {
  static SurvivalDifficultyStage stageForSecond(int second) {
    final safeSecond = math.max(0, second);
    if (safeSecond < 300) return SurvivalDifficultyStage.boot;
    if (safeSecond < 720) return SurvivalDifficultyStage.escalation;
    if (safeSecond < 1200) return SurvivalDifficultyStage.crisis;
    return SurvivalDifficultyStage.endless;
  }

  static SurvivalDifficultyProfile profileForSecond(int second) {
    final safeSecond = math.max(0, second);
    final stage = stageForSecond(safeSecond);
    switch (stage) {
      case SurvivalDifficultyStage.boot:
        final progress = safeSecond / 300;
        return SurvivalDifficultyProfile(
          stage: stage,
          threatPressure: 4.0 + safeSecond / 24,
          spawnIntervalSeconds: 3.0 - progress * .6,
          activeEnemyCap: 24,
          crawlerCap: 6,
          sentinelCap: 2,
          phaseHoundCap: 1,
          anomalyCap: 2,
          enemySpeedMultiplier: .95 + progress * .10,
          endlessTier: 0,
        );
      case SurvivalDifficultyStage.escalation:
        final stageSecond = safeSecond - 300;
        final progress = stageSecond / 420;
        return SurvivalDifficultyProfile(
          stage: stage,
          threatPressure: 16.6 + stageSecond / 20,
          spawnIntervalSeconds: 2.4 - progress * .45,
          activeEnemyCap: 32,
          crawlerCap: 8,
          sentinelCap: 3,
          phaseHoundCap: 2,
          anomalyCap: 4,
          enemySpeedMultiplier: 1.05 + progress * .10,
          endlessTier: 0,
        );
      case SurvivalDifficultyStage.crisis:
        final stageSecond = safeSecond - 720;
        final progress = stageSecond / 480;
        return SurvivalDifficultyProfile(
          stage: stage,
          threatPressure: 38.0 + stageSecond / 17,
          spawnIntervalSeconds: 1.95 - progress * .4,
          activeEnemyCap: 40,
          crawlerCap: 9,
          sentinelCap: 4,
          phaseHoundCap: 3,
          anomalyCap: 6,
          enemySpeedMultiplier: 1.15 + progress * .10,
          endlessTier: 0,
        );
      case SurvivalDifficultyStage.endless:
        final stageSecond = safeSecond - 1200;
        final endlessTier = 1 + stageSecond ~/ 60;
        return SurvivalDifficultyProfile(
          stage: stage,
          threatPressure: 67.0 + stageSecond / 16 + endlessTier * 2.4,
          spawnIntervalSeconds: math.max(.9, 1.55 - endlessTier * .05),
          activeEnemyCap: math.min(64, 44 + endlessTier * 3),
          crawlerCap: math.min(14, 9 + endlessTier),
          sentinelCap: math.min(8, 4 + endlessTier ~/ 2),
          phaseHoundCap: math.min(5, 3 + endlessTier ~/ 3),
          anomalyCap: math.min(10, 6 + endlessTier ~/ 2),
          enemySpeedMultiplier: math.min(1.45, 1.25 + endlessTier * .02),
          endlessTier: endlessTier,
        );
    }
  }

  static bool crossedEliteBetween({
    required int previousSecond,
    required int currentSecond,
  }) {
    final previous = math.max(0, previousSecond);
    final current = math.max(previous, currentSecond);
    for (final stage in SurvivalDifficultyStage.values) {
      final interval = stage.eliteIntervalSeconds;
      final firstTick = stage.startSecond + interval;
      final finalTick = math.min(current, (stage.endSecond ?? current + 1) - 1);
      final lowerBound = math.max(previous + 1, firstTick);
      if (lowerBound > finalTick) continue;
      final ticksAfterFirst = math.max(0, lowerBound - firstTick);
      final nextTick =
          firstTick + ((ticksAfterFirst + interval - 1) ~/ interval) * interval;
      if (nextTick <= finalTick) return true;
    }
    return false;
  }
}

final class SurvivalWeaponBaseline {
  const SurvivalWeaponBaseline({
    required this.weapon,
    required this.attackCooldownMultiplier,
    required this.comboDamage,
    required this.targetSustainedDps,
  });

  final PlayerWeapon weapon;
  final double attackCooldownMultiplier;
  final int comboDamage;
  final double targetSustainedDps;

  double get estimatedSustainedDps =>
      (comboDamage / 6) / (weapon.baseCooldown * attackCooldownMultiplier);

  static SurvivalWeaponBaseline forWeapon(PlayerWeapon weapon) =>
      switch (weapon) {
        PlayerWeapon.sword => const SurvivalWeaponBaseline(
          weapon: PlayerWeapon.sword,
          attackCooldownMultiplier: .92,
          comboDamage: 8,
          targetSustainedDps: 5.1,
        ),
        PlayerWeapon.gauntlet => const SurvivalWeaponBaseline(
          weapon: PlayerWeapon.gauntlet,
          attackCooldownMultiplier: .90,
          comboDamage: 10,
          targetSustainedDps: 5.0,
        ),
        PlayerWeapon.gun => const SurvivalWeaponBaseline(
          weapon: PlayerWeapon.gun,
          attackCooldownMultiplier: 1.02,
          comboDamage: 9,
          targetSustainedDps: 4.5,
        ),
      };
}
