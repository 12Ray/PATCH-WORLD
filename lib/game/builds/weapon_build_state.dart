import 'package:patch_world/game/combat/player_weapon.dart';

enum WeaponBuildBranch { mobility, counter, finisher }

enum WeaponBuildUpgradeId {
  swordDashCircuit,
  swordCounterEdge,
  swordFinisherCore,
  gauntletAirDrive,
  gauntletGuardMesh,
  gauntletSeismicCore,
  gunBurstLoader,
  gunPhaseMagazine,
  gunRailCore,
}

extension WeaponBuildUpgradeSpec on WeaponBuildUpgradeId {
  PlayerWeapon get weapon => switch (this) {
    WeaponBuildUpgradeId.swordDashCircuit ||
    WeaponBuildUpgradeId.swordCounterEdge ||
    WeaponBuildUpgradeId.swordFinisherCore => PlayerWeapon.sword,
    WeaponBuildUpgradeId.gauntletAirDrive ||
    WeaponBuildUpgradeId.gauntletGuardMesh ||
    WeaponBuildUpgradeId.gauntletSeismicCore => PlayerWeapon.gauntlet,
    WeaponBuildUpgradeId.gunBurstLoader ||
    WeaponBuildUpgradeId.gunPhaseMagazine ||
    WeaponBuildUpgradeId.gunRailCore => PlayerWeapon.gun,
  };

  WeaponBuildBranch get branch => switch (this) {
    WeaponBuildUpgradeId.swordDashCircuit ||
    WeaponBuildUpgradeId.gauntletAirDrive ||
    WeaponBuildUpgradeId.gunBurstLoader => WeaponBuildBranch.mobility,
    WeaponBuildUpgradeId.swordCounterEdge ||
    WeaponBuildUpgradeId.gauntletGuardMesh ||
    WeaponBuildUpgradeId.gunPhaseMagazine => WeaponBuildBranch.counter,
    WeaponBuildUpgradeId.swordFinisherCore ||
    WeaponBuildUpgradeId.gauntletSeismicCore ||
    WeaponBuildUpgradeId.gunRailCore => WeaponBuildBranch.finisher,
  };

  String get nameLocalizationKey => 'build.$name.name';
  String get descriptionLocalizationKey => 'build.$name.description';
}

final class WeaponBuildSelectionRequest {
  const WeaponBuildSelectionRequest({
    required this.encounterId,
    required this.weapon,
    required this.choices,
  });

  final int encounterId;
  final PlayerWeapon weapon;
  final List<WeaponBuildUpgradeId> choices;
}

abstract final class WeaponBuildCatalog {
  static List<WeaponBuildUpgradeId> choicesFor(PlayerWeapon weapon) =>
      WeaponBuildUpgradeId.values
          .where((upgrade) => upgrade.weapon == weapon)
          .toList(growable: false);
}

/// Three ROOM 1 rewards can be concentrated into one tier-three identity or
/// distributed across branches. The state stores only the run-persistent
/// choice; combat systems ask it for small deterministic modifiers.
final class WeaponBuildState {
  static const int maximumTier = 3;
  static const int maximumRoomOneChoices = 3;

  final Map<WeaponBuildUpgradeId, int> _tiers = <WeaponBuildUpgradeId, int>{};

  Map<WeaponBuildUpgradeId, int> get tiers =>
      Map<WeaponBuildUpgradeId, int>.unmodifiable(_tiers);
  int get totalChoices => _tiers.values.fold(0, (sum, tier) => sum + tier);
  int tier(WeaponBuildUpgradeId id) => _tiers[id] ?? 0;

  bool canUpgrade(WeaponBuildUpgradeId id, PlayerWeapon weapon) =>
      id.weapon == weapon &&
      tier(id) < maximumTier &&
      totalChoices < maximumRoomOneChoices;

  bool upgrade(WeaponBuildUpgradeId id, PlayerWeapon weapon) {
    if (!canUpgrade(id, weapon)) return false;
    _tiers[id] = tier(id) + 1;
    return true;
  }

  double get swordDashCooldownReduction =>
      tier(WeaponBuildUpgradeId.swordDashCircuit) * .30;

  double get gauntletAirJumpSpeedBonus =>
      tier(WeaponBuildUpgradeId.gauntletAirDrive) * .03;

  double attackCooldownMultiplierFor(PlayerWeapon weapon) => switch (weapon) {
    PlayerWeapon.sword => 1,
    PlayerWeapon.gauntlet => 1,
    PlayerWeapon.gun => 1 - tier(WeaponBuildUpgradeId.gunBurstLoader) * .045,
  };

  int damageBonusFor({
    required PlayerWeapon weapon,
    required int motionIndex,
    required bool counter,
    required bool airborne,
    required bool dashEmpowered,
  }) => switch (weapon) {
    PlayerWeapon.sword => _swordDamageBonus(
      motionIndex: motionIndex,
      counter: counter,
      dashEmpowered: dashEmpowered,
    ),
    PlayerWeapon.gauntlet => _gauntletDamageBonus(
      motionIndex: motionIndex,
      counter: counter,
      airborne: airborne,
    ),
    PlayerWeapon.gun => _gunDamageBonus(
      motionIndex: motionIndex,
      counter: counter,
    ),
  };

  int _swordDamageBonus({
    required int motionIndex,
    required bool counter,
    required bool dashEmpowered,
  }) {
    var bonus = 0;
    final dashTier = tier(WeaponBuildUpgradeId.swordDashCircuit);
    if (dashEmpowered && dashTier > 0) bonus += dashTier >= 3 ? 2 : 1;
    final counterTier = tier(WeaponBuildUpgradeId.swordCounterEdge);
    if (counter && counterTier > 0) bonus += counterTier >= 3 ? 2 : 1;
    final finisherTier = tier(WeaponBuildUpgradeId.swordFinisherCore);
    if (motionIndex == 6 && finisherTier > 0) {
      bonus += finisherTier >= 3 ? 2 : 1;
    } else if (motionIndex == 4 && finisherTier >= 2) {
      bonus += 1;
    }
    return bonus;
  }

  int _gauntletDamageBonus({
    required int motionIndex,
    required bool counter,
    required bool airborne,
  }) {
    var bonus = 0;
    final airTier = tier(WeaponBuildUpgradeId.gauntletAirDrive);
    if (airborne && airTier > 0) bonus += airTier >= 3 ? 2 : 1;
    final guardTier = tier(WeaponBuildUpgradeId.gauntletGuardMesh);
    if (counter && guardTier > 0) bonus += guardTier >= 3 ? 2 : 1;
    final seismicTier = tier(WeaponBuildUpgradeId.gauntletSeismicCore);
    if (motionIndex == 6 && seismicTier > 0) {
      bonus += seismicTier >= 3 ? 2 : 1;
    } else if (motionIndex >= 3 && seismicTier >= 2) {
      bonus += 1;
    }
    return bonus;
  }

  int _gunDamageBonus({required int motionIndex, required bool counter}) {
    var bonus = 0;
    final phaseTier = tier(WeaponBuildUpgradeId.gunPhaseMagazine);
    if (counter && phaseTier > 0) {
      bonus += phaseTier >= 3 ? 2 : 1;
    } else if ((motionIndex == 3 || motionIndex == 6) && phaseTier >= 2) {
      bonus += 1;
    }
    final railTier = tier(WeaponBuildUpgradeId.gunRailCore);
    if (motionIndex == 4 && railTier > 0) {
      bonus += railTier >= 3 ? 2 : 1;
    }
    return bonus;
  }

  void reset() => _tiers.clear();
}
