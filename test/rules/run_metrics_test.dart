import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/core/run_metrics.dart';

void main() {
  test('builds a deterministic run summary and score', () {
    final metrics = RunMetrics()
      ..update(61.2)
      ..recordDamage(2)
      ..recordDeath()
      ..recordOverflow()
      ..recordOverflow();

    final summary = metrics.finish(
      integrity: 3,
      selectedPatchIds: const <String>['patch.motion_tax'],
      endingId: 'preserve',
    );

    expect(summary.formattedTime, '1:01');
    expect(summary.deaths, 1);
    expect(summary.damageTaken, 2);
    expect(summary.overflowCount, 2);
    expect(summary.score, 1878);
    expect(summary.endingId, 'preserve');
  });

  test('no-death runs receive the completion bonus', () {
    final metrics = RunMetrics()..update(10);
    final summary = metrics.finish(
      integrity: 5,
      selectedPatchIds: const <String>[],
      endingId: 'purge',
    );
    expect(summary.score, 2430);
  });
}
