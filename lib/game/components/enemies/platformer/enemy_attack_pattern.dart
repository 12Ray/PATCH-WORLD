import 'package:patch_world/game/combat/attack_tier.dart';

enum EnemyActionSlot { normal, enhanced, parryable, special }

enum EnemyProjectilePattern { aimed, facing, fan, radial, ballistic }

enum EnemyDamagePlacement {
  attachedFront,
  selfCentered,
  groundAtSelf,
  targetCentered,
  targetBelow,
  historyTrail,
  crossAtSelf,
  crossAtTarget,
}

enum EnemyMovementMode {
  dashTowardTarget,
  dashAwayFromTarget,
  leapTowardTarget,
  teleportOppositeSide,
  teleportAboveTarget,
  rewindOldestPosition,
}

enum EnemyImpulseMode { pull, push }

enum EnemySupportMode { healSelf, healNearestAlly, summonLeech }

sealed class EnemyAttackEffectSpec {
  const EnemyAttackEffectSpec();

  String get mechanicalFingerprint;
}

final class EnemyProjectileEffectSpec extends EnemyAttackEffectSpec {
  const EnemyProjectileEffectSpec({
    required this.pattern,
    required this.tier,
    required this.speed,
    this.count = 1,
    this.spreadRadians = 0,
    this.verticalSpeed = 0,
    this.gravity = 0,
    this.bounces = 0,
    this.radius = 7,
    this.damage = 1,
    this.impactImpulse = 0,
  }) : assert(count > 0),
       assert(speed >= 0),
       assert(radius > 0),
       assert(damage >= 0);

  final EnemyProjectilePattern pattern;
  final AttackTier tier;
  final double speed;
  final int count;
  final double spreadRadians;
  final double verticalSpeed;
  final double gravity;
  final int bounces;
  final double radius;
  final int damage;

  /// Signed impulse applied along the projectile travel direction on hit.
  /// Negative values pull the player back toward the shooter.
  final double impactImpulse;

  @override
  String get mechanicalFingerprint =>
      'projectile:${pattern.name}:${tier.name}:$count:'
      '${speed.toStringAsFixed(1)}:${spreadRadians.toStringAsFixed(2)}:'
      '${verticalSpeed.toStringAsFixed(1)}:${gravity.toStringAsFixed(1)}:'
      '$bounces:${radius.toStringAsFixed(1)}:$damage:'
      '${impactImpulse.toStringAsFixed(1)}';
}

final class EnemyDamageEffectSpec extends EnemyAttackEffectSpec {
  const EnemyDamageEffectSpec({
    required this.placement,
    required this.width,
    required this.height,
    required this.activeSeconds,
    this.count = 1,
    this.spacing = 0,
    this.damage = 1,
  }) : assert(width > 0),
       assert(height > 0),
       assert(activeSeconds > 0),
       assert(count > 0),
       assert(damage > 0);

  final EnemyDamagePlacement placement;
  final double width;
  final double height;
  final double activeSeconds;
  final int count;
  final double spacing;
  final int damage;

  @override
  String get mechanicalFingerprint =>
      'damage:${placement.name}:${width.toStringAsFixed(1)}:'
      '${height.toStringAsFixed(1)}:${activeSeconds.toStringAsFixed(2)}:'
      '$count:${spacing.toStringAsFixed(1)}:$damage';
}

final class EnemyMovementEffectSpec extends EnemyAttackEffectSpec {
  const EnemyMovementEffectSpec({
    required this.mode,
    this.speed = 0,
    this.verticalSpeed = 0,
    this.distance = 0,
    this.landingEffect,
  });

  final EnemyMovementMode mode;
  final double speed;
  final double verticalSpeed;
  final double distance;
  final EnemyDamageEffectSpec? landingEffect;

  @override
  String get mechanicalFingerprint =>
      'movement:${mode.name}:${speed.toStringAsFixed(1)}:'
      '${verticalSpeed.toStringAsFixed(1)}:${distance.toStringAsFixed(1)}:'
      '${landingEffect?.mechanicalFingerprint ?? '-'}';
}

final class EnemyImpulseEffectSpec extends EnemyAttackEffectSpec {
  const EnemyImpulseEffectSpec({required this.mode, required this.strength})
    : assert(strength > 0);

  final EnemyImpulseMode mode;
  final double strength;

