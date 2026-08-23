/// Run-persistent progress shared by the later four-cell campaign chapters.
final class CampaignFloorState {
  final Set<int> clearedEncounterIds = <int>{};
  final Set<int> collectedRecordIds = <int>{};
  final Set<int> completedObjectiveIds = <int>{};
  final Set<String> claimedSecretRewardIds = <String>{};

  bool bossDefeated = false;
  bool questRewardClaimed = false;
  bool bossRewardClaimed = false;
  bool patchApplied = false;
  bool repairStationUsed = false;
  bool loadoutEventResolved = false;

  int get clearedEncounterCount => clearedEncounterIds.length;
  int get collectedRecordCount => collectedRecordIds.length;
  int get completedObjectiveCount => completedObjectiveIds.length;
  bool get questComplete => collectedRecordIds.length >= 3;
  bool get allEncountersCleared => clearedEncounterIds.length >= 3;
  bool get allObjectivesComplete => completedObjectiveIds.length >= 3;
  bool get allRoomsComplete =>
      List<int>.generate(3, (index) => index).every(isRoomComplete);

  bool isRoomComplete(int encounterId) =>
      clearedEncounterIds.contains(encounterId) &&
      completedObjectiveIds.contains(encounterId);

  int get resumeCell {
    if (bossDefeated || allRoomsComplete) return 3;
    for (var index = 0; index < 3; index += 1) {
      if (!isRoomComplete(index)) return index;
    }
    return 0;
  }

  void reset() {
    clearedEncounterIds.clear();
    collectedRecordIds.clear();
    completedObjectiveIds.clear();
    claimedSecretRewardIds.clear();
    bossDefeated = false;
    questRewardClaimed = false;
    bossRewardClaimed = false;
    patchApplied = false;
    repairStationUsed = false;
    loadoutEventResolved = false;
  }
}
