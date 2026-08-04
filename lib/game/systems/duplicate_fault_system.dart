import 'package:flame/components.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/combat_system.dart';

enum DuplicateArchetype { crawler, sentinel, optimizer }

abstract interface class DuplicateSource implements CombatTarget {
  Vector2 get duplicatePosition;
  DuplicateArchetype get duplicateArchetype;
  bool claimDuplicate();
}

typedef SpawnDuplicate =
    void Function({
      required DuplicateArchetype archetype,
      required Vector2 position,
      required String sourceEntityId,
    });

final class DuplicateFaultSystem {
  DuplicateFaultSystem({required this.runState, required this.spawnDuplicate});

  final RunState runState;
  final SpawnDuplicate spawnDuplicate;
  bool get isActive => runState.hasPatch(RuleIds.duplicateFault);

  void onPlayerDamageCommitted(CombatTarget target) {
    if (!isActive || target is! DuplicateSource || !target.claimDuplicate()) {
      return;
    }
    spawnDuplicate(
      archetype: target.duplicateArchetype,
      position: target.duplicatePosition.clone(),
      sourceEntityId: target.entityId,
    );
  }
}
