import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';

void main() {
  test('later campaign floor progress preserves cells and records', () {
    final state = CampaignFloorState();
    state.clearedEncounterIds.addAll(<int>{0, 1});
    state.collectedRecordIds.addAll(<int>{0, 1, 2});

    expect(state.resumeCell, 2);
    expect(state.questComplete, isTrue);
    state.clearedEncounterIds.add(2);
    expect(state.resumeCell, 3);

    state.reset();
    expect(state.resumeCell, 0);
    expect(state.questComplete, isFalse);
  });
}
