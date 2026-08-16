import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

void main() {
  test('each weapon exposes one upgrade in every ROOM 1 build branch', () {
    for (final weapon in PlayerWeapon.values) {
      final choices = WeaponBuildCatalog.choicesFor(weapon);
      expect(choices, hasLength(3), reason: weapon.name);
      expect(choices.every((choice) => choice.weapon == weapon), isTrue);
      expect(
        choices.map((choice) => choice.branch).toSet(),
        WeaponBuildBranch.values.toSet(),
      );
    }
  });

  test('three rewards can concentrate into a tier-three sword build', () {
    final state = WeaponBuildState();
    for (var pick = 0; pick < 3; pick += 1) {
      expect(
        state.upgrade(
          WeaponBuildUpgradeId.swordDashCircuit,
          PlayerWeapon.sword,
        ),
        isTrue,
      );
    }

    expect(state.totalChoices, 3);
    expect(state.swordDashCooldownReduction, closeTo(.9, .0001));
    expect(
      state.damageBonusFor(
        weapon: PlayerWeapon.sword,
        motionIndex: 1,
        counter: false,
        airborne: false,
        dashEmpowered: true,
      ),
      2,
    );
    expect(
      state.upgrade(WeaponBuildUpgradeId.swordCounterEdge, PlayerWeapon.sword),
      isFalse,
      reason: 'ROOM 1 grants exactly three build choices.',
    );
  });

  test('gauntlet and gun branches modify their authored combat identities', () {
    final gauntlet = WeaponBuildState()
      ..upgrade(WeaponBuildUpgradeId.gauntletAirDrive, PlayerWeapon.gauntlet)
      ..upgrade(
        WeaponBuildUpgradeId.gauntletSeismicCore,
        PlayerWeapon.gauntlet,
      );
    expect(gauntlet.gauntletAirJumpSpeedBonus, .03);
    expect(
      gauntlet.damageBonusFor(
        weapon: PlayerWeapon.gauntlet,
        motionIndex: 6,
        counter: false,
        airborne: true,
        dashEmpowered: false,
      ),
      2,
    );

    final gun = WeaponBuildState();
    for (var pick = 0; pick < 3; pick += 1) {
      gun.upgrade(WeaponBuildUpgradeId.gunBurstLoader, PlayerWeapon.gun);
    }
    expect(gun.attackCooldownMultiplierFor(PlayerWeapon.gun), .865);
  });

  test('a build cannot receive an upgrade owned by another weapon', () {
    final state = WeaponBuildState();
    expect(
      state.upgrade(WeaponBuildUpgradeId.gunRailCore, PlayerWeapon.sword),
      isFalse,
    );
    expect(state.tiers, isEmpty);
  });
}
