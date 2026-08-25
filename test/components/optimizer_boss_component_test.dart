import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';

void main() {
  test('optimizer enters predict, perfect, then stability overflow', () {
    var perfectEntries = 0;
    final gate = OptimizerPatternGate()
      ..recordResolved(OptimizerAttackPattern.analysisRing)
      ..recordResolved(OptimizerAttackPattern.analysisCross)
      ..recordResolved(OptimizerAttackPattern.predictionTrail)
      ..recordResolved(OptimizerAttackPattern.predictionPincer);
    final boss = OptimizerBossComponent(
      position: Vector2.zero(),
      onPerfectStateEntered: () => perfectEntries += 1,
      onDefeated: () {},
      patternGate: gate,
    );
    boss.receiveDamage(7);
    expect(boss.phase, OptimizerPhase.predict);
    boss.receiveDamage(7);
    expect(boss.phase, OptimizerPhase.perfect);
    expect(perfectEntries, 1);
    for (var i = 0; i < 4; i += 1) {
      boss.receiveHealing(1);
    }
    expect(boss.stability.current, 150);
    expect(boss.phase, OptimizerPhase.overflow);
  });

  test('health floors hold until two unique phase patterns resolve', () {
    final gate = OptimizerPatternGate();
    final boss = OptimizerBossComponent(
      position: Vector2.zero(),
      onPerfectStateEntered: () {},
      onDefeated: () {},
      patternGate: gate,
    );

    boss.receiveDamage(99);
    expect(boss.health, 13);
    expect(boss.phase, OptimizerPhase.analyze);
    gate.recordResolved(OptimizerAttackPattern.analysisRing);
    boss.receiveDamage(1);
    expect(boss.phase, OptimizerPhase.analyze);
    gate.recordResolved(OptimizerAttackPattern.analysisCross);
    boss.receiveDamage(1);
    expect(boss.phase, OptimizerPhase.predict);

    boss.receiveDamage(99);
    expect(boss.health, 6);
    expect(boss.phase, OptimizerPhase.predict);
    gate.recordResolved(OptimizerAttackPattern.predictionTrail);
    boss.receiveDamage(1);
    expect(boss.phase, OptimizerPhase.predict);
    gate.recordResolved(OptimizerAttackPattern.predictionPincer);
    boss.receiveDamage(1);
    expect(boss.phase, OptimizerPhase.perfect);
  });

  test('each live phase cycles three deterministic identifiable patterns', () {
    for (final phase in <OptimizerPhase>[
      OptimizerPhase.analyze,
      OptimizerPhase.predict,
      OptimizerPhase.perfect,
    ]) {
      final deck = OptimizerAttackDeck();
      final firstCycle = <OptimizerAttackPattern>[
        for (var index = 0; index < 3; index += 1) deck.next(phase),
      ];

      expect(firstCycle.toSet(), hasLength(3));
      expect(firstCycle.every((pattern) => pattern.phase == phase), isTrue);
      expect(
        firstCycle.every(
          (pattern) => pattern.sourceId.startsWith('boss.optimizer.'),
        ),
        isTrue,
      );
      expect(deck.next(phase), firstCycle.first);

      deck.reset(phase);
      expect(deck.next(phase), firstCycle.first);
    }
  });

  test('overflow exposes the core before a three-second-plus outro ends', () {
    final phases = <OptimizerPhase>[];
    var coreExposures = 0;
    var defeats = 0;
    final gate = OptimizerPatternGate()
      ..recordResolved(OptimizerAttackPattern.analysisRing)
      ..recordResolved(OptimizerAttackPattern.analysisCross)
      ..recordResolved(OptimizerAttackPattern.predictionTrail)
      ..recordResolved(OptimizerAttackPattern.predictionPincer);
    final boss = OptimizerBossComponent(
      position: Vector2.zero(),
      onPerfectStateEntered: () {},
      onPhaseChanged: phases.add,
      onCoreExposed: () => coreExposures += 1,
      onDefeated: () => defeats += 1,
      patternGate: gate,
    );
    boss.receiveDamage(7);
    boss.receiveDamage(7);
    boss.receiveHealing(4);

    expect(boss.phase, OptimizerPhase.overflow);
    expect(OptimizerBossComponent.outroSeconds, greaterThanOrEqualTo(3));
    boss.update(OptimizerBossComponent.collapseSeconds - .01);
    expect(coreExposures, 0);
    expect(defeats, 0);

    boss.update(.02);
    expect(boss.isCoreExposed, isTrue);
    expect(coreExposures, 1);
    expect(defeats, 0);

    boss.update(
      OptimizerBossComponent.outroSeconds -
          OptimizerBossComponent.collapseSeconds -
          .03,
    );
    expect(defeats, 0);
    boss.update(.04);
    expect(boss.phase, OptimizerPhase.defeated);
    expect(defeats, 1);
    expect(phases.last, OptimizerPhase.defeated);
  });
}
