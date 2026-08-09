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
}
