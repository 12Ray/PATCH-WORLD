import 'package:patch_world/game/combat/player_weapon.dart';

final class EnemyBrainDecision {
  const EnemyBrainDecision(
    this.actionId,
    this.telegraph,
    this.active,
    this.recovery,
  );
  final String actionId;
  final double telegraph;
  final double active;
  final double recovery;
}

final class EnemyCombatContext {
  const EnemyCombatContext({
    required this.distance,
    required this.verticalDelta,
    required this.healthRatio,
    required this.playerGrounded,
    required this.playerWeapon,
    required this.nearbyAllies,
    required this.activeAllyAttackers,
    required this.formationSlot,
    required this.recentActionIds,
    required this.decisionSeed,
  });

  final double distance;
  final double verticalDelta;
  final double healthRatio;
  final bool playerGrounded;
  final PlayerWeapon playerWeapon;
  final int nearbyAllies;
  final int activeAllyAttackers;
  final int formationSlot;
  final List<String> recentActionIds;
  final int decisionSeed;
}

final class EnemyBrainSelection {
  const EnemyBrainSelection({
    required this.decision,
    required this.motionFrame,
  });

  final EnemyBrainDecision decision;
  final int motionFrame;
}

/// Data-driven brain catalog. Bespoke runtime effects remain in the host, but
/// selection and timing are owned by one immutable brain contract per enemy.
abstract final class PlatformerEnemyBrain {
  /// Five combat motions complete the ten-frame runtime contract:
  /// idle, move, telegraph, five attacks, hurt, and defeat.
  static List<EnemyBrainDecision> combatPattern(String name) {
    final signature = forArchetype(name);
    final motions = _additionalCombatMotions(name);
    return <EnemyBrainDecision>[
      signature,
      EnemyBrainDecision('$name.normal.${motions[0]}', .28, .10, .42),
      EnemyBrainDecision('$name.enhanced.${motions[1]}', .52, .16, .64),
      EnemyBrainDecision('$name.parryable.${motions[2]}', .72, .12, .58),
      EnemyBrainDecision('$name.special.${motions[3]}', .46, .22, .70),
    ];
  }

