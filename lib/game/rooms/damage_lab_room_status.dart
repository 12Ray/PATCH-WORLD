abstract interface class DamageLabRoomStatus {
  int get currentCellNumber;
  int get clearedEncounterCount;
  int get qaRecordCount;
  bool get isCompleted;
  int? get bossHealth;
  int? get bossMaxHealth;
  String? get bossPhaseKey;
}
