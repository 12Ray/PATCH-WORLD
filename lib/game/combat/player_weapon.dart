enum PlayerWeapon { sword, gauntlet, gun }

extension PlayerWeaponSpec on PlayerWeapon {
  String get label => switch (this) {
    PlayerWeapon.sword => 'SWORD',
    PlayerWeapon.gauntlet => 'GAUNTLET',
    PlayerWeapon.gun => 'GUN',
  };

  String get assetName => name;

  double get baseCooldown => switch (this) {
    PlayerWeapon.sword => 0.28,
    PlayerWeapon.gauntlet => 0.36,
    PlayerWeapon.gun => 0.32,
  };

  int get baseIntegrity => switch (this) {
    PlayerWeapon.sword => 5,
    PlayerWeapon.gauntlet => 7,
    PlayerWeapon.gun => 3,
  };

  double get moveSpeedMultiplier => switch (this) {
    PlayerWeapon.gauntlet => 0.95,
    _ => 1,
  };

  String get localizationKey => 'weapon.$name';
}
