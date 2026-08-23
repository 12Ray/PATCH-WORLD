import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/items/run_item_state.dart';

void main() {
  test('acquisition distinguishes a new install from duplicate conversion', () {
    final state = RunItemState();

    final installed = state.acquire(RunItemId.bladeCalibrator);
    final duplicate = state.acquire(RunItemId.bladeCalibrator);

    expect(installed.item, RunItemId.bladeCalibrator);
    expect(installed.outcome, RunItemAcquisitionOutcome.installed);
    expect(installed.isInstalled, isTrue);
    expect(installed.isDuplicate, isFalse);
    expect(duplicate.outcome, RunItemAcquisitionOutcome.duplicateConverted);
    expect(duplicate.isInstalled, isFalse);
    expect(duplicate.isDuplicate, isTrue);
    expect(state.items, <RunItemId>{RunItemId.bladeCalibrator});
  });

  test('Damage Lab calibrators improve geometry without adding damage', () {
    final state = RunItemState()
      ..acquire(RunItemId.bladeCalibrator)
      ..acquire(RunItemId.impactCalibrator)
      ..acquire(RunItemId.barrelCalibrator);

    expect(
      state.weaponReachMultiplierFor(
        weapon: PlayerWeapon.sword,
        motionIndex: 1,
        dashEmpowered: false,
      ),
      1.08,
    );
    expect(
      state.weaponReachMultiplierFor(
        weapon: PlayerWeapon.gauntlet,
        motionIndex: 3,
        dashEmpowered: false,
      ),
      1.08,
    );
    expect(state.projectileSpeedMultiplierFor(PlayerWeapon.gun), 1.08);
    expect(state.projectileSpeedMultiplierFor(PlayerWeapon.sword), 1);
    expect(state.weaponDamageBonusFor(PlayerWeapon.sword, 6), 0);
    expect(state.weaponDamageBonusFor(PlayerWeapon.gauntlet, 6), 0);
    expect(state.weaponDamageBonusFor(PlayerWeapon.gun, 4), 0);
  });

  test('Temporal event modules make small weapon-specific cadence changes', () {
    final state = RunItemState()
      ..acquire(RunItemId.afterimageGovernor)
      ..acquire(RunItemId.echoLiftServo)
      ..acquire(RunItemId.forecastTrigger);

    expect(state.swordDashCooldownSeconds, 4.75);
    expect(state.gauntletAirJumpSpeedMultiplier, closeTo(.85, .0001));
    expect(
      state.attackCooldownMultiplierFor(PlayerWeapon.gun),
      closeTo(.97, .0001),
    );
    expect(state.attackCooldownMultiplierFor(PlayerWeapon.sword), 1);
    expect(state.attackCooldownMultiplierFor(PlayerWeapon.gauntlet), 1);
  });

  test('Collision modules add conditional reach and rail spatial control', () {
    final state = RunItemState()
      ..acquire(RunItemId.momentumEdge)
      ..acquire(RunItemId.seismicCoupler)
      ..acquire(RunItemId.prismBore);

    expect(state.enablesSwordDashEmpowerWindow, isTrue);
    expect(
      state.weaponReachMultiplierFor(
        weapon: PlayerWeapon.sword,
        motionIndex: 2,
        dashEmpowered: false,
      ),
      1,
    );
    expect(
      state.weaponReachMultiplierFor(
        weapon: PlayerWeapon.sword,
        motionIndex: 2,
        dashEmpowered: true,
      ),
      1.15,
    );
    expect(
      state.weaponReachMultiplierFor(
        weapon: PlayerWeapon.gauntlet,
        motionIndex: 5,
        dashEmpowered: false,
      ),
      1,
    );
    expect(
      state.weaponReachMultiplierFor(
        weapon: PlayerWeapon.gauntlet,
        motionIndex: 6,
        dashEmpowered: false,
      ),
      1.15,
    );
    expect(state.projectileMaxHitsBonusFor(PlayerWeapon.gun, 4), 1);
    expect(state.projectileMaxHitsBonusFor(PlayerWeapon.gun, 3), 0);
    expect(state.projectileRicochetRadiansFor(PlayerWeapon.gun, 4), .10);
    expect(state.projectileRicochetRadiansFor(PlayerWeapon.sword, 4), 0);
  });

  test('event modifiers compose with existing secret rewards and caps', () {
    final state = RunItemState()
      ..acquire(RunItemId.dashBuffer)
      ..acquire(RunItemId.chronalBuffer)
      ..acquire(RunItemId.afterimageGovernor)
      ..acquire(RunItemId.echoSpring)
      ..acquire(RunItemId.echoLiftServo)
      ..acquire(RunItemId.targetingDaemon)
      ..acquire(RunItemId.predictiveScope)
      ..acquire(RunItemId.forecastTrigger);

    expect(state.swordDashCooldownSeconds, 3.25);
    expect(state.gauntletAirJumpSpeedMultiplier, closeTo(.95, .0001));
    expect(
      state.attackCooldownMultiplierFor(PlayerWeapon.gun),
      closeTo(.90 * .93 * .97, .0001),
    );
  });
}
