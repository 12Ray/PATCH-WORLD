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

  int get eventFrame => switch (this) {
    PlayerCombatAnimation.attack1 ||
    PlayerCombatAnimation.attack2 ||
    PlayerCombatAnimation.attack3 ||
    PlayerCombatAnimation.attack4 ||
    PlayerCombatAnimation.attack5 ||
    PlayerCombatAnimation.attack6 ||
    PlayerCombatAnimation.counter => 1,
    _ => 0,
  };

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

/// One timing source for the visible clip, legal retrigger, and gameplay hit.
///
/// Build/item modifiers can shorten the weapon interval. Keeping the authored
/// four phases inside the same derived duration prevents a new attack from
/// resetting the previous clip before its recovery frame is shown. The 30 FPS
/// ceiling also keeps longer composed actions readable instead of skipping
/// most of their frames in one update.
final class PlayerCombatPlaybackContract {
  const PlayerCombatPlaybackContract._({
    required this.state,
    required this.effectiveIntervalSeconds,
    required this.durationSeconds,
    required this.frameCount,
    required this.eventFrame,
  });

  factory PlayerCombatPlaybackContract.forAction({
    required PlayerCombatAnimation state,
    required double effectiveIntervalSeconds,
    int? frameCount,
    int? eventFrame,
  }) {
    final resolvedFrameCount = frameCount ?? state.frameCount;
    final resolvedEventFrame = eventFrame ?? state.eventFrame;
    if (!effectiveIntervalSeconds.isFinite || effectiveIntervalSeconds <= 0) {
      throw ArgumentError.value(
        effectiveIntervalSeconds,
        'effectiveIntervalSeconds',
        'must be finite and greater than zero',
      );
    }
    if (resolvedFrameCount <= 0) {
      throw ArgumentError.value(frameCount, 'frameCount', 'must be positive');
    }
    if (resolvedEventFrame < 0 || resolvedEventFrame >= resolvedFrameCount) {
      throw ArgumentError.value(
        eventFrame,
        'eventFrame',
        'must address a frame in the clip',
      );
    }
    final minimumDuration = resolvedFrameCount / maximumPlaybackFps;
    final duration = effectiveIntervalSeconds < minimumDuration
        ? minimumDuration
        : effectiveIntervalSeconds;
    return PlayerCombatPlaybackContract._(
      state: state,
      effectiveIntervalSeconds: effectiveIntervalSeconds,
      durationSeconds: duration,
      frameCount: resolvedFrameCount,
      eventFrame: resolvedEventFrame,
    );
  }

  static const double maximumPlaybackFps = 30;

  final PlayerCombatAnimation state;
  final double effectiveIntervalSeconds;
  final double durationSeconds;
  final int frameCount;
  final int eventFrame;

  double get secondsPerFrame => durationSeconds / frameCount;
  double get fps => frameCount / durationSeconds;
  double get impactDelaySeconds => eventFrame * secondsPerFrame;
}

extension PlayerWeaponCombatAsset on PlayerWeapon {
  String combatAnimationAssetPath(PlayerCombatAnimation state) =>
      'sprites/art_v3/hero/$assetName-${state.assetSuffix}.png';
}

List<T> composeAbilityMotionFrames<T>({
  required List<T> abilityFrames,
  List<T>? transitionFrames,
  List<T>? authoredActionFrames,
}) {
  final transition = transitionFrames ?? const <Never>[];
  return <T>[
    ...?authoredActionFrames,
    if (transition.isNotEmpty) transition.first,
    ...abilityFrames,
    if (transition.length > 1) ...transition.skip(1),
  ];
}
