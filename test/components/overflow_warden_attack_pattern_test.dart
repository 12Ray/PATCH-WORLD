import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/overflow_warden_attack_pattern.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_action_timeline.dart';

void main() {
  test('Warden owns five distinct spatial attacks and counterplays', () {
    final patterns = OverflowWardenAttackCatalog.all;

    expect(patterns, hasLength(5));
    expect(patterns.map((pattern) => pattern.id).toSet(), hasLength(5));
    expect(
      patterns.map((pattern) => pattern.attackSpace).toSet(),
      hasLength(5),
    );
    expect(
      patterns.map((pattern) => pattern.counterplay).toSet(),
      hasLength(5),
    );
    expect(
      patterns.map((pattern) => pattern.fingerprint).toSet(),
      hasLength(5),
    );
  });

  test('Warden attack timing drives telegraph active and recovery frames', () {
    final action = OverflowWardenAttackCatalog.byId(
      'shieldCharge',
    ).createTimeline();

    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: action.phase,
        visualClock: 0,
        idleFrame: 3,
      ),
      4,
    );
    action.advance(.63);
    expect(action.phase, EnemyActionPhase.active);
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: action.phase,
        visualClock: .2,
        idleFrame: 3,
      ),
      5,
    );
    action.advance(.28);
    expect(action.phase, EnemyActionPhase.recovery);
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: action.phase,
        visualClock: .2,
        idleFrame: 3,
      ),
      inInclusiveRange(6, 7),
    );
  });

  test('idle health-phase silhouette is restored after recovery', () {
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: null,
        visualClock: 2,
        idleFrame: 3,
      ),
      3,
    );
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: EnemyActionPhase.completed,
        visualClock: 2,
        idleFrame: 1,
      ),
      1,
    );
  });
}
