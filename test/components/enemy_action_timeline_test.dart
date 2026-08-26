import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_action_timeline.dart';

void main() {
  test('enemy action advances through telegraph active and recovery', () {
    final action = EnemyActionTimeline(
      id: 'test.attack',
      telegraphSeconds: 0.3,
      activeSeconds: 0.2,
      recoverySeconds: 0.5,
    );

    expect(action.phase, EnemyActionPhase.telegraph);
    expect(action.advance(0.29).enteredActive, isFalse);

    final activeTick = action.advance(0.01);
    expect(activeTick.enteredActive, isTrue);
    expect(action.isDamaging, isTrue);

    final recoveryTick = action.advance(0.2);
    expect(recoveryTick.enteredRecovery, isTrue);
    expect(action.isDamaging, isFalse);

    expect(action.advance(0.5).completed, isTrue);
    expect(action.isComplete, isTrue);
  });

  test('frozen and invalid delta do not advance enemy action', () {
    final action = EnemyActionTimeline(
      id: 'test.freeze',
      telegraphSeconds: 0.4,
      activeSeconds: 0.1,
      recoverySeconds: 0.2,
    );

    action.advance(0);
    action.advance(-1);

    expect(action.elapsed, 0);
    expect(action.phase, EnemyActionPhase.telegraph);
  });

  test('large delta reports active boundary when it lands in recovery', () {
    final action = EnemyActionTimeline(
      id: 'test.skip-to-recovery',
      telegraphSeconds: 0.3,
      activeSeconds: 0.2,
      recoverySeconds: 0.5,
    );

    final tick = action.advance(0.75);

    expect(action.phase, EnemyActionPhase.recovery);
    expect(tick.enteredActive, isTrue);
    expect(tick.enteredRecovery, isTrue);
    expect(tick.completed, isFalse);
  });

  test('large delta reports crossed boundaries when action completes', () {
    final action = EnemyActionTimeline(
      id: 'test.skip-to-completed',
      telegraphSeconds: 0.3,
      activeSeconds: 0.2,
      recoverySeconds: 0.5,
    );

    final tick = action.advance(1.5);

    expect(action.phase, EnemyActionPhase.completed);
    expect(tick.enteredActive, isTrue);
    expect(tick.enteredRecovery, isTrue);
    expect(tick.completed, isTrue);
  });

  test('phase progress resets at boundaries and advances one way', () {
    final action = EnemyActionTimeline(
      id: 'paced',
      telegraphSeconds: .5,
      activeSeconds: .2,
      recoverySeconds: .4,
    );

    action.advance(.25);
    expect(action.phaseProgress, closeTo(.5, .0001));
    action.advance(.25);
    expect(action.phase, EnemyActionPhase.active);
    expect(action.phaseProgress, closeTo(0, .0001));
    action.advance(.2);
    expect(action.phase, EnemyActionPhase.recovery);
    expect(action.phaseProgress, closeTo(0, .0001));
    action.advance(.3);
    expect(action.phaseProgress, closeTo(.75, .0001));
  });
}
