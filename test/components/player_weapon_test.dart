import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

void main() {
  test('starting weapon profiles match the approved balance table', () {
    expect(PlayerWeapon.sword.baseIntegrity, 5);
    expect(PlayerWeapon.gauntlet.baseIntegrity, 7);
    expect(PlayerWeapon.gun.baseIntegrity, 3);

    expect(PlayerWeapon.sword.baseCooldown, 0.28);
    expect(PlayerWeapon.gauntlet.baseCooldown, 0.36);
    expect(PlayerWeapon.gun.baseCooldown, 0.32);
    expect(PlayerWeapon.gauntlet.moveSpeedMultiplier, 0.95);

    expect(
      PlayerWeapon.sword.idleAssetPath,
      'sprites/art_v3/hero/sword-idle.png',
    );
    expect(
      PlayerWeapon.gauntlet.idleAssetPath,
      'sprites/art_v3/hero/gauntlet-idle.png',
    );
    expect(PlayerWeapon.gun.idleAssetPath, 'sprites/art_v3/hero/gun-idle.png');

    for (final weapon in PlayerWeapon.values) {
      for (final state in PlayerAnimationState.values) {
        expect(
          weapon.animationAssetPath(state),
          'sprites/art_v3/hero/${weapon.name}-${state.assetSuffix}.png',
        );
      }
    }
    expect(PlayerAnimationState.run.frameCount, 6);
    expect(PlayerAnimationState.jumpRise.frameCount, 2);
    expect(PlayerAnimationState.apex.frameCount, 1);
    expect(PlayerAnimationState.fall.frameCount, 2);
    expect(PlayerAnimationState.land.frameCount, 3);
    expect(PlayerAnimationState.land.loop, isFalse);
  });
}
