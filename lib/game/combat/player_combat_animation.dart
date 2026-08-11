import 'package:patch_world/game/combat/player_weapon.dart';

enum PlayerCombatAnimation {
  attack1,
  attack2,
  attack3,
  attack4,
  attack5,
  attack6,
  parry,
  perfectParry,
  counter,
  abilityTransition;

  static PlayerCombatAnimation attackForIndex(int index) => switch (index) {
    1 => PlayerCombatAnimation.attack1,
    2 => PlayerCombatAnimation.attack2,
    3 => PlayerCombatAnimation.attack3,
    4 => PlayerCombatAnimation.attack4,
    5 => PlayerCombatAnimation.attack5,
    6 => PlayerCombatAnimation.attack6,
    _ => throw ArgumentError.value(index, 'index', 'must be in 1..6'),
  };

  String get assetSuffix => switch (this) {
    PlayerCombatAnimation.attack1 => 'attack-1',
    PlayerCombatAnimation.attack2 => 'attack-2',
    PlayerCombatAnimation.attack3 => 'attack-3',
    PlayerCombatAnimation.attack4 => 'attack-4',
    PlayerCombatAnimation.attack5 => 'attack-5',
    PlayerCombatAnimation.attack6 => 'attack-6',
    PlayerCombatAnimation.perfectParry => 'perfect-parry',
    PlayerCombatAnimation.abilityTransition => 'ability-transition',
    _ => name,
  };

  int get frameCount => 4;

  int get eventFrame => 0;

  double fps(PlayerWeapon weapon) => switch (this) {
    PlayerCombatAnimation.attack1 ||
    PlayerCombatAnimation.attack2 ||
    PlayerCombatAnimation.attack3 ||
    PlayerCombatAnimation.attack4 ||
    PlayerCombatAnimation.attack5 ||
    PlayerCombatAnimation.attack6 => switch (weapon) {
      PlayerWeapon.sword => 4 / PlayerWeapon.sword.baseCooldown,
      PlayerWeapon.gauntlet => 4 / PlayerWeapon.gauntlet.baseCooldown,
      PlayerWeapon.gun => 4 / PlayerWeapon.gun.baseCooldown,
    },
    PlayerCombatAnimation.parry => 12,
    PlayerCombatAnimation.perfectParry => 18,
    PlayerCombatAnimation.counter => 16,
    PlayerCombatAnimation.abilityTransition => switch (weapon) {
      PlayerWeapon.sword => 20,
      PlayerWeapon.gauntlet => 16.5,
      PlayerWeapon.gun => 14,
    },
  };

  int activeFrameEnd(PlayerWeapon weapon) => switch (this) {
    PlayerCombatAnimation.attack1 ||
    PlayerCombatAnimation.attack2 ||
    PlayerCombatAnimation.attack3 ||
    PlayerCombatAnimation.attack4 ||
    PlayerCombatAnimation.attack5 => weapon == PlayerWeapon.sword ? 1 : 0,
    PlayerCombatAnimation.attack6 => weapon == PlayerWeapon.gun ? 0 : 1,
    PlayerCombatAnimation.parry => 1,
    PlayerCombatAnimation.perfectParry ||
    PlayerCombatAnimation.abilityTransition => 0,
    PlayerCombatAnimation.counter => weapon == PlayerWeapon.gun ? 0 : 2,
  };
}

extension PlayerWeaponCombatAsset on PlayerWeapon {
  String combatAnimationAssetPath(PlayerCombatAnimation state) =>
      'sprites/art_v3/hero/$assetName-${state.assetSuffix}.png';
}