  /// Selects an attack from live combat context while staying deterministic
  /// enough for replays and tests. Recent attacks receive a strong penalty,
  /// so enemies no longer repeat a fixed five-step carousel.
  static EnemyBrainSelection chooseAction(
    String name,
    EnemyCombatContext context,
  ) {
    final pattern = combatPattern(name);
    var bestIndex = 0;
    var bestScore = -100000.0;
    for (var index = 0; index < pattern.length; index += 1) {
      final action = pattern[index];
      var score = ((context.decisionSeed + index * 3) % 7) * .08;
      if (context.recentActionIds.take(2).contains(action.actionId)) {
        score -= 8;
      }
      if (index == 0) {
        score += context.distance < 180 ? 2.8 : -.6;
      } else if (action.actionId.contains('.normal.')) {
        score += context.distance < 240 ? 2.0 : .3;
      } else if (action.actionId.contains('.enhanced.')) {
        score += context.distance >= 190 ? 2.3 : -.2;
      } else if (action.actionId.contains('.parryable.')) {
        score += !context.playerGrounded || context.verticalDelta > 45
            ? 2.4
            : .9;
      } else if (action.actionId.contains('.special.')) {
        score += context.healthRatio < .55 ? 2.7 : .5;
        if (context.verticalDelta > 70) score += 1.2;
      }
      score += _weaponResponseScore(
        actionIndex: index,
        actionId: action.actionId,
        weapon: context.playerWeapon,
      );
      score += _coordinationScore(
        actionIndex: index,
        actionId: action.actionId,
        nearbyAllies: context.nearbyAllies,
        activeAllyAttackers: context.activeAllyAttackers,
      );
      score += ((context.formationSlot + index) % 3) * .06;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = index;
      }
    }
    return EnemyBrainSelection(
      decision: pattern[bestIndex],
      motionFrame: 3 + bestIndex,
    );
  }

  static double _weaponResponseScore({
    required int actionIndex,
    required String actionId,
    required PlayerWeapon weapon,
  }) => switch (weapon) {
    // Sword players are strongest at a steady melee range. Enemies answer by
    // buying space or asking for a readable parry instead of body-stacking.
    PlayerWeapon.sword => switch (actionIndex) {
      0 => -.4,
      _ when actionId.contains('.normal.') => -.25,
      _ when actionId.contains('.enhanced.') => 1.25,
      _ when actionId.contains('.parryable.') => .5,
      _ => .65,
    },
    // Gauntlet players own the air and can double-jump over flat volleys.
    // Vertical/parryable patterns make that mobility part of the fight.
    PlayerWeapon.gauntlet => switch (actionIndex) {
      0 => .1,
      _ when actionId.contains('.normal.') => .25,
      _ when actionId.contains('.enhanced.') => .1,
      _ when actionId.contains('.parryable.') => 1.45,
      _ => .45,
    },
    // Gun players prefer long, safe lanes. An engager or quick normal pattern
    // pressures that lane while expensive ranged patterns become less common.
    PlayerWeapon.gun => switch (actionIndex) {
      0 => 1.4,
      _ when actionId.contains('.normal.') => .9,
      _ when actionId.contains('.enhanced.') => -.65,
      _ when actionId.contains('.parryable.') => -.15,
      _ => -.45,
    },
  };

  static double _coordinationScore({
    required int actionIndex,
    required String actionId,
    required int nearbyAllies,
    required int activeAllyAttackers,
  }) {
    if (activeAllyAttackers <= 0) {
      return actionIndex == 0 ? .6 : (actionId.contains('.normal.') ? .3 : 0);
    }
    var score = switch (actionIndex) {
      0 => -2.0,
      _ when actionId.contains('.normal.') => -.8,
      _ when actionId.contains('.enhanced.') => 1.0,
      _ when actionId.contains('.parryable.') => .55,
      _ => 1.3,
    };
    if (nearbyAllies >= 2 &&
        (actionId.contains('.enhanced.') || actionId.contains('.special.'))) {
      score += .25;
    }
    return score;
  }

  static List<String> _additionalCombatMotions(String name) => switch (name) {
    'patchMite' => const <String>[
      'pixelSpit',
      'burrowDash',
      'backplateGuard',
      'repairChipThrow',
    ],
    'checksumHopper' => const <String>[
      'landingShockwave',
      'checksumOrb',
      'wallRebound',
      'doubleStomp',
    ],
    'pulseTurret' => const <String>[
      'tripleBurst',
      'ricochetPulse',
      'mortarShot',
      'vent',
    ],
    'repairLeech' => const <String>[
      'siphonBite',
      'repairCapsule',
      'tetherPull',
      'emergencyShield',
    ],
    'overflowWarden' => const <String>[
      'summonLeech',
      'overflowGrenade',
      'shieldBash',
      'tankBurst',
    ],
    'tickRunner' => const <String>[
      'enhancedLunge',
      'parryableClockDisc',
      'timeMine',
      'afterimageDash',
    ],
    'echoBat' => const <String>[
      'enhancedSonicRing',
      'parryableEchoCrystal',
      'arcReplay',
      'blinkClone',
    ],
    'delaySniper' => const <String>[
      'enhancedRail',
      'parryableHourglass',
      'delayMine',
      'phaseRelocate',
    ],
    'rewindSkater' => const <String>[
      'enhancedChakram',
      'parryableRewindOrb',
      'rewind',
      'spinSlash',
    ],
    'chronoJailer' => const <String>[
      'enhancedSpearFan',
      'parryableClockCore',
      'timeCage',
      'coreBurst',
    ],
    'vectorRam' => const <String>[
      'enhancedCharge',
      'parryableArrowCore',
      'directionMine',
      'reverseImpact',
    ],
    'polarityDrone' => const <String>[
      'enhancedPushNova',
      'parryableSplitOrb',
      'magneticMine',
      'polarityDash',
    ],
    'phaseMimic' => const <String>[
      'enhancedBelowSnap',
      'parryablePhaseKey',
      'decoyPlatform',
      'ceilingDrop',
    ],
    'shardLobber' => const <String>[
      'enhancedCluster',
      'parryableCrystal',
      'gravityBomb',
      'shieldRetreat',
    ],
    'kernelChimera' => const <String>[
      'enhancedDualVolley',
      'parryableKernelDisc',
      'splitGrapple',
      'recombineShockwave',
    ],
    _ => throw ArgumentError.value(name, 'name', 'Unknown enemy archetype'),
  };

  static EnemyBrainDecision forArchetype(String name, {String? variant}) {
    return switch ((name, variant)) {
      ('patchMite', _) => const EnemyBrainDecision(
        'patchMite.bite',
        .30,
        .18,
        .55,
      ),
      ('checksumHopper', _) => const EnemyBrainDecision(
        'checksumHopper.leap',
        .45,
        .08,
        .65,
      ),
      ('pulseTurret', _) => const EnemyBrainDecision(
        'pulseTurret.lockedShot',
        .60,
        .08,
        .75,
      ),
      ('repairLeech', _) => const EnemyBrainDecision(
        'repairLeech.channel',
        .30,
        .12,
        .95,
      ),
      ('overflowWarden', 'summon') => const EnemyBrainDecision(
        'warden.summonLeech',
        .65,
        .10,
        .65,
      ),
      ('overflowWarden', 'guard') => const EnemyBrainDecision(
        'warden.guard',
        .25,
        .90,
        .40,
      ),
      ('overflowWarden', _) => const EnemyBrainDecision(
        'warden.slam',
        .75,
        .12,
        .80,
      ),
      ('tickRunner', _) => const EnemyBrainDecision(
        'tickRunner.threeStepLunge',
        .36,
        .28,
        .48,
      ),
      ('echoBat', _) => const EnemyBrainDecision(
        'echoBat.arcReplay',
        .52,
        .34,
        .62,
      ),
      ('delaySniper', _) => const EnemyBrainDecision(
        'delaySniper.lockedShot',
        .90,
        .08,
        .72,
      ),
      ('rewindSkater', 'rewind') => const EnemyBrainDecision(
        'rewindSkater.rewind',
        .34,
        .42,
        .52,
      ),
      ('rewindSkater', _) => const EnemyBrainDecision(
        'rewindSkater.dash',
        .28,
        .42,
        .40,
      ),
      ('chronoJailer', _) => const EnemyBrainDecision(
        'chronoJailer.clockSweep',
        .70,
        .20,
        .78,
      ),
      ('vectorRam', _) => const EnemyBrainDecision(
        'vectorRam.impactCharge',
        .48,
        .36,
        .68,
      ),
      ('polarityDrone', 'push') => const EnemyBrainDecision(
        'polarityDrone.pushField',
        .42,
        .18,
        .78,
      ),
      ('polarityDrone', _) => const EnemyBrainDecision(
        'polarityDrone.pullField',
        .42,
        .18,
        .78,
      ),
      ('phaseMimic', _) => const EnemyBrainDecision(
        'phaseMimic.belowSnap',
        .72,
        .16,
        .85,
      ),
      ('shardLobber', _) => const EnemyBrainDecision(
        'shardLobber.ricochet',
        .65,
        .08,
        .82,
      ),
      ('kernelChimera', _) => const EnemyBrainDecision(
        'kernelChimera.polarityCollision',
        .82,
        .24,
        .90,
      ),
      _ => throw ArgumentError.value(name, 'name', 'Unknown enemy archetype'),
    };
  }
}
