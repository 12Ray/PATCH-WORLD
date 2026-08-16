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
}

extension RunItemIdPresentation on RunItemId {
  String get localizationKey => 'item.$name.name';
  String get descriptionLocalizationKey => 'item.$name.description';
}

/// Items collected during the current campaign run.
final class RunItemState {
  final Set<RunItemId> _items = <RunItemId>{};

  Set<RunItemId> get items => Set<RunItemId>.unmodifiable(_items);
  bool contains(RunItemId item) => _items.contains(item);
  bool acquire(RunItemId item) => _items.add(item);

  double get swordDashCooldownSeconds {
    var seconds = 5.0;
    if (contains(RunItemId.dashBuffer)) seconds -= 1;
    if (contains(RunItemId.chronalBuffer)) seconds -= .5;
    return seconds.clamp(3.5, 5.0).toDouble();
  }

  double get gauntletAirJumpSpeedMultiplier =>
      contains(RunItemId.echoSpring) ? .92 : .82;

  double attackCooldownMultiplierFor(PlayerWeapon weapon) {
    var multiplier = contains(RunItemId.temporalRelay) ? .92 : 1.0;
    if (weapon == PlayerWeapon.gun) {
      if (contains(RunItemId.targetingDaemon)) multiplier *= .90;
      if (contains(RunItemId.predictiveScope)) multiplier *= .93;
    }
    return multiplier;
  }

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
