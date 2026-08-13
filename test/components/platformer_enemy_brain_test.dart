import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer/platformer_enemy_brain.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

void main() {
  test('all fifteen enemies own a unique signature brain action', () {
    final actions = <String>{};
    for (final archetype in PlatformerEnemyArchetype.values) {
      actions.add(PlatformerEnemyBrain.forArchetype(archetype.name).actionId);
    }
    expect(actions, hasLength(15));
  });

  test('all fifteen enemies expose five combat motions and three tiers', () {
    for (final archetype in PlatformerEnemyArchetype.values) {
      final pattern = PlatformerEnemyBrain.combatPattern(archetype.name);
      expect(pattern, hasLength(5), reason: archetype.name);
      expect(
        pattern.map((decision) => decision.actionId).toSet(),
        hasLength(5),
        reason: archetype.name,
      );
      expect(pattern[1].actionId, contains('.normal.'));
      expect(pattern[2].actionId, contains('.enhanced.'));
      expect(pattern[3].actionId, contains('.parryable.'));
      expect(pattern[4].actionId, contains('.special.'));
    }
  });

  test('context selection avoids repeating the two most recent actions', () {
    final pattern = PlatformerEnemyBrain.combatPattern('patchMite');
    final selection = PlatformerEnemyBrain.chooseAction(
      'patchMite',
      EnemyCombatContext(
        distance: 90,
        verticalDelta: 0,
        healthRatio: .35,
        playerGrounded: true,
        recentActionIds: <String>[pattern[0].actionId, pattern[1].actionId],
        decisionSeed: 4,
      ),
    );
    expect(<String>[
      pattern[0].actionId,
      pattern[1].actionId,
    ], isNot(contains(selection.decision.actionId)));
    expect(selection.motionFrame, inInclusiveRange(3, 7));
  });
}
