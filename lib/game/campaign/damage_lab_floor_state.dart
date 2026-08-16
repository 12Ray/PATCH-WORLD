/// Persistent progress for the four-cell Damage Lab floor.
///
/// The state belongs to the run rather than the room component, so restarting
/// after a defeat keeps completed encounters and optional QA records while the
/// currently active encounter is rebuilt.
final class DamageLabFloorState {
  final Set<int> clearedEncounterIds = <int>{};
  final Set<int> collectedRecordIds = <int>{};
  final Set<String> claimedSecretRewardIds = <String>{};
  final Set<int> claimedBuildRewardIds = <int>{};

  bool bossDefeated = false;
  bool questRewardClaimed = false;
  bool bossRewardClaimed = false;
  bool patchApplied = false;
  bool repairStationUsed = false;
  bool loadoutEventResolved = false;

  int get clearedEncounterCount => clearedEncounterIds.length;
  int get collectedRecordCount => collectedRecordIds.length;
  bool get questComplete => collectedRecordIds.length >= 3;
  bool get allEncountersCleared => clearedEncounterIds.length >= 3;

  int get resumeCell {
    if (bossDefeated || allEncountersCleared) return 3;
    for (var index = 0; index < 3; index += 1) {
      if (!clearedEncounterIds.contains(index)) return index;
    }
    return 0;
  }

  void reset() {
    clearedEncounterIds.clear();
    collectedRecordIds.clear();
    claimedSecretRewardIds.clear();
    claimedBuildRewardIds.clear();
    bossDefeated = false;
    questRewardClaimed = false;
    bossRewardClaimed = false;
    patchApplied = false;
    repairStationUsed = false;
    loadoutEventResolved = false;
  }
}
