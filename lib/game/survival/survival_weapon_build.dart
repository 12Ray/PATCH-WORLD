import 'dart:math' as math;

import 'package:patch_world/game/combat/player_weapon.dart';

enum SurvivalWeaponUpgradeId {
  swordRiftEdge,
  swordBlinkCircuit,
  swordExecutionLoop,
  gauntletQuakeCore,
  gauntletMagnetKnuckle,
  gauntletCounterBattery,
  gunRailDriver,
  gunDroneMagazine,
  gunRicochetProtocol,
}

extension SurvivalWeaponUpgradeSpec on SurvivalWeaponUpgradeId {
  String get id => 'survivalBuild.$name';

  PlayerWeapon get weapon => switch (this) {
    SurvivalWeaponUpgradeId.swordRiftEdge ||
    SurvivalWeaponUpgradeId.swordBlinkCircuit ||
    SurvivalWeaponUpgradeId.swordExecutionLoop => PlayerWeapon.sword,
    SurvivalWeaponUpgradeId.gauntletQuakeCore ||
    SurvivalWeaponUpgradeId.gauntletMagnetKnuckle ||
    SurvivalWeaponUpgradeId.gauntletCounterBattery => PlayerWeapon.gauntlet,
    SurvivalWeaponUpgradeId.gunRailDriver ||
    SurvivalWeaponUpgradeId.gunDroneMagazine ||
    SurvivalWeaponUpgradeId.gunRicochetProtocol => PlayerWeapon.gun,
  };
}

final class SurvivalWeaponUpgradeRequest {
  const SurvivalWeaponUpgradeRequest({
    required this.level,
    required this.choices,
  });

  final int level;
  final List<SurvivalWeaponUpgradeId> choices;
}

/// Persistent, run-local specialization state for the selected survival
/// weapon. Each weapon owns three branches and every branch can reach tier 3.
final class SurvivalWeaponBuildState {
  final Map<SurvivalWeaponUpgradeId, int> _tiers =
      <SurvivalWeaponUpgradeId, int>{};

  Map<SurvivalWeaponUpgradeId, int> get tiers =>
      Map<SurvivalWeaponUpgradeId, int>.unmodifiable(_tiers);

  int tier(SurvivalWeaponUpgradeId id) => _tiers[id] ?? 0;

  int upgrade(SurvivalWeaponUpgradeId id) {
    final next = math.min(3, tier(id) + 1);
    _tiers[id] = next;
    return next;
  }

  List<SurvivalWeaponUpgradeId> choicesFor(PlayerWeapon weapon) =>
      List<SurvivalWeaponUpgradeId>.unmodifiable(
        SurvivalWeaponUpgradeId.values.where(
          (id) => id.weapon == weapon && tier(id) < 3,
        ),
      );

  int damageBonusFor(PlayerWeapon weapon, {required int motionIndex}) =>
      switch (weapon) {
        PlayerWeapon.sword =>
          tier(SurvivalWeaponUpgradeId.swordRiftEdge) +
              (motionIndex == 3 || motionIndex == 6
                  ? tier(SurvivalWeaponUpgradeId.swordExecutionLoop)
                  : 0),
        PlayerWeapon.gauntlet =>
          motionIndex >= 3
              ? tier(SurvivalWeaponUpgradeId.gauntletQuakeCore)
              : 0,
        PlayerWeapon.gun =>
          motionIndex == 4 ? tier(SurvivalWeaponUpgradeId.gunRailDriver) : 0,
      };

  double attackCooldownMultiplierFor(PlayerWeapon weapon) => switch (weapon) {
    PlayerWeapon.sword =>
      1 - tier(SurvivalWeaponUpgradeId.swordExecutionLoop) * 0.04,
    PlayerWeapon.gauntlet =>
      1 - tier(SurvivalWeaponUpgradeId.gauntletCounterBattery) * 0.035,
    PlayerWeapon.gun =>
      1 - tier(SurvivalWeaponUpgradeId.gunDroneMagazine) * 0.05,
  };

  double get swordReachMultiplier =>
      1 + tier(SurvivalWeaponUpgradeId.swordRiftEdge) * 0.16;
  double get swordSpecialDistance =>
      108 + tier(SurvivalWeaponUpgradeId.swordBlinkCircuit) * 22;
  int get swordSpecialDamage =>
      2 + tier(SurvivalWeaponUpgradeId.swordBlinkCircuit);

  double get gauntletReachMultiplier =>
      1 + tier(SurvivalWeaponUpgradeId.gauntletMagnetKnuckle) * 0.18;
  double get gauntletQuakeRadius =>
      92 + tier(SurvivalWeaponUpgradeId.gauntletQuakeCore) * 18;
  int get gauntletQuakeDamage =>
      2 + tier(SurvivalWeaponUpgradeId.gauntletQuakeCore);

  int get gunBonusShots => tier(SurvivalWeaponUpgradeId.gunDroneMagazine);
  int get gunMaxHits => 1 + tier(SurvivalWeaponUpgradeId.gunRailDriver);
  double get gunRicochetRadians =>
      tier(SurvivalWeaponUpgradeId.gunRicochetProtocol) * 0.18;
  double get gunProjectileSpeedMultiplier =>
      1 + tier(SurvivalWeaponUpgradeId.gunRailDriver) * 0.12;

  double specialCooldownFor(PlayerWeapon weapon) => switch (weapon) {
    PlayerWeapon.sword =>
      4.2 - tier(SurvivalWeaponUpgradeId.swordBlinkCircuit) * 0.45,
    PlayerWeapon.gauntlet =>
      4.8 - tier(SurvivalWeaponUpgradeId.gauntletCounterBattery) * 0.4,
    PlayerWeapon.gun =>
      5.2 - tier(SurvivalWeaponUpgradeId.gunDroneMagazine) * 0.45,
  };

  void reset() => _tiers.clear();
}
