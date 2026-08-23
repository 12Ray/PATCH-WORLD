import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/attack_tier.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_attack_pattern.dart';
import 'package:patch_world/game/components/enemies/platformer/platformer_enemy_brain.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

void main() {
  test('catalog owns fifteen mechanically distinct combat profiles', () {
    final profiles = EnemyAttackPatternCatalog.all;

    expect(profiles, hasLength(15));
    expect(
      profiles.map((profile) => profile.archetypeName).toSet(),
      PlatformerEnemyArchetype.values
          .map((archetype) => archetype.name)
          .toSet(),
    );
    expect(profiles.map((profile) => profile.familyId).toSet(), hasLength(15));
    expect(
      profiles.map((profile) => profile.counterplayId).toSet(),
      hasLength(15),
    );
    expect(
      profiles.map((profile) => profile.mechanicalFingerprint).toSet(),
      hasLength(15),
    );
  });

  test('every profile has four distinct composed action slots', () {
    for (final profile in EnemyAttackPatternCatalog.all) {
      expect(profile.actions, hasLength(4), reason: profile.archetypeName);
      expect(
        profile.actions.map((action) => action.slot).toSet(),
        EnemyActionSlot.values.toSet(),
        reason: profile.archetypeName,
      );
      expect(
        profile.actions.map((action) => action.mechanicalFingerprint).toSet(),
        hasLength(4),
        reason: profile.archetypeName,
      );
      for (final action in profile.actions) {
        expect(action.effects, isNotEmpty, reason: action.motionId);
        expect(
          profile.resolveAction(action.actionId(profile.archetypeName)),
          same(action),
          reason: action.motionId,
        );
      }
    }
  });

  test('every parryable slot creates a real reflectable projectile window', () {
    for (final profile in EnemyAttackPatternCatalog.all) {
      final action = profile.actionForSlot(EnemyActionSlot.parryable);
      expect(action.createsParryWindow, isTrue, reason: profile.archetypeName);
      expect(
        action.effects.whereType<EnemyProjectileEffectSpec>().any(
          (effect) => effect.tier == AttackTier.parryable,
        ),
        isTrue,
        reason: profile.archetypeName,
      );
    }
  });

  test('each connected-campaign regular enemy composes multiple mechanics', () {
    for (final archetype in PlatformerEnemyArchetype.values.where(
      (archetype) => !archetype.isMidBoss,
    )) {
      final profile = EnemyAttackPatternCatalog.forArchetype(archetype.name);
      final effectTypes = profile.actions
          .expand((action) => action.effects)
          .map((effect) => effect.runtimeType)
          .toSet();
      final projectilePatterns = profile.actions
          .expand((action) => action.effects)
          .whereType<EnemyProjectileEffectSpec>()
          .map((effect) => effect.pattern)
          .toSet();

      expect(
        effectTypes.length,
        greaterThanOrEqualTo(2),
        reason: archetype.name,
      );
      expect(
        projectilePatterns.length,
        greaterThanOrEqualTo(2),
        reason: archetype.name,
      );
    }
  });

  test('brain timing and action ids are sourced from the same catalog', () {
    for (final profile in EnemyAttackPatternCatalog.all) {
      final brainPattern = PlatformerEnemyBrain.combatPattern(
        profile.archetypeName,
      );
      expect(brainPattern, hasLength(5), reason: profile.archetypeName);
      for (var index = 0; index < profile.actions.length; index += 1) {
        final action = profile.actions[index];
        final decision = brainPattern[index + 1];
        expect(
          decision.actionId,
          action.actionId(profile.archetypeName),
          reason: action.motionId,
        );
        expect(decision.telegraph, action.telegraphSeconds);
        expect(decision.active, action.activeSeconds);
        expect(decision.recovery, action.recoverySeconds);
      }
    }
  });

  test('unknown action ids cannot silently fall back to a shared pattern', () {
    final profile = EnemyAttackPatternCatalog.forArchetype('patchMite');

    expect(profile.resolveAction('patchMite.normal.notARealMotion'), isNull);
    expect(
      () => EnemyAttackPatternCatalog.forArchetype('notAnEnemy'),
      throwsArgumentError,
    );
  });
}
