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

  static List<PatchDefinition> choicesForLevel(int level) {
    final start = ((level - 2) * 2) % all.length;
    return List<PatchDefinition>.generate(
      3,
      (index) => all[(start + index) % all.length],
      growable: false,
    );
  }

  static int riskTierFor(PatchDefinition patch) => switch (patch.riskLabel) {
    'STABLE' => 1,
    'RISKY' => 2,
    _ => 3,
  };
}
