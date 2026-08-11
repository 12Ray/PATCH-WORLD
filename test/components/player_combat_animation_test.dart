import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_combat_animation.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

void main() {
  test('all Pass 2 combat events are visible from gameplay time zero', () {
    for (final weapon in PlayerWeapon.values) {
      for (final state in PlayerCombatAnimation.values) {
        expect(state.eventFrame, 0, reason: '${weapon.name}.${state.name}');
        expect(
          state.activeFrameEnd(weapon),
          inInclusiveRange(0, state.frameCount - 1),
          reason: '${weapon.name}.${state.name}',
        );
        expect(state.fps(weapon), greaterThan(0));
        expect(
          weapon.combatAnimationAssetPath(state),
          'sprites/art_v3/hero/${weapon.name}-${state.assetSuffix}.png',
        );
      }
    }
  });

  test('normal combo strips span the existing weapon cooldowns', () {
    for (final weapon in PlayerWeapon.values) {
      for (var index = 1; index <= 6; index += 1) {
        final state = PlayerCombatAnimation.attackForIndex(index);
        final visualDuration = state.frameCount / state.fps(weapon);
        expect(
          visualDuration,
          closeTo(weapon.baseCooldown, 0.000001),
          reason: '${weapon.name}.attack$index',
        );
      }
    }
  });

  test('attack index rejects values outside the six-step combo', () {
    expect(() => PlayerCombatAnimation.attackForIndex(0), throwsArgumentError);
    expect(() => PlayerCombatAnimation.attackForIndex(7), throwsArgumentError);
  });

  test(
    'ability composition retains every authored transition and action frame',
    () {
      final result = composeAbilityMotionFrames<int>(
        authoredActionFrames: <int>[1, 2, 3, 4],
        transitionFrames: <int>[5, 6, 7, 8],
        abilityFrames: <int>[9, 10],
      );

      expect(result, <int>[1, 2, 3, 4, 5, 9, 10, 6, 7, 8]);
    },
  );
}
