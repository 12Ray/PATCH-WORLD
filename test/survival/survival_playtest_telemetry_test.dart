import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/survival/survival_playtest_telemetry.dart';

void main() {
  test('pacing snapshot includes opening, between-event, and ending gaps', () {
    final telemetry = SurvivalPlaytestTelemetry()
      ..record(5, SurvivalMeaningfulEvent.kill)
      ..record(18, SurvivalMeaningfulEvent.patchInstalled);

    final snapshot = telemetry.snapshot(25);

    expect(snapshot.meaningfulEventCount, 2);
    expect(snapshot.longestQuietSeconds, 13);
    expect(snapshot.eventsPerMinute, closeTo(4.8, 0.001));
    expect(snapshot.hasPacingGap, isFalse);
  });

  test('pacing warning starts only after twenty seconds', () {
    final telemetry = SurvivalPlaytestTelemetry();

    expect(telemetry.snapshot(20).hasPacingGap, isFalse);
    expect(telemetry.snapshot(20.01).hasPacingGap, isTrue);
  });

  test(
    'session summary keeps five recent runs and breaks ties by patch id',
    () {
      final summary = SurvivalSessionSummary.fromPatchRuns(<Set<String>>[
        <String>{'patch.old'},
        <String>{'patch.beta'},
        <String>{'patch.alpha'},
        <String>{'patch.beta'},
        <String>{'patch.alpha'},
        <String>{'patch.gamma'},
      ]);

      expect(summary.runCount, 5);
      expect(summary.topPatchId, 'patch.alpha');
      expect(summary.topPatchSelectionRate, 0.4);
      expect(summary.hasSelectionBias, isFalse);
    },
  );

  test('selection bias requires five runs and more than eighty percent', () {
    final fiveOfFive = SurvivalSessionSummary.fromPatchRuns(
      List<Set<String>>.generate(5, (_) => <String>{'patch.motion_tax'}),
    );
    final fourOfFive = SurvivalSessionSummary.fromPatchRuns(<Set<String>>[
      <String>{'patch.motion_tax'},
      <String>{'patch.motion_tax'},
      <String>{'patch.motion_tax'},
      <String>{'patch.motion_tax'},
      <String>{'patch.frame_burst'},
    ]);

    expect(fiveOfFive.hasSelectionBias, isTrue);
    expect(fourOfFive.topPatchSelectionRate, 0.8);
    expect(fourOfFive.hasSelectionBias, isFalse);
  });
}
