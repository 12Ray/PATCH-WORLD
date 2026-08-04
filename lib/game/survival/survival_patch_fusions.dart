import 'package:patch_world/game/rules/rule_ids.dart';

final class SurvivalFusionDefinition {
  const SurvivalFusionDefinition({
    required this.id,
    required this.firstPatchId,
    required this.secondPatchId,
  });

  final String id;
  final String firstPatchId;
  final String secondPatchId;

  String partnerOf(String patchId) =>
      patchId == firstPatchId ? secondPatchId : firstPatchId;
}

abstract final class SurvivalPatchFusions {
  static const String ghostVent = 'fusion.ghost_vent';
  static const String echoCascade = 'fusion.echo_cascade';
  static const String redline = 'fusion.redline';

  static const List<String> all = <String>[ghostVent, echoCascade, redline];

  static const List<SurvivalFusionDefinition> definitions =
      <SurvivalFusionDefinition>[
        SurvivalFusionDefinition(
          id: ghostVent,
          firstPatchId: RuleIds.motionTax,
          secondPatchId: RuleIds.phaseLeak,
        ),
        SurvivalFusionDefinition(
          id: echoCascade,
          firstPatchId: RuleIds.retaliationEcho,
          secondPatchId: RuleIds.duplicateFault,
        ),
        SurvivalFusionDefinition(
          id: redline,
          firstPatchId: RuleIds.hostileTurbo,
          secondPatchId: RuleIds.frameBurst,
        ),
      ];

  static List<String> activeFor(Map<String, int> patchTiers) => <String>[
    if (_hasPair(patchTiers, RuleIds.motionTax, RuleIds.phaseLeak)) ghostVent,
    if (_hasPair(patchTiers, RuleIds.retaliationEcho, RuleIds.duplicateFault))
      echoCascade,
    if (_hasPair(patchTiers, RuleIds.hostileTurbo, RuleIds.frameBurst)) redline,
  ];

  static List<String> newlyUnlocked({
    required Iterable<String> before,
    required Iterable<String> after,
  }) {
    final previous = before.toSet();
    return after.where((fusionId) => !previous.contains(fusionId)).toList();
  }

  static SurvivalFusionDefinition? definitionForPatch(String patchId) {
    for (final definition in definitions) {
      if (definition.firstPatchId == patchId ||
          definition.secondPatchId == patchId) {
        return definition;
      }
    }
    return null;
  }

  static bool willUnlockAfterUpgrade({
    required String patchId,
    required int nextTier,
    required Map<String, int> patchTiers,
  }) {
    final definition = definitionForPatch(patchId);
    if (definition == null || activeFor(patchTiers).contains(definition.id)) {
      return false;
    }
    final upgraded = Map<String, int>.of(patchTiers)..[patchId] = nextTier;
    return activeFor(upgraded).contains(definition.id);
  }

  static bool _hasPair(
    Map<String, int> patchTiers,
    String first,
    String second,
  ) => (patchTiers[first] ?? 0) >= 2 && (patchTiers[second] ?? 0) >= 2;
}