  @override
  String get mechanicalFingerprint =>
      'impulse:${mode.name}:${strength.toStringAsFixed(1)}';
}

final class EnemySupportEffectSpec extends EnemyAttackEffectSpec {
  const EnemySupportEffectSpec({required this.mode, this.amount = 1})
    : assert(amount > 0);

  final EnemySupportMode mode;
  final int amount;

  @override
  String get mechanicalFingerprint => 'support:${mode.name}:$amount';
}

final class EnemyAttackSpec {
  EnemyAttackSpec({
    required this.slot,
    required this.motionId,
    required this.telegraphSeconds,
    required this.activeSeconds,
    required this.recoverySeconds,
    required List<EnemyAttackEffectSpec> effects,
  }) : assert(telegraphSeconds >= 0),
       assert(activeSeconds > 0),
       assert(recoverySeconds >= 0),
       assert(effects.isNotEmpty),
       effects = List<EnemyAttackEffectSpec>.unmodifiable(effects);

  final EnemyActionSlot slot;
  final String motionId;
  final double telegraphSeconds;
  final double activeSeconds;
  final double recoverySeconds;
  final List<EnemyAttackEffectSpec> effects;

  String actionId(String archetypeName) =>
      '$archetypeName.${slot.name}.$motionId';

  String get mechanicalFingerprint =>
      '${slot.name}:${telegraphSeconds.toStringAsFixed(2)}:'
      '${activeSeconds.toStringAsFixed(2)}:'
      '${recoverySeconds.toStringAsFixed(2)}:'
      '${effects.map((effect) => effect.mechanicalFingerprint).join('|')}';

  bool get createsParryWindow => effects
      .whereType<EnemyProjectileEffectSpec>()
      .any((effect) => effect.tier == AttackTier.parryable);
}

final class EnemyCombatPatternProfile {
  EnemyCombatPatternProfile({
    required this.archetypeName,
    required this.familyId,
    required this.counterplayId,
    required List<EnemyAttackSpec> actions,
  }) : assert(actions.length == 4),
       assert(actions.map((action) => action.slot).toSet().length == 4),
       actions = List<EnemyAttackSpec>.unmodifiable(actions);

  final String archetypeName;
  final String familyId;
  final String counterplayId;
  final List<EnemyAttackSpec> actions;

  EnemyAttackSpec actionForSlot(EnemyActionSlot slot) =>
      actions.singleWhere((action) => action.slot == slot);

  EnemyAttackSpec? resolveAction(String actionId) {
    for (final action in actions) {
      if (action.actionId(archetypeName) == actionId) return action;
    }
    return null;
  }

  String get mechanicalFingerprint =>
      actions.map((action) => action.mechanicalFingerprint).join('||');
}

/// Immutable combat contracts for the fifteen campaign archetypes.
///
/// The connected campaign currently hosts twelve regular enemies through
/// `PlatformerEnemyComponent`; its three bosses use dedicated components. The
/// boss entries remain useful for legacy rooms and as a design contract, while
/// the dedicated boss runtime owns its authored phase logic.
abstract final class EnemyAttackPatternCatalog {
  static EnemyCombatPatternProfile forArchetype(String name) {
    final profile = _profiles[name];
    if (profile == null) {
      throw ArgumentError.value(name, 'name', 'Unknown enemy archetype');
    }
    return profile;
  }

  static List<EnemyCombatPatternProfile> get all =>
      List<EnemyCombatPatternProfile>.unmodifiable(_profiles.values);

  static EnemyAttackSpec _attack(
    EnemyActionSlot slot,
    String motionId,
    double telegraph,
    double active,
    double recovery,
    List<EnemyAttackEffectSpec> effects,
  ) => EnemyAttackSpec(
    slot: slot,
    motionId: motionId,
    telegraphSeconds: telegraph,
    activeSeconds: active,
    recoverySeconds: recovery,
    effects: effects,
  );

  static EnemyProjectileEffectSpec _shot(
    EnemyProjectilePattern pattern,
    AttackTier tier,
    double speed, {
    int count = 1,
    double spread = 0,
    double verticalSpeed = 0,
    double gravity = 0,
    int bounces = 0,
    double radius = 7,
    int? damage,
    double impactImpulse = 0,
  }) => EnemyProjectileEffectSpec(
    pattern: pattern,
    tier: tier,
    speed: speed,
    count: count,
    spreadRadians: spread,
    verticalSpeed: verticalSpeed,
    gravity: gravity,
    bounces: bounces,
    radius: radius,
    damage: damage ?? (tier == AttackTier.enhanced ? 2 : 1),
    impactImpulse: impactImpulse,
  );

