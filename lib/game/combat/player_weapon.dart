enum PlayerWeapon { sword, gauntlet, gun }

enum PlayerAnimationState { idle, run, jumpRise, apex, fall, land }

extension PlayerAnimationStateSpec on PlayerAnimationState {
  String get assetSuffix => switch (this) {
    PlayerAnimationState.jumpRise => 'jump-rise',
    _ => name,
  };

  int get frameCount => switch (this) {
    PlayerAnimationState.idle => 4,
    PlayerAnimationState.run => 6,
    PlayerAnimationState.jumpRise => 2,
    PlayerAnimationState.apex => 1,
    PlayerAnimationState.fall => 2,
    PlayerAnimationState.land => 3,
  };

  double get fps => switch (this) {
    PlayerAnimationState.idle => 6,
    PlayerAnimationState.run => 10,
    PlayerAnimationState.jumpRise => 10,
    PlayerAnimationState.apex => 1,
    PlayerAnimationState.fall => 10,
    PlayerAnimationState.land => 12,
  };

  bool get loop => this != PlayerAnimationState.land;
}

extension PlayerWeaponSpec on PlayerWeapon {
  String get label => switch (this) {
    PlayerWeapon.sword => 'SWORD',
    PlayerWeapon.gauntlet => 'GAUNTLET',
    PlayerWeapon.gun => 'GUN',
  };

  String get assetName => name;

  String animationAssetPath(PlayerAnimationState state) =>
      'sprites/art_v3/hero/$assetName-${state.assetSuffix}.png';

  String get idleAssetPath => animationAssetPath(PlayerAnimationState.idle);

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
