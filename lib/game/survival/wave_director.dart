import 'dart:math' as math;

import 'package:patch_world/game/survival/survival_balance.dart';

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
    final crossedElite = SurvivalBalanceCurve.crossedEliteBetween(
      previousSecond: previous,
      currentSecond: current,
    );
    return SurvivalMilestonePlan(
      spawnElite: crossedElite,
      spawnComposite: false,
      activateTemporalStorm: false,
      spawnOptimizerFragment: false,
    );
  }

  SurvivalWavePlan planForSecond({
    required int second,
    required double integrityRatio,
    required double recentKillsPerSecond,
  }) {
    final safeSecond = math.max(0, second);
    final profile = SurvivalBalanceCurve.profileForSecond(safeSecond);
    final endlessTier = profile.endlessTier;
    final pressure = profile.threatPressure;
    final recoveryFactor = integrityRatio < 0.4 ? 0.72 : 1.0;
    final masteryFactor = recentKillsPerSecond > 1.8 ? 1.18 : 1.0;
    final budget = pressure * recoveryFactor * masteryFactor;
    final elite = SurvivalBalanceCurve.crossedEliteBetween(
      previousSecond: safeSecond - 1,
      currentSecond: safeSecond,
    );

    var remaining = budget;
    final phaseHoundLimit = safeSecond < 120 ? 0 : profile.phaseHoundCap;
    final phaseHounds = math.min(phaseHoundLimit, (remaining / 4).floor());
    remaining -= phaseHounds * 4;
    final sentinelLimit = safeSecond < 45 ? 0 : profile.sentinelCap;
    final sentinels = math.min(sentinelLimit, (remaining / 3).floor());
    remaining -= sentinels * 3;
    final crawlers = math.max(1, remaining.floor());
    return SurvivalWavePlan(
      crawlers: crawlers,
      sentinels: sentinels,
      phaseHounds: phaseHounds,
      spawnElite: elite,
      spawnComposite: false,
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

  /// Picks an in-world spawn just beyond the normal camera view.
  ///
  /// The original edge spawn works for a single-screen arena, but makes an
  /// expanded Nexus feel empty because enemies spend too long crossing the
  /// world. This engagement band keeps the warning distance while returning
  /// enemies to combat quickly.
  SurvivalSpawnPoint chooseEngagementSpawnPoint({
    required double width,
    required double height,
    required double playerX,
    required double playerY,
    double minimumDistance = 540,
    double maximumDistance = 720,
    double inset = 72,
  }) {
    final safeMinimum = math.max(0, minimumDistance);
    final safeMaximum = math.max(safeMinimum, maximumDistance);
    final candidates = <SurvivalSpawnPoint>[];
    for (var index = 0; index < 16; index += 1) {
      final angle = _random.nextDouble() * math.pi * 2;
      final radius =
          safeMinimum + _random.nextDouble() * (safeMaximum - safeMinimum);
      candidates.add(
        SurvivalSpawnPoint(
          (playerX + math.cos(angle) * radius)
              .clamp(inset, width - inset)
              .toDouble(),
          (playerY + math.sin(angle) * radius)
              .clamp(inset, height - inset)
              .toDouble(),
        ),
      );
    }
    final minimumSquared = safeMinimum * safeMinimum;
    for (final candidate in candidates) {
      if (_distanceSquared(candidate.x, candidate.y, playerX, playerY) >=
          minimumSquared) {
        return candidate;
      }
    }
    candidates.sort((a, b) {
      final aDistance = _distanceSquared(a.x, a.y, playerX, playerY);
      final bDistance = _distanceSquared(b.x, b.y, playerX, playerY);
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