  static EnemyDamageEffectSpec _damage(
    EnemyDamagePlacement placement,
    double width,
    double height,
    double seconds, {
    int count = 1,
    double spacing = 0,
    int damage = 1,
  }) => EnemyDamageEffectSpec(
    placement: placement,
    width: width,
    height: height,
    activeSeconds: seconds,
    count: count,
    spacing: spacing,
    damage: damage,
  );

  static EnemyMovementEffectSpec _move(
    EnemyMovementMode mode, {
    double speed = 0,
    double verticalSpeed = 0,
    double distance = 0,
    EnemyDamageEffectSpec? landing,
  }) => EnemyMovementEffectSpec(
    mode: mode,
    speed: speed,
    verticalSpeed: verticalSpeed,
    distance: distance,
    landingEffect: landing,
  );

  static EnemyImpulseEffectSpec _impulse(
    EnemyImpulseMode mode,
    double strength,
  ) => EnemyImpulseEffectSpec(mode: mode, strength: strength);

  static EnemySupportEffectSpec _support(
    EnemySupportMode mode, {
    int amount = 1,
  }) => EnemySupportEffectSpec(mode: mode, amount: amount);

  static final Map<String, EnemyCombatPatternProfile>
  _profiles = <String, EnemyCombatPatternProfile>{
    'patchMite': EnemyCombatPatternProfile(
      archetypeName: 'patchMite',
      familyId: 'burrow_ambusher',
      counterplayId: 'cross_over_and_punish_rear',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'pixelSpit', .24, .10, .36, [
          _shot(EnemyProjectilePattern.aimed, AttackTier.normal, 150),
        ]),
        _attack(EnemyActionSlot.enhanced, 'burrowDash', .42, .24, .50, [
          _move(EnemyMovementMode.dashTowardTarget, speed: 285),
          _damage(EnemyDamagePlacement.attachedFront, 78, 24, .24, damage: 2),
        ]),
        _attack(EnemyActionSlot.parryable, 'backplateGuard', .58, .14, .48, [
          _support(EnemySupportMode.healSelf),
          _shot(EnemyProjectilePattern.facing, AttackTier.parryable, 105),
        ]),
        _attack(EnemyActionSlot.special, 'repairChipThrow', .44, .18, .62, [
          _support(EnemySupportMode.healSelf),
          _shot(
            EnemyProjectilePattern.aimed,
            AttackTier.parryable,
            118,
            count: 2,
            spread: .16,
          ),
        ]),
      ],
    ),
    'checksumHopper': EnemyCombatPatternProfile(
      archetypeName: 'checksumHopper',
      familyId: 'landing_zone_controller',
      counterplayId: 'cross_under_then_punish_landing',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'landingShockwave', .38, .18, .48, [
          _move(
            EnemyMovementMode.leapTowardTarget,
            speed: 120,
            verticalSpeed: 430,
            landing: _damage(EnemyDamagePlacement.groundAtSelf, 140, 20, .18),
          ),
        ]),
        _attack(EnemyActionSlot.enhanced, 'checksumOrb', .50, .16, .58, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.enhanced,
            205,
            verticalSpeed: 310,
            gravity: 690,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'wallRebound', .62, .14, .54, [
          _shot(
            EnemyProjectilePattern.aimed,
            AttackTier.parryable,
            158,
            bounces: 3,
            radius: 8,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'doubleStomp', .46, .22, .68, [
          _damage(EnemyDamagePlacement.groundAtSelf, 116, 18, .16),
          _move(
            EnemyMovementMode.leapTowardTarget,
            speed: 145,
            verticalSpeed: 480,
            landing: _damage(
              EnemyDamagePlacement.groundAtSelf,
              188,
              24,
              .24,
              damage: 2,
            ),
          ),
        ]),
      ],
    ),
    'pulseTurret': EnemyCombatPatternProfile(
      archetypeName: 'pulseTurret',
      familyId: 'lane_ballistics_sentry',
      counterplayId: 'read_lane_then_change_height',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'tripleBurst', .32, .12, .44, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.normal,
            188,
            count: 3,
            spread: .055,
          ),
        ]),
        _attack(EnemyActionSlot.enhanced, 'ricochetPulse', .48, .18, .60, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.enhanced,
            202,
            count: 2,
            spread: .18,
            bounces: 2,
            radius: 9,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'mortarShot', .70, .16, .62, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            172,
            verticalSpeed: 340,
            gravity: 660,
            bounces: 1,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'vent', .40, .20, .72, [
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.normal,
            132,
            count: 8,
          ),
          _impulse(EnemyImpulseMode.push, 120),
        ]),
      ],
    ),
    'repairLeech': EnemyCombatPatternProfile(
      archetypeName: 'repairLeech',
      familyId: 'priority_support_tether',
      counterplayId: 'interrupt_support_before_overfill',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'siphonBite', .28, .16, .46, [
          _damage(EnemyDamagePlacement.attachedFront, 46, 28, .16),
          _support(EnemySupportMode.healSelf),
        ]),
        _attack(EnemyActionSlot.enhanced, 'repairCapsule', .54, .18, .74, [
          _support(EnemySupportMode.healNearestAlly, amount: 2),
        ]),
        _attack(EnemyActionSlot.parryable, 'tetherPull', .64, .18, .58, [
          _shot(
            EnemyProjectilePattern.aimed,
            AttackTier.parryable,
            126,
            radius: 8,
            impactImpulse: -230,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'emergencyShield', .48, .24, .76, [
          _support(EnemySupportMode.healSelf, amount: 2),
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.parryable,
            94,
            count: 4,
          ),
        ]),
      ],
    ),
    'overflowWarden': EnemyCombatPatternProfile(
      archetypeName: 'overflowWarden',
      familyId: 'guard_summon_slam',
      counterplayId: 'cross_guard_then_break_support',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'summonLeech', .58, .12, .68, [
          _support(EnemySupportMode.summonLeech),
        ]),
        _attack(EnemyActionSlot.enhanced, 'overflowGrenade', .52, .18, .66, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.enhanced,
            216,
            verticalSpeed: 300,
            gravity: 710,
            bounces: 1,
            radius: 11,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'shieldBash', .66, .20, .60, [
          _move(EnemyMovementMode.dashTowardTarget, speed: 205),
          _shot(
            EnemyProjectilePattern.facing,
            AttackTier.parryable,
            96,
            radius: 9,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'tankBurst', .60, .26, .82, [
          _damage(EnemyDamagePlacement.groundAtSelf, 310, 30, .26, damage: 2),
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.parryable,
            102,
            count: 6,
          ),
        ]),
      ],
    ),
    'tickRunner': EnemyCombatPatternProfile(
      archetypeName: 'tickRunner',
      familyId: 'rhythm_dash_duelist',
      counterplayId: 'count_three_beats_then_jump',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedLunge', .24, .28, .38, [
          _move(EnemyMovementMode.dashTowardTarget, speed: 335),
          _damage(EnemyDamagePlacement.attachedFront, 72, 24, .28),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableClockDisc', .44, .20, .54, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.enhanced,
            104,
            count: 2,
            spread: .18,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'timeMine', .60, .16, .56, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            128,
            verticalSpeed: 175,
            gravity: 480,
            bounces: 1,
            radius: 9,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'afterimageDash', .34, .30, .58, [
          _move(EnemyMovementMode.dashTowardTarget, speed: 420),
          _damage(EnemyDamagePlacement.historyTrail, 42, 24, .30, count: 3),
        ]),
      ],
    ),
    'echoBat': EnemyCombatPatternProfile(
      archetypeName: 'echoBat',
      familyId: 'player_path_replay',
      counterplayId: 'avoid_crossing_your_old_arc',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedSonicRing', .36, .18, .50, [
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.normal,
            114,
            count: 6,
          ),
        ]),
        _attack(
          EnemyActionSlot.enhanced,
          'parryableEchoCrystal',
          .50,
          .20,
          .62,
          [
            _shot(
              EnemyProjectilePattern.fan,
              AttackTier.enhanced,
              148,
              count: 3,
              spread: .24,
              radius: 9,
            ),
          ],
        ),
        _attack(EnemyActionSlot.parryable, 'arcReplay', .68, .20, .64, [
          _damage(EnemyDamagePlacement.historyTrail, 42, 42, .22, count: 3),
          _shot(EnemyProjectilePattern.aimed, AttackTier.parryable, 112),
        ]),
        _attack(EnemyActionSlot.special, 'blinkClone', .46, .24, .72, [
          _move(EnemyMovementMode.teleportOppositeSide, distance: 0),
          _damage(EnemyDamagePlacement.historyTrail, 38, 38, .30, count: 5),
        ]),
      ],
    ),
    'delaySniper': EnemyCombatPatternProfile(
      archetypeName: 'delaySniper',
      familyId: 'locked_snapshot_marksman',
      counterplayId: 'leave_locked_line_after_flash',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedRail', .46, .08, .52, [
          _shot(EnemyProjectilePattern.aimed, AttackTier.normal, 286),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableHourglass', .64, .16, .66, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.enhanced,
            108,
            count: 3,
            spread: .075,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'delayMine', .78, .14, .60, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            102,
            verticalSpeed: 145,
            gravity: 360,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'phaseRelocate', .42, .12, .68, [
          _move(EnemyMovementMode.teleportOppositeSide),
          _shot(EnemyProjectilePattern.aimed, AttackTier.normal, 224),
        ]),
      ],
    ),
    'rewindSkater': EnemyCombatPatternProfile(
      archetypeName: 'rewindSkater',
      familyId: 'self_route_rewind',
      counterplayId: 'vacate_the_recorded_lane',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedChakram', .30, .18, .44, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.normal,
            172,
            count: 2,
            spread: .30,
            bounces: 1,
          ),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableRewindOrb', .48, .22, .58, [
          _shot(
            EnemyProjectilePattern.aimed,
            AttackTier.enhanced,
            122,
            bounces: 2,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'rewind', .62, .24, .60, [
          _move(EnemyMovementMode.rewindOldestPosition),
          _damage(EnemyDamagePlacement.historyTrail, 48, 24, .26, count: 4),
          _shot(EnemyProjectilePattern.facing, AttackTier.parryable, 118),
        ]),
        _attack(EnemyActionSlot.special, 'spinSlash', .36, .28, .56, [
          _move(EnemyMovementMode.rewindOldestPosition),
          _damage(EnemyDamagePlacement.selfCentered, 158, 34, .28, damage: 2),
        ]),
      ],
    ),
    'chronoJailer': EnemyCombatPatternProfile(
      archetypeName: 'chronoJailer',
      familyId: 'clock_cage_controller',
      counterplayId: 'use_open_quadrant_then_reflect_core',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedSpearFan', .40, .18, .50, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.normal,
            212,
            count: 5,
            spread: .12,
          ),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableClockCore', .58, .22, .64, [
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.enhanced,
            124,
            count: 8,
            radius: 9,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'timeCage', .82, .24, .72, [
          _damage(EnemyDamagePlacement.crossAtTarget, 190, 30, .26),
          _shot(EnemyProjectilePattern.aimed, AttackTier.parryable, 92),
        ]),
        _attack(EnemyActionSlot.special, 'coreBurst', .54, .28, .78, [
          _damage(EnemyDamagePlacement.crossAtSelf, 240, 24, .28),
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.normal,
            132,
            count: 12,
          ),
        ]),
      ],
    ),
    'vectorRam': EnemyCombatPatternProfile(
      archetypeName: 'vectorRam',
      familyId: 'axis_charge_rebound',
      counterplayId: 'jump_axis_then_punish_rear',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedCharge', .32, .30, .46, [
          _move(EnemyMovementMode.dashTowardTarget, speed: 365),
          _damage(EnemyDamagePlacement.attachedFront, 98, 36, .30),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableArrowCore', .48, .18, .56, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.enhanced,
            232,
            count: 3,
            spread: .09,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'directionMine', .66, .16, .62, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            132,
            verticalSpeed: 195,
            gravity: 550,
            bounces: 1,
            radius: 9,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'reverseImpact', .40, .30, .66, [
          _move(EnemyMovementMode.dashAwayFromTarget, speed: 390),
          _damage(EnemyDamagePlacement.attachedFront, 126, 44, .30, damage: 2),
        ]),
      ],
    ),
    'polarityDrone': EnemyCombatPatternProfile(
      archetypeName: 'polarityDrone',
      familyId: 'push_pull_orbit',
      counterplayId: 'anchor_away_from_edges_and_reflect',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedPushNova', .36, .20, .52, [
          _impulse(EnemyImpulseMode.push, 190),
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.normal,
            116,
            count: 6,
          ),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableSplitOrb', .52, .20, .62, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.enhanced,
            162,
            count: 2,
            spread: .40,
            impactImpulse: -110,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'magneticMine', .72, .18, .64, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            116,
            verticalSpeed: 185,
            gravity: 460,
            radius: 10,
            impactImpulse: -245,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'polarityDash', .42, .26, .68, [
          _move(EnemyMovementMode.dashTowardTarget, speed: 260),
          _impulse(EnemyImpulseMode.push, 270),
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.parryable,
            98,
            count: 4,
          ),
        ]),
      ],
    ),
    'phaseMimic': EnemyCombatPatternProfile(
      archetypeName: 'phaseMimic',
      familyId: 'false_floor_ambush',
      counterplayId: 'keep_horizontal_motion_after_weight_tell',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedBelowSnap', .46, .16, .54, [
          _damage(EnemyDamagePlacement.targetBelow, 66, 94, .18),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryablePhaseKey', .56, .18, .62, [
          _move(EnemyMovementMode.teleportAboveTarget, distance: 128),
          _shot(
            EnemyProjectilePattern.aimed,
            AttackTier.enhanced,
            186,
            count: 2,
            spread: .12,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'decoyPlatform', .76, .18, .70, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            94,
            count: 2,
            spread: .28,
            verticalSpeed: 90,
            gravity: 250,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'ceilingDrop', .52, .24, .76, [
          _move(EnemyMovementMode.teleportAboveTarget, distance: 138),
          _damage(EnemyDamagePlacement.targetCentered, 50, 158, .24, damage: 2),
        ]),
      ],
    ),
    'shardLobber': EnemyCombatPatternProfile(
      archetypeName: 'shardLobber',
      familyId: 'terrain_ricochet_artillery',
      counterplayId: 'track_second_bounce_not_first_arc',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedCluster', .40, .16, .52, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.normal,
            166,
            count: 3,
            spread: .30,
            verticalSpeed: 285,
            gravity: 620,
            bounces: 1,
          ),
        ]),
        _attack(EnemyActionSlot.enhanced, 'parryableCrystal', .54, .20, .64, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.enhanced,
            154,
            count: 2,
            spread: .24,
            bounces: 2,
            radius: 10,
          ),
        ]),
        _attack(EnemyActionSlot.parryable, 'gravityBomb', .72, .18, .68, [
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            118,
            verticalSpeed: 270,
            gravity: 830,
            bounces: 1,
            radius: 11,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'shieldRetreat', .44, .22, .70, [
          _move(EnemyMovementMode.dashAwayFromTarget, speed: 190),
          _shot(
            EnemyProjectilePattern.ballistic,
            AttackTier.parryable,
            124,
            verticalSpeed: 220,
            gravity: 390,
            bounces: 1,
          ),
        ]),
      ],
    ),
    'kernelChimera': EnemyCombatPatternProfile(
      archetypeName: 'kernelChimera',
      familyId: 'split_merge_polarity',
      counterplayId: 'align_halves_then_strike_exposed_core',
      actions: <EnemyAttackSpec>[
        _attack(EnemyActionSlot.normal, 'enhancedDualVolley', .38, .20, .52, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.normal,
            222,
            count: 4,
            spread: .20,
          ),
        ]),
        _attack(
          EnemyActionSlot.enhanced,
          'parryableKernelDisc',
          .54,
          .24,
          .66,
          [
            _shot(
              EnemyProjectilePattern.radial,
              AttackTier.enhanced,
              134,
              count: 10,
              radius: 9,
            ),
          ],
        ),
        _attack(EnemyActionSlot.parryable, 'splitGrapple', .72, .22, .70, [
          _shot(
            EnemyProjectilePattern.fan,
            AttackTier.parryable,
            132,
            count: 2,
            spread: .34,
            impactImpulse: -225,
          ),
        ]),
        _attack(EnemyActionSlot.special, 'recombineShockwave', .60, .28, .82, [
          _damage(EnemyDamagePlacement.groundAtSelf, 340, 38, .28, damage: 2),
          _shot(
            EnemyProjectilePattern.radial,
            AttackTier.enhanced,
            142,
            count: 10,
          ),
        ]),
      ],
    ),
  };
}
