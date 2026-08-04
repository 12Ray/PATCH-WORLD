import 'package:patch_world/game/core/run_state.dart';

final class SurvivalUpgradeRequest {
  const SurvivalUpgradeRequest({required this.level, required this.choices});

  final int level;
  final List<PatchDefinition> choices;
}

abstract final class SurvivalUpgradeCatalog {
  static const List<PatchDefinition> all = <PatchDefinition>[
    PatchCatalog.motionTax,
    PatchCatalog.retaliationEcho,
    PatchCatalog.hostileTurbo,
    PatchCatalog.frameBurst,
    PatchCatalog.phaseLeak,
    PatchCatalog.duplicateFault,
  ];

  static List<PatchDefinition> choicesForLevel(
    int level, {
    Map<String, int> patchTiers = const <String, int>{},
  }) {
    final start = ((level - 2) * 2) % all.length;
    final choices = <PatchDefinition>[];
    for (
      var offset = 0;
      offset < all.length && choices.length < 3;
      offset += 1
    ) {
      final patch = all[(start + offset) % all.length];
      if ((patchTiers[patch.id] ?? 0) < 3) choices.add(patch);
    }
    return List<PatchDefinition>.unmodifiable(choices);
  }

  static List<PatchDefinition> reroutedChoicesForLevel({
    required int level,
    required List<PatchDefinition> currentChoices,
    Map<String, int> patchTiers = const <String, int>{},
  }) {
    final currentIds = currentChoices.map((patch) => patch.id).toSet();
    final start = (((level - 2) * 2) + 3) % all.length;
    final choices = <PatchDefinition>[];
    for (var offset = 0; offset < all.length; offset += 1) {
      final patch = all[(start + offset) % all.length];
      if ((patchTiers[patch.id] ?? 0) >= 3 || currentIds.contains(patch.id)) {
        continue;
      }
      choices.add(patch);
      if (choices.length == 3) break;
    }
    if (choices.isEmpty) {
      return List<PatchDefinition>.unmodifiable(currentChoices);
    }
    for (
      var offset = 0;
      offset < all.length && choices.length < 3;
      offset += 1
    ) {
      final patch = all[(start + offset) % all.length];
      if ((patchTiers[patch.id] ?? 0) >= 3 || choices.contains(patch)) {
        continue;
      }
      choices.add(patch);
    }
    return List<PatchDefinition>.unmodifiable(choices);
  }

  static int riskTierFor(PatchDefinition patch) => switch (patch.riskLabel) {
    'STABLE' => 1,
    'RISKY' => 2,
    _ => 3,
  };
}
