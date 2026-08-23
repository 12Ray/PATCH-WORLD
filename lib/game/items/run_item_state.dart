import 'package:patch_world/game/combat/player_weapon.dart';

enum RunItemId {
  conduitHeart,
  overflowCapacitor,
  echoClock,
  temporalRelay,
  vectorBoots,
  collisionPrism,
  dashBuffer,
  airStack,
  targetingDaemon,
  chronalBuffer,
  echoSpring,
  predictiveScope,
  vectorEdge,
  impactLattice,
  splitChamber,
  bladeCalibrator,
  impactCalibrator,
  barrelCalibrator,
  afterimageGovernor,
  echoLiftServo,
  forecastTrigger,
  momentumEdge,
  seismicCoupler,
  prismBore,
}

extension RunItemIdPresentation on RunItemId {
  String get localizationKey => 'item.$name.name';
  String get descriptionLocalizationKey => 'item.$name.description';
}

enum RunItemAcquisitionOutcome { installed, duplicateConverted }

/// The authoritative result of trying to install a campaign run item.
///
/// Reward presenters consume this value instead of assuming that every item
/// source installed a new module. This keeps duplicate compensation truthful
/// without coupling item state to a Flame component or player health.
final class RunItemAcquisitionResult {
  const RunItemAcquisitionResult({required this.item, required this.outcome});

  final RunItemId item;
  final RunItemAcquisitionOutcome outcome;

  bool get isInstalled => outcome == RunItemAcquisitionOutcome.installed;
  bool get isDuplicate =>
      outcome == RunItemAcquisitionOutcome.duplicateConverted;
}

/// Items collected during the current campaign run.
final class RunItemState {
  final Set<RunItemId> _items = <RunItemId>{};

  Set<RunItemId> get items => Set<RunItemId>.unmodifiable(_items);
  bool contains(RunItemId item) => _items.contains(item);
  RunItemAcquisitionResult acquire(RunItemId item) => RunItemAcquisitionResult(
    item: item,
    outcome: _items.add(item)
        ? RunItemAcquisitionOutcome.installed
        : RunItemAcquisitionOutcome.duplicateConverted,
  );

  double get swordDashCooldownSeconds {
    var seconds = 5.0;
    if (contains(RunItemId.dashBuffer)) seconds -= 1;
    if (contains(RunItemId.chronalBuffer)) seconds -= .5;
    if (contains(RunItemId.afterimageGovernor)) seconds -= .25;
    return seconds.clamp(3.25, 5.0).toDouble();
  }

  double get gauntletAirJumpSpeedMultiplier {
    var multiplier = contains(RunItemId.echoSpring) ? .92 : .82;
    if (contains(RunItemId.echoLiftServo)) multiplier += .03;
    return multiplier.clamp(.82, 1).toDouble();
  }

  double attackCooldownMultiplierFor(PlayerWeapon weapon) {
    var multiplier = contains(RunItemId.temporalRelay) ? .92 : 1.0;
    if (weapon == PlayerWeapon.gun) {
      if (contains(RunItemId.targetingDaemon)) multiplier *= .90;
      if (contains(RunItemId.predictiveScope)) multiplier *= .93;
      if (contains(RunItemId.forecastTrigger)) multiplier *= .97;
    }
    return multiplier;
  }

  /// Campaign attack geometry multiplier consumed by [PlayerComponent].
  ///
  /// Calibration modules improve the selected weapon's baseline spatial
  /// control. Collision modules remain conditional so they do not add flat
  /// damage or erase the three weapons' established balance identities.
  double weaponReachMultiplierFor({
    required PlayerWeapon weapon,
    required int motionIndex,
    required bool dashEmpowered,
  }) {
    var multiplier = switch (weapon) {
      PlayerWeapon.sword => contains(RunItemId.bladeCalibrator) ? 1.08 : 1.0,
      PlayerWeapon.gauntlet =>
        contains(RunItemId.impactCalibrator) ? 1.08 : 1.0,
      PlayerWeapon.gun => 1.0,
    };
    if (weapon == PlayerWeapon.sword &&
        dashEmpowered &&
        contains(RunItemId.momentumEdge)) {
      multiplier *= 1.15;
    }
    if (weapon == PlayerWeapon.gauntlet &&
        motionIndex == 6 &&
        contains(RunItemId.seismicCoupler)) {
      multiplier *= 1.15;
    }
    return multiplier;
  }

  double projectileSpeedMultiplierFor(PlayerWeapon weapon) =>
      weapon == PlayerWeapon.gun && contains(RunItemId.barrelCalibrator)
      ? 1.08
      : 1.0;

  bool get enablesSwordDashEmpowerWindow => contains(RunItemId.momentumEdge);

  int projectileMaxHitsBonusFor(PlayerWeapon weapon, int motionIndex) =>
      weapon == PlayerWeapon.gun &&
          motionIndex == 4 &&
          contains(RunItemId.prismBore)
      ? 1
      : 0;

  double projectileRicochetRadiansFor(PlayerWeapon weapon, int motionIndex) =>
      weapon == PlayerWeapon.gun &&
          motionIndex == 4 &&
          contains(RunItemId.prismBore)
      ? .10
      : 0;

  int weaponDamageBonusFor(PlayerWeapon weapon, int motionIndex) =>
      switch (weapon) {
        PlayerWeapon.sword =>
          contains(RunItemId.vectorEdge) &&
                  (motionIndex == 4 || motionIndex == 6)
              ? 1
              : 0,
        PlayerWeapon.gauntlet =>
          contains(RunItemId.impactLattice) && motionIndex >= 3 ? 1 : 0,
        PlayerWeapon.gun =>
          contains(RunItemId.splitChamber) && motionIndex == 4 ? 1 : 0,
      };

  void reset() => _items.clear();
}
