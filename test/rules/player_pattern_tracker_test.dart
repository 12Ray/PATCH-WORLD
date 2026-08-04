import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/systems/player_pattern_tracker.dart';

void main() {
  test('finds the dominant recent movement direction', () {
    final tracker = PlayerPatternTracker();
    for (var i = 0; i < 8; i += 1) {
      tracker.recordMovement(-1, 0);
    }
    for (var i = 0; i < 4; i += 1) {
      tracker.recordMovement(0, -1);
    }
    expect(tracker.snapshot.preferredDirection, DirectionBucket.left);
    expect(tracker.snapshot.confidence, closeTo(8 / 12, 0.001));
  });

  test('tracks average interval between attacks', () {
    final tracker = PlayerPatternTracker();
    tracker.update(0.5);
    tracker.recordAttack();
    tracker.update(1.5);
    tracker.recordAttack();
    expect(tracker.snapshot.averageAttackInterval, closeTo(1.5, 0.001));
  });
}
