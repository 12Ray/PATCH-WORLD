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
    PlayerWeapon.gauntlet => 0.34,
    PlayerWeapon.gun => 0.24,
  };
}
