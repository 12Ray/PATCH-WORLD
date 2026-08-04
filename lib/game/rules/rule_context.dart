enum RoomId {
  damageLab,
  temporalHall,
  collisionArchive,
  optimizerCore,
  survivalArena,
}

final class RuleContext {
  const RuleContext({required this.roomId, required this.selectedPatchIds});

  final RoomId roomId;
  final Set<String> selectedPatchIds;

  bool hasPatch(String patchId) => selectedPatchIds.contains(patchId);
}
