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

  test('every phase deck exposes at least two representative patterns', () {
    final knownIds = OverflowWardenAttackCatalog.all
        .map((pattern) => pattern.id)
        .toSet();

    for (final phase in <int>[1, 2, 3]) {
      final deck = OverflowWardenAttackCatalog.deckForPhase(phase);
      expect(deck.toSet(), hasLength(deck.length));
      expect(deck.length, greaterThanOrEqualTo(2));
      expect(deck.every(knownIds.contains), isTrue);
    }
    expect(
      OverflowWardenAttackCatalog.deckForPhase(3).length,
      greaterThan(OverflowWardenAttackCatalog.deckForPhase(1).length),
    );
  });

  test('Warden attack timing drives telegraph active and recovery frames', () {
    final action = OverflowWardenAttackCatalog.byId(
      'shieldCharge',
    ).createTimeline();

    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: action.phase,
        phaseProgress: 0,
        idleFrame: 3,
      ),
      4,
    );
    action.advance(.63);
    expect(action.phase, EnemyActionPhase.active);
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: action.phase,
        phaseProgress: action.phaseProgress,
        idleFrame: 3,
      ),
      5,
    );
    action.advance(.28);
    expect(action.phase, EnemyActionPhase.recovery);
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: action.phase,
        phaseProgress: action.phaseProgress,
        idleFrame: 3,
      ),
      inInclusiveRange(6, 7),
    );
  });

  test('idle health-phase silhouette is restored after recovery', () {
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: null,
        phaseProgress: 0,
        idleFrame: 3,
      ),
      3,
    );
    expect(
      resolveOverflowWardenAttackFrame(
        actionPhase: EnemyActionPhase.completed,
        phaseProgress: 0,
        idleFrame: 1,
      ),
      1,
    );
  });

  test('phase gate requires two different completed patterns', () {
    final gate = OverflowWardenPhaseAttackGate();

    gate.record('shieldSlam');
    gate.record('shieldSlam');
    expect(gate.completedDistinctAttackCount, 1);
    expect(gate.isReady, isFalse);

    gate.record('shieldCharge');
    expect(gate.completedAttackIds, <String>{'shieldSlam', 'shieldCharge'});
    expect(gate.isReady, isTrue);

    gate.reset();
    expect(gate.completedAttackIds, isEmpty);
    expect(gate.isReady, isFalse);
  });

  test('shield charge travels 320 units and respects arena walls', () {
    expect(
      resolveOverflowWardenChargeEndX(
        startX: 1040,
        facing: -1,
        arenaWidth: 1440,
        bodyWidth: 76,
      ),
      720,
    );
    expect(
      resolveOverflowWardenChargeEndX(
        startX: 1280,
        facing: 1,
        arenaWidth: 1440,
        bodyWidth: 76,
      ),
      1383,
    );
    expect(
      resolveOverflowWardenChargeEndX(
        startX: 80,
        facing: -1,
        arenaWidth: 1440,
        bodyWidth: 76,
      ),
      57,
    );
    expect(
      resolveOverflowWardenChargeEndX(
        startX: 1040,
        facing: 1,
        arenaWidth: 1440,
        arenaLeft: 152,
        arenaRight: 1288,
        bodyWidth: 76,
      ),
      1231,
    );
    expect(
      resolveOverflowWardenChargeEndX(
        startX: 300,
        facing: -1,
        arenaWidth: 1440,
        arenaLeft: 152,
        arenaRight: 1288,
        bodyWidth: 76,
      ),
      209,
    );
  });
}
