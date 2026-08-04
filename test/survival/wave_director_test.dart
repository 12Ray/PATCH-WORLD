import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/survival/wave_director.dart';

void main() {
  test('director introduces sentinels, elites, and the three-minute boss', () {
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
    expect(elite.sentinels, greaterThan(0));
    expect(elite.spawnElite, isTrue);
    expect(boss.spawnComposite, isTrue);
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

    expect(elite.spawnElite, isTrue);
    expect(elite.spawnComposite, isFalse);
    expect(composite.spawnElite, isFalse);
    expect(composite.spawnComposite, isTrue);
  });
}
