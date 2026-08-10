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
  });
}
