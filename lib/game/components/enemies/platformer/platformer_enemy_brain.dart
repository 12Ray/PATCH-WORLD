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

/// Data-driven brain catalog. Bespoke runtime effects remain in the host, but
/// selection and timing are owned by one immutable brain contract per enemy.
abstract final class PlatformerEnemyBrain {
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
