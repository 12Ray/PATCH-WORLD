import 'dart:math' as math;

final class SurvivalWavePlan {
  const SurvivalWavePlan({
    required this.crawlers,
    required this.sentinels,
    required this.phaseHounds,
    required this.spawnElite,
    required this.spawnComposite,
    required this.threatBudget,
    required this.endlessTier,
  });

  final int crawlers;
  final int sentinels;
  final int phaseHounds;
  final bool spawnElite;
  final bool spawnComposite;
  final double threatBudget;
  final int endlessTier;
}

final class SurvivalSpawnPoint {
  const SurvivalSpawnPoint(this.x, this.y);

  final double x;
  final double y;

  bool isOutside(double width, double height) =>
      x < 0 || y < 0 || x > width || y > height;
}

final class SurvivalMilestonePlan {
  const SurvivalMilestonePlan({
    required this.spawnElite,
    required this.spawnComposite,
    required this.activateTemporalStorm,
    required this.spawnOptimizerFragment,
  });

  final bool spawnElite;
  final bool spawnComposite;
  final bool activateTemporalStorm;
  final bool spawnOptimizerFragment;
}

final class SurvivalWaveDirector {
  SurvivalWaveDirector({int seed = 20260804}) : _random = math.Random(seed);

  final math.Random _random;

  SurvivalMilestonePlan milestonesBetween({
    required int previousSecond,
    required int currentSecond,
  }) {
    final previous = math.max(0, previousSecond);
    final current = math.max(previous, currentSecond);
    final crossedComposite = current ~/ 180 > previous ~/ 180;
    final crossedElite = current ~/ 90 > previous ~/ 90;
    final crossedTemporalStorm = previous < 300 && current >= 300;
    final crossedOptimizerFragment = previous < 450 && current >= 450;
    return SurvivalMilestonePlan(
      spawnElite:
          crossedElite &&
          !crossedComposite &&
          !crossedOptimizerFragment &&
          !crossedTemporalStorm,
      spawnComposite: crossedComposite && !crossedOptimizerFragment,
      activateTemporalStorm: crossedTemporalStorm,
      spawnOptimizerFragment: crossedOptimizerFragment,
    );
  }

  SurvivalWavePlan planForSecond({
    required int second,
    required double integrityRatio,
    required double recentKillsPerSecond,
  }) {
    final safeSecond = math.max(0, second);
    final endlessTier = safeSecond < 600 ? 0 : 1 + (safeSecond - 600) ~/ 60;
    final pressure = 2.2 + safeSecond / 22 + endlessTier * 1.8;
    final recoveryFactor = integrityRatio < 0.4 ? 0.72 : 1.0;
    final masteryFactor = recentKillsPerSecond > 1.8 ? 1.18 : 1.0;
    final budget = pressure * recoveryFactor * masteryFactor;
    final composite = safeSecond > 0 && safeSecond % 180 == 0;
    final elite = !composite && safeSecond > 0 && safeSecond % 90 == 0;

    var remaining = composite ? math.max(0, budget - 7) : budget;
    final phaseHoundLimit = safeSecond < 120
        ? 0
        : safeSecond < 300
        ? 1
        : math.min(3, 2 + endlessTier ~/ 3);
    final phaseHounds = math.min(phaseHoundLimit, (remaining / 4).floor());
    remaining -= phaseHounds * 4;
    final sentinelLimit = safeSecond < 45
        ? 0
        : 1 + safeSecond ~/ 150 + endlessTier ~/ 2;
    final sentinels = math.min(sentinelLimit, (remaining / 3).floor());
    remaining -= sentinels * 3;
    final crawlers = math.max(1, remaining.floor());
    return SurvivalWavePlan(
      crawlers: crawlers,
      sentinels: sentinels,
      phaseHounds: phaseHounds,
      spawnElite: elite,
      spawnComposite: composite,
      threatBudget: budget,
      endlessTier: endlessTier,
    );
  }

  SurvivalSpawnPoint chooseSpawnPoint({
    required double width,
    required double height,
    required double playerX,
    required double playerY,
    required double velocityX,
    required double velocityY,
    double margin = 48,
  }) {
    final predictedX = playerX + velocityX * 0.8;
    final predictedY = playerY + velocityY * 0.8;
    final candidates = <SurvivalSpawnPoint>[
      SurvivalSpawnPoint(-margin, _random.nextDouble() * height),
      SurvivalSpawnPoint(width + margin, _random.nextDouble() * height),
      SurvivalSpawnPoint(_random.nextDouble() * width, -margin),
      SurvivalSpawnPoint(_random.nextDouble() * width, height + margin),
    ];
    candidates.sort((a, b) {
      final aDistance = _distanceSquared(a.x, a.y, predictedX, predictedY);
      final bDistance = _distanceSquared(b.x, b.y, predictedX, predictedY);
      return bDistance.compareTo(aDistance);
    });
    return candidates.first;
  }

  double _distanceSquared(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return dx * dx + dy * dy;
  }
}
