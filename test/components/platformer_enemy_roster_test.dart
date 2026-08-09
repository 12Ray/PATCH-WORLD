import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

void main() {
  test(
    'campaign roster contains fifteen unique concepts and three mid-bosses',
    () {
      const roster = PlatformerEnemyArchetype.values;

      expect(roster, hasLength(15));
      expect(roster.map((item) => item.displayName).toSet(), hasLength(15));
      expect(roster.where((item) => item.isMidBoss), hasLength(3));
    },
  );

  test(
    'roster includes player-like and concept-specific movement profiles',
    () {
      const roster = PlatformerEnemyArchetype.values;

      expect(
        roster.where(
          (item) => item.mobility == PlatformerEnemyMobility.grounded,
        ),
        isNotEmpty,
      );
      expect(
        roster.where((item) => item.mobility == PlatformerEnemyMobility.hopper),
        contains(PlatformerEnemyArchetype.checksumHopper),
      );
      expect(
        roster.where((item) => item.mobility == PlatformerEnemyMobility.flying),
        containsAll(<PlatformerEnemyArchetype>[
          PlatformerEnemyArchetype.echoBat,
          PlatformerEnemyArchetype.polarityDrone,
        ]),
      );
      expect(
        roster.where((item) => item.mobility == PlatformerEnemyMobility.turret),
        containsAll(<PlatformerEnemyArchetype>[
          PlatformerEnemyArchetype.pulseTurret,
          PlatformerEnemyArchetype.delaySniper,
          PlatformerEnemyArchetype.phaseMimic,
          PlatformerEnemyArchetype.shardLobber,
        ]),
      );
    },
  );

  test('campaign projectile identities are archetype-specific', () {
    final identities = PlatformerEnemyArchetype.values
        .map((item) => 'enemy.${item.name}.projectile')
        .toSet();

    expect(identities, hasLength(15));
    expect(identities, isNot(contains('enemy.sentinel.projectile')));
  });

  test(
    'Damage Lab enemies use telegraphed attacks instead of body contact',
    () {
      for (final archetype in PlatformerEnemyArchetype.values.take(5)) {
        final enemy = PlatformerEnemyComponent(
          archetype: archetype,
          position: Vector2.zero(),
          onDefeated: (_) {},
        );
        expect(enemy.dealsContactDamage, isFalse, reason: archetype.name);
      }
    },
  );
}
