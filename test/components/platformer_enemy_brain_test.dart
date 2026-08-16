import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
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
        playerWeapon: PlayerWeapon.sword,
        nearbyAllies: 0,
        activeAllyAttackers: 0,
        formationSlot: 0,
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

  test('enemy action selection answers each starting weapon differently', () {
    EnemyBrainSelection select(PlayerWeapon weapon) =>
        PlatformerEnemyBrain.chooseAction(
          'patchMite',
          EnemyCombatContext(
            distance: 215,
            verticalDelta: 80,
            healthRatio: .8,
            playerGrounded: false,
            playerWeapon: weapon,
            nearbyAllies: 0,
            activeAllyAttackers: 0,
            formationSlot: 0,
            recentActionIds: const <String>[],
            decisionSeed: 0,
          ),
        );

    expect(
      select(PlayerWeapon.sword).decision.actionId,
      contains('.enhanced.'),
    );
    expect(
      select(PlayerWeapon.gauntlet).decision.actionId,
      contains('.parryable.'),
    );
    expect(select(PlayerWeapon.gun).decision.actionId, contains('.normal.'));
  });

  test(
    'a second attacker selects a cover pattern instead of body-stacking',
    () {
      EnemyBrainSelection select(int activeAllyAttackers) =>
          PlatformerEnemyBrain.chooseAction(
            'patchMite',
            EnemyCombatContext(
              distance: 90,
              verticalDelta: 0,
              healthRatio: .8,
              playerGrounded: true,
              playerWeapon: PlayerWeapon.sword,
              nearbyAllies: 3,
              activeAllyAttackers: activeAllyAttackers,
              formationSlot: 0,
              recentActionIds: const <String>[],
              decisionSeed: 0,
            ),
          );

      expect(select(0).decision.actionId, 'patchMite.bite');
      expect(select(1).decision.actionId, contains('.special.'));
    },
  );
}
