import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';

void main() {
  test('Damage Lab progress resumes at the first uncleared combat cell', () {
    final progress = DamageLabFloorState();
    expect(progress.resumeCell, 0);

    progress.clearedEncounterIds.add(0);
    progress.collectedRecordIds.addAll(<int>{0, 2});
    progress.claimedBuildRewardIds.add(0);
    expect(progress.resumeCell, 1);
    expect(progress.collectedRecordCount, 2);

    progress.clearedEncounterIds.addAll(<int>{1, 2});
    expect(progress.allEncountersCleared, isTrue);
    expect(progress.resumeCell, 3);

    progress.reset();
    expect(progress.clearedEncounterIds, isEmpty);
    expect(progress.collectedRecordIds, isEmpty);
    expect(progress.claimedBuildRewardIds, isEmpty);
    expect(progress.resumeCell, 0);
  });
}
