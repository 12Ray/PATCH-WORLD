import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/survival/survival_items.dart';

void main() {
  test('catalog contains six items per weapon and six shared items', () {
    expect(SurvivalItemCatalog.all, hasLength(24));
    for (final weapon in PlayerWeapon.values) {
      expect(
        SurvivalItemCatalog.all.where(
          (definition) => definition.weapon == weapon,
        ),
        hasLength(6),
      );
    }
    expect(
      SurvivalItemCatalog.all.where((definition) => definition.weapon == null),
      hasLength(6),
    );
    expect(
      SurvivalItemCatalog.all.map((definition) => definition.id).toSet(),
      hasLength(24),
    );
  });

  test('campaign abilities expand choices instead of granting raw power', () {
    final locked = SurvivalItemCatalog.choices(
      weapon: PlayerWeapon.sword,
      owned: const <SurvivalItemId>{},
      unlockedAbilities: const <CampaignTraversalAbility>{},
      rewardIndex: 7,
    );
    expect(locked, isNot(contains(SurvivalItemId.wallScript)));
    expect(locked, isNot(contains(SurvivalItemId.ghostStep)));
    expect(locked, isNot(contains(SurvivalItemId.terrainCompiler)));

    final expandedPool = <SurvivalItemDefinition>[
      for (final definition in SurvivalItemCatalog.all)
        if (definition.supports(PlayerWeapon.sword) &&
            (definition.requiredAbility == null ||
                const <CampaignTraversalAbility>{
                  CampaignTraversalAbility.wallJump,
                  CampaignTraversalAbility.airDash,
                  CampaignTraversalAbility.terrainPulse,
                }.contains(definition.requiredAbility)))
          definition,
    ];
    expect(
      expandedPool.map((definition) => definition.id),
      containsAll(<SurvivalItemId>[
        SurvivalItemId.wallScript,
        SurvivalItemId.ghostStep,
        SurvivalItemId.terrainCompiler,
      ]),
    );
  });

  test('reward rotation never offers owned items or duplicates', () {
    final state = SurvivalItemBuildState();
    const abilities = <CampaignTraversalAbility>{
      CampaignTraversalAbility.wallJump,
      CampaignTraversalAbility.airDash,
      CampaignTraversalAbility.terrainPulse,
    };
    for (var reward = 0; reward < 8; reward += 1) {
      final choices = state.choices(
        weapon: PlayerWeapon.gun,
        unlockedAbilities: abilities,
      );
      expect(choices.toSet(), hasLength(choices.length));
      expect(choices.any(state.contains), isFalse);
      expect(choices, isNotEmpty);
      state.acquire(choices.first);
      state.advanceReward();
    }
    expect(state.items, hasLength(8));
  });

  test('tag synergies activate at two and upgrade at four items', () {
    final state = SurvivalItemBuildState()
      ..acquire(SurvivalItemId.railCapacitor);
    expect(state.synergyTier(SurvivalItemTag.projectile), 0);
    state.acquire(SurvivalItemId.splitProtocol);
    expect(state.synergyTier(SurvivalItemTag.projectile), 1);
    state
      ..acquire(SurvivalItemId.ricochetLens)
      ..acquire(SurvivalItemId.blastChamber);
    expect(state.synergyTier(SurvivalItemTag.projectile), 2);
    expect(state.gunBonusShots, greaterThanOrEqualTo(2));
    expect(state.gunBonusHits, greaterThanOrEqualTo(2));
  });

  test('every weapon owns three distinct competitive build recipes', () {
    final globalFrequency = <SurvivalItemId, int>{};
    for (final recipe in SurvivalItemCatalog.recommendedBuilds) {
      for (final item in recipe.coreItems) {
        globalFrequency.update(item, (count) => count + 1, ifAbsent: () => 1);
        expect(
          SurvivalItemCatalog.definition(item).supports(recipe.weapon),
          true,
        );
      }
      expect(recipe.coreItems.toSet(), hasLength(recipe.coreItems.length));
      expect(recipe.primaryTags, isNotEmpty);
    }
    for (final weapon in PlayerWeapon.values) {
      final recipes = SurvivalItemCatalog.recommendedBuilds
          .where((recipe) => recipe.weapon == weapon)
          .toList(growable: false);
      expect(recipes, hasLength(3));
      expect(recipes.map((recipe) => recipe.primaryTags).toSet(), hasLength(3));
      for (final recipe in recipes) {
        final state = SurvivalItemBuildState();
        for (final item in recipe.coreItems) {
          state.acquire(item);
        }
        expect(state.buildPotentialFor(weapon), greaterThanOrEqualTo(12));
      }
    }
    expect(
      globalFrequency.values.every(
        (count) => count < SurvivalItemCatalog.recommendedBuilds.length,
      ),
      isTrue,
      reason: 'No single item may be mandatory in every viable build.',
    );
  });
}
