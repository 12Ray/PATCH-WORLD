import 'dart:math' as math;

final class SurvivalWavePlan {
  const SurvivalWavePlan({
    required this.crawlers,
    required this.sentinels,
    required this.spawnElite,
    required this.spawnComposite,
    required this.threatBudget,
  });

  final int crawlers;
  final int sentinels;
  final bool spawnElite;
  final bool spawnComposite;
  final double threatBudget;
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
  });

  final bool spawnElite;
  final bool spawnComposite;
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
    return SurvivalMilestonePlan(
      spawnElite: crossedElite && !crossedComposite,
      spawnComposite: crossedComposite,
    );
  }

  SurvivalWavePlan planForSecond({
    required int second,
    required double integrityRatio,
    required double recentKillsPerSecond,
  }) {
    final safeSecond = math.max(0, second);
    final pressure = 2.2 + safeSecond / 22;
    final recoveryFactor = integrityRatio < 0.4 ? 0.72 : 1.0;
    final masteryFactor = recentKillsPerSecond > 1.8 ? 1.18 : 1.0;
    final budget = pressure * recoveryFactor * masteryFactor;
    final composite = safeSecond > 0 && safeSecond % 180 == 0;
    final elite = !composite && safeSecond > 0 && safeSecond % 90 == 0;

    var remaining = composite ? math.max(0, budget - 7) : budget;
    final sentinelLimit = safeSecond < 45 ? 0 : 1 + safeSecond ~/ 150;
    final sentinels = math.min(sentinelLimit, (remaining / 3).floor());
    remaining -= sentinels * 3;
    final crawlers = math.max(1, remaining.floor());
    return SurvivalWavePlan(
      crawlers: crawlers,
      sentinels: sentinels,
      spawnElite: elite,
      spawnComposite: composite,
      threatBudget: budget,
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
