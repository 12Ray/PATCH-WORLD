import 'package:patch_world/game/rules/rule_ids.dart';

abstract final class SurvivalPatchFusions {
  static const String ghostVent = 'fusion.ghost_vent';
  static const String echoCascade = 'fusion.echo_cascade';
  static const String redline = 'fusion.redline';

  static const List<String> all = <String>[ghostVent, echoCascade, redline];

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

  static bool _hasPair(
    Map<String, int> patchTiers,
    String first,
    String second,
  ) => (patchTiers[first] ?? 0) >= 2 && (patchTiers[second] ?? 0) >= 2;
}
