import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/survival/wave_director.dart';

void main() {
  test('director introduces sentinels and elites without legacy bosses', () {
    final director = SurvivalWaveDirector(seed: 7);
    final opening = director.planForSecond(
      second: 10,
      integrityRatio: 1,
      recentKillsPerSecond: 0.5,
    );
    final elite = director.planForSecond(
      second: 90,
      integrityRatio: 1,
      recentKillsPerSecond: 2,
    );
    final boss = director.planForSecond(
      second: 180,
      integrityRatio: 1,
      recentKillsPerSecond: 2,
    );

    expect(opening.sentinels, 0);
    expect(opening.crawlers, greaterThanOrEqualTo(4));
    expect(elite.sentinels, greaterThan(0));
    expect(elite.spawnElite, isTrue);
    expect(boss.spawnComposite, isFalse);
    expect(boss.threatBudget, greaterThan(elite.threatBudget));
  });

  test(
    'spawn point stays outside the arena and away from predicted travel',
    () {
      final director = SurvivalWaveDirector(seed: 42);
      final point = director.chooseSpawnPoint(
        width: 960,
        height: 540,
        playerX: 480,
        playerY: 270,
        velocityX: 160,
        velocityY: 0,
      );

      expect(point.isOutside(960, 540), isTrue);
      final predictedX = 480 + 160 * 0.8;
      final dx = point.x - predictedX;
      final dy = point.y - 270;
      expect(dx * dx + dy * dy, greaterThan(160 * 160));
    },
  );

  test('expanded arena spawns stay in the nearby engagement band', () {
    final director = SurvivalWaveDirector(seed: 42);
    final point = director.chooseEngagementSpawnPoint(
      width: 2880,
      height: 1620,
      playerX: 1440,
      playerY: 810,
    );

    expect(point.isOutside(2880, 1620), isFalse);
    final dx = point.x - 1440;
    final dy = point.y - 810;
    final distance = math.sqrt(dx * dx + dy * dy);
    expect(distance, inInclusiveRange(540, 720));
  });

  test('milestones cannot be skipped by a coarse wave interval', () {
    final director = SurvivalWaveDirector();
    final elite = director.milestonesBetween(
      previousSecond: 88,
      currentSecond: 92,
    );
    final composite = director.milestonesBetween(
      previousSecond: 176,
      currentSecond: 180,
    );
    final storm = director.milestonesBetween(
      previousSecond: 298,
      currentSecond: 302,
    );
    final optimizer = director.milestonesBetween(
      previousSecond: 448,
      currentSecond: 452,
    );

    expect(elite.spawnElite, isTrue);
    expect(elite.spawnComposite, isFalse);
    expect(composite.spawnElite, isTrue);
    expect(composite.spawnComposite, isFalse);
    expect(storm.activateTemporalStorm, isFalse);
    expect(storm.spawnElite, isFalse);
    expect(optimizer.spawnOptimizerFragment, isFalse);
    expect(optimizer.spawnElite, isTrue);
  });

  test(
    'endless scaling starts after twenty minutes and tiers every minute',
    () {
      final director = SurvivalWaveDirector(seed: 9);
      final twentyMinutes = director.planForSecond(
        second: 1200,
        integrityRatio: 1,
        recentKillsPerSecond: 1,
      );
      final twentyTwoMinutes = director.planForSecond(
        second: 1320,
        integrityRatio: 1,
        recentKillsPerSecond: 1,
      );

      expect(twentyMinutes.endlessTier, 1);
      expect(twentyTwoMinutes.endlessTier, 3);
      expect(
        twentyTwoMinutes.threatBudget,
        greaterThan(twentyMinutes.threatBudget),
      );
    },
  );

  test('phase hounds join after two minutes without removing all crawlers', () {
    final director = SurvivalWaveDirector(seed: 12);
    final before = director.planForSecond(
      second: 119,
      integrityRatio: 1,
      recentKillsPerSecond: 1,
    );
    final first = director.planForSecond(
      second: 120,
      integrityRatio: 1,
      recentKillsPerSecond: 1,
    );
    final storm = director.planForSecond(
      second: 300,
      integrityRatio: 1,
      recentKillsPerSecond: 1,
    );
    final recovering = director.planForSecond(
      second: 120,
      integrityRatio: 0.3,
      recentKillsPerSecond: 1,
    );

    expect(before.phaseHounds, 0);
    expect(first.phaseHounds, 1);
    expect(storm.phaseHounds, 2);
    expect(recovering.crawlers, greaterThanOrEqualTo(1));
  });
}
