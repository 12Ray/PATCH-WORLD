import 'package:patch_world/game/rules/rule_ids.dart';

final class PatchDefinition {
  const PatchDefinition({
    required this.id,
    required this.title,
    required this.fix,
    required this.sideEffect,
    required this.tactic,
    required this.riskLabel,
  });

  final String id;
  final String title;
  final String fix;
  final String sideEffect;
  final String tactic;
  final String riskLabel;
}

abstract final class PatchCatalog {
  static const PatchDefinition motionTax = PatchDefinition(
    id: RuleIds.motionTax,
    title: 'MOTION TAX',
    fix: 'Attacks deal damage normally.',
    sideEffect: 'Moving builds Heat. At maximum Heat, lose 1 Integrity.',
    tactic: 'Stop briefly to vent Heat quickly.',
    riskLabel: 'STABLE',
  );

  static const PatchDefinition retaliationEcho = PatchDefinition(
    id: RuleIds.retaliationEcho,
    title: 'RETALIATION ECHO',
    fix: 'Attacks deal damage normally.',
    sideEffect: 'Every fourth Pulse creates a delayed blast at its origin.',
    tactic: 'The blast can also damage enemies.',
    riskLabel: 'RISKY',
  );

  static const List<PatchDefinition> roomOneChoices = <PatchDefinition>[
    motionTax,
    retaliationEcho,
  ];

  static const PatchDefinition hostileTurbo = PatchDefinition(
    id: RuleIds.hostileTurbo,
    title: 'HOSTILE TURBO',
    fix: 'Time flows continuously again.',
    sideEffect: 'Enemies and projectiles move 20% faster.',
    tactic: 'Telegraphs stay readable, so position before each shot.',
    riskLabel: 'RISKY',
  );

  static const PatchDefinition frameBurst = PatchDefinition(
    id: RuleIds.frameBurst,
    title: 'FRAME BURST',
    fix: 'Time flows continuously again.',
    sideEffect: 'Every 5 seconds enemies surge for 0.6 seconds.',
    tactic: 'Move to safety during the frame warning.',
    riskLabel: 'CHAOTIC',
  );

  static const List<PatchDefinition> roomTwoChoices = <PatchDefinition>[
    hostileTurbo,
    frameBurst,
  ];
}

final class RunState {
  final List<String> _selectedPatchIds = <String>[];

  List<String> get selectedPatchIds =>
      List<String>.unmodifiable(_selectedPatchIds);

  bool hasPatch(String id) => _selectedPatchIds.contains(id);

  void selectPatch(String id) {
    if (!_selectedPatchIds.contains(id)) {
      _selectedPatchIds.add(id);
    }
  }

  void reset() => _selectedPatchIds.clear();
}

final class PatchSelectionRequest {
  const PatchSelectionRequest({required this.roomId, required this.choices});

  final String roomId;
  final List<PatchDefinition> choices;
}
