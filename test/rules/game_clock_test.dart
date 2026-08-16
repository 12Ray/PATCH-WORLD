import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/game_clock.dart';

void main() {
  test('freezes simulation while player status time continues', () {
    final clock = GameClock();
    clock.beginFrame(
      realDt: 1 / 60,
      simulationAdvances: false,
      enemySpeedMultiplier: 1,
    );
    expect(clock.playerStatusDt, closeTo(1 / 60, 0.00001));
    expect(clock.simulationDt, 0);
    expect(clock.enemyDt, 0);
  });

  test('applies enemy multiplier only to enemy dt', () {
    final clock = GameClock();
    clock.beginFrame(
      realDt: 0.01,
      simulationAdvances: true,
      enemySpeedMultiplier: 2,
    );
    expect(clock.simulationDt, 0.01);
    expect(clock.enemyDt, 0.02);
    expect(clock.playerStatusDt, 0.01);
  });

  test('clamps abnormally large frame delta', () {
    final clock = GameClock();
    clock.beginFrame(
      realDt: 2,
      simulationAdvances: true,
      enemySpeedMultiplier: 1,
    );
    expect(clock.realDt, closeTo(1 / 15, 0.00001));
  });

  test('cinematic scale slows simulation without slowing status timers', () {
    final clock = GameClock();
    clock.beginFrame(
      realDt: 0.02,
      simulationAdvances: true,
      enemySpeedMultiplier: 1.5,
      simulationSpeedMultiplier: .25,
    );
    expect(clock.realDt, 0.02);
    expect(clock.playerStatusDt, 0.02);
    expect(clock.simulationDt, 0.005);
    expect(clock.enemyDt, 0.0075);
  });
}
