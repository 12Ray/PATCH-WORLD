import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/survival/survival_phase_eleven.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

void main() {
  test('four corners map to four distinct Nexus regions', () {
    expect(
      SurvivalNexusRegionSpec.forPosition(Vector2(300, 300)),
      SurvivalNexusRegion.dataFoundry,
    );
    expect(
      SurvivalNexusRegionSpec.forPosition(Vector2(2580, 300)),
      SurvivalNexusRegion.temporalBreach,
    );
    expect(
      SurvivalNexusRegionSpec.forPosition(Vector2(300, 1320)),
      SurvivalNexusRegion.collisionGraveyard,
    );
    expect(
      SurvivalNexusRegionSpec.forPosition(Vector2(2580, 1320)),
      SurvivalNexusRegion.reactorYard,
    );
    expect(SurvivalNexusRegionSpec.forPosition(Vector2(1440, 810)), isNull);
  });

  test('event schedule rotates all four region objectives between bosses', () {
    final firstWindow = SurvivalPhaseElevenDirector.eventsBetween(
      previousSecond: 0,
      currentSecond: 299,
    );
    expect(firstWindow.map((event) => event.startSecond), <int>[60, 180]);
    expect(firstWindow.map((event) => event.kind), <SurvivalRegionEventKind>[
      SurvivalRegionEventKind.relayRepair,
      SurvivalRegionEventKind.escort,
    ]);
    expect(
      SurvivalPhaseElevenDirector.eventSchedule
          .take(4)
          .map((event) => event.region)
          .toSet(),
      SurvivalNexusRegion.values.toSet(),
    );
  });

  test('boss milestones occur at five-minute gates and end at Nexus Core', () {
    final bosses = SurvivalPhaseElevenDirector.bossesBetween(
      previousSecond: 0,
      currentSecond: 1200,
    );
    expect(bosses.map((boss) => boss.second), <int>[300, 600, 900, 1200]);
    expect(bosses.last.kind, SurvivalNexusBossKind.nexusCore);
  });

  test('every boss phase owns three unique attack pattern identifiers', () {
    final allIds = <String>{};
    for (final boss in SurvivalNexusBossKind.values) {
      for (var phase = 1; phase <= boss.phaseCount; phase += 1) {
        final patterns = boss.patternIdsForPhase(phase);
        expect(patterns, hasLength(3));
        expect(patterns.toSet(), hasLength(3));
        expect(allIds.intersection(patterns.toSet()), isEmpty);
        allIds.addAll(patterns);
      }
    }
  });

  test(
    'run snapshot preserves region, event, and boss completion telemetry',
    () {
      final run = SurvivalRunState();
      for (final region in SurvivalNexusRegion.values.take(3)) {
        expect(run.recordRegionVisited(region), isTrue);
        expect(run.recordRegionVisited(region), isFalse);
      }
      run.recordRegionEventStarted(SurvivalRegionEventKind.relayRepair);
      run.recordRegionEventCompleted(SurvivalRegionEventKind.relayRepair);
      run.recordRegionEventStarted(SurvivalRegionEventKind.escort);
      run.recordRegionEventFailed(SurvivalRegionEventKind.escort);
      run.recordSurvivalBossDefeated(finalBoss: false);

      final result = SurvivalResultSnapshot.fromRun(
        run,
        isBestScore: false,
        isBestTime: false,
      );
      expect(result.visitedRegionCount, 3);
      expect(result.regionEventsStarted, 2);
      expect(result.regionEventsCompleted, 1);
      expect(result.regionEventsFailed, 1);
      expect(result.survivalBossesDefeated, 1);
      expect(result.finalBossDefeated, isFalse);
    },
  );
}
