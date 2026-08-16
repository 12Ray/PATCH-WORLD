import 'dart:math' as math;

import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/combat/player_weapon.dart';

enum SurvivalItemTag {
  attack,
  dash,
  parry,
  projectile,
  explosion,
  sustain,
  mobility,
}

extension SurvivalItemTagSpec on SurvivalItemTag {
  String get localizationKey => 'survivalItemTag.$name';
}

enum SurvivalItemId {
  // Sword pool.
  phaseWhetstone,
  blinkSheath,
  riposteCoil,
  fractureEdge,
  pursuitSigil,
  guardRecompiler,

  // Gauntlet pool.
  kineticWraps,
  quakeAmplifier,
  magnetKnuckle,
  counterweight,
  aftershockFork,
  impactReservoir,

  // Gun pool.
  railCapacitor,
  splitProtocol,
  ricochetLens,
  blastChamber,
  hunterDrone,
  snapLoader,

  // Shared pool. The final three expand through campaign exploration unlocks.
  recursiveTrigger,
  mirrorGuard,
  volatileKernel,
  wallScript,
  ghostStep,
  terrainCompiler,
}

final class SurvivalItemDefinition {
  const SurvivalItemDefinition({
    required this.id,
    required this.tags,
    this.weapon,
    this.requiredAbility,
  });

  final SurvivalItemId id;
  final PlayerWeapon? weapon;
  final Set<SurvivalItemTag> tags;
  final CampaignTraversalAbility? requiredAbility;

  String get localizationPrefix => 'survivalItem.${id.name}';
  bool supports(PlayerWeapon selectedWeapon) =>
      weapon == null || weapon == selectedWeapon;
}

enum SurvivalItemRewardSource { regionEvent, regionBoss, nexusBoss }

extension SurvivalItemRewardSourceSpec on SurvivalItemRewardSource {
  String get localizationKey => 'survivalItemReward.$name';
}

final class SurvivalItemRewardRequest {
  const SurvivalItemRewardRequest({
    required this.source,
    required this.choices,
  });

  final SurvivalItemRewardSource source;
  final List<SurvivalItemId> choices;
}

final class SurvivalBuildRecipe {
  const SurvivalBuildRecipe({
    required this.id,
    required this.weapon,
    required this.coreItems,
    required this.primaryTags,
  });

  final String id;
  final PlayerWeapon weapon;
  final List<SurvivalItemId> coreItems;
  final Set<SurvivalItemTag> primaryTags;
}

abstract final class SurvivalItemCatalog {
  static const List<SurvivalItemDefinition> all = <SurvivalItemDefinition>[
    SurvivalItemDefinition(
      id: SurvivalItemId.phaseWhetstone,
      weapon: PlayerWeapon.sword,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.blinkSheath,
      weapon: PlayerWeapon.sword,
      tags: <SurvivalItemTag>{SurvivalItemTag.dash, SurvivalItemTag.mobility},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.riposteCoil,
      weapon: PlayerWeapon.sword,
      tags: <SurvivalItemTag>{SurvivalItemTag.parry, SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.fractureEdge,
      weapon: PlayerWeapon.sword,
      tags: <SurvivalItemTag>{
        SurvivalItemTag.attack,
        SurvivalItemTag.explosion,
      },
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.pursuitSigil,
      weapon: PlayerWeapon.sword,
      tags: <SurvivalItemTag>{SurvivalItemTag.dash, SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.guardRecompiler,
      weapon: PlayerWeapon.sword,
      tags: <SurvivalItemTag>{SurvivalItemTag.parry, SurvivalItemTag.sustain},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.kineticWraps,
      weapon: PlayerWeapon.gauntlet,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.quakeAmplifier,
      weapon: PlayerWeapon.gauntlet,
      tags: <SurvivalItemTag>{SurvivalItemTag.explosion},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.magnetKnuckle,
      weapon: PlayerWeapon.gauntlet,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack, SurvivalItemTag.mobility},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.counterweight,
      weapon: PlayerWeapon.gauntlet,
      tags: <SurvivalItemTag>{SurvivalItemTag.parry, SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.aftershockFork,
      weapon: PlayerWeapon.gauntlet,
      tags: <SurvivalItemTag>{
        SurvivalItemTag.attack,
        SurvivalItemTag.explosion,
      },
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.impactReservoir,
      weapon: PlayerWeapon.gauntlet,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack, SurvivalItemTag.sustain},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.railCapacitor,
      weapon: PlayerWeapon.gun,
      tags: <SurvivalItemTag>{
        SurvivalItemTag.projectile,
        SurvivalItemTag.attack,
      },
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.splitProtocol,
      weapon: PlayerWeapon.gun,
      tags: <SurvivalItemTag>{SurvivalItemTag.projectile},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.ricochetLens,
      weapon: PlayerWeapon.gun,
      tags: <SurvivalItemTag>{SurvivalItemTag.projectile},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.blastChamber,
      weapon: PlayerWeapon.gun,
      tags: <SurvivalItemTag>{
        SurvivalItemTag.projectile,
        SurvivalItemTag.explosion,
      },
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.hunterDrone,
      weapon: PlayerWeapon.gun,
      tags: <SurvivalItemTag>{
        SurvivalItemTag.projectile,
        SurvivalItemTag.attack,
      },
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.snapLoader,
      weapon: PlayerWeapon.gun,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.recursiveTrigger,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.mirrorGuard,
      tags: <SurvivalItemTag>{SurvivalItemTag.parry, SurvivalItemTag.sustain},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.volatileKernel,
      tags: <SurvivalItemTag>{SurvivalItemTag.explosion},
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.wallScript,
      tags: <SurvivalItemTag>{SurvivalItemTag.attack, SurvivalItemTag.mobility},
      requiredAbility: CampaignTraversalAbility.wallJump,
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.ghostStep,
      tags: <SurvivalItemTag>{SurvivalItemTag.dash, SurvivalItemTag.mobility},
      requiredAbility: CampaignTraversalAbility.airDash,
    ),
    SurvivalItemDefinition(
      id: SurvivalItemId.terrainCompiler,
      tags: <SurvivalItemTag>{
        SurvivalItemTag.projectile,
        SurvivalItemTag.explosion,
      },
      requiredAbility: CampaignTraversalAbility.terrainPulse,
    ),
  ];

  static const List<SurvivalBuildRecipe> recommendedBuilds =
      <SurvivalBuildRecipe>[
        SurvivalBuildRecipe(
          id: 'sword.edgeCascade',
          weapon: PlayerWeapon.sword,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.phaseWhetstone,
            SurvivalItemId.fractureEdge,
            SurvivalItemId.recursiveTrigger,
            SurvivalItemId.volatileKernel,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.attack,
            SurvivalItemTag.explosion,
          },
        ),
        SurvivalBuildRecipe(
          id: 'sword.riftPredator',
          weapon: PlayerWeapon.sword,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.blinkSheath,
            SurvivalItemId.pursuitSigil,
            SurvivalItemId.ghostStep,
            SurvivalItemId.wallScript,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.dash,
            SurvivalItemTag.mobility,
          },
        ),
        SurvivalBuildRecipe(
          id: 'sword.counterKernel',
          weapon: PlayerWeapon.sword,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.riposteCoil,
            SurvivalItemId.guardRecompiler,
            SurvivalItemId.mirrorGuard,
            SurvivalItemId.recursiveTrigger,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.parry,
            SurvivalItemTag.sustain,
          },
        ),
        SurvivalBuildRecipe(
          id: 'gauntlet.seismicLoop',
          weapon: PlayerWeapon.gauntlet,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.quakeAmplifier,
            SurvivalItemId.aftershockFork,
            SurvivalItemId.kineticWraps,
            SurvivalItemId.terrainCompiler,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.explosion,
            SurvivalItemTag.attack,
          },
        ),
        SurvivalBuildRecipe(
          id: 'gauntlet.pressureEngine',
          weapon: PlayerWeapon.gauntlet,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.kineticWraps,
            SurvivalItemId.magnetKnuckle,
            SurvivalItemId.impactReservoir,
            SurvivalItemId.recursiveTrigger,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.attack,
            SurvivalItemTag.sustain,
          },
        ),
        SurvivalBuildRecipe(
          id: 'gauntlet.counterBrawler',
          weapon: PlayerWeapon.gauntlet,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.counterweight,
            SurvivalItemId.impactReservoir,
            SurvivalItemId.mirrorGuard,
            SurvivalItemId.kineticWraps,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.parry,
            SurvivalItemTag.attack,
          },
        ),
        SurvivalBuildRecipe(
          id: 'gun.railNetwork',
          weapon: PlayerWeapon.gun,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.railCapacitor,
            SurvivalItemId.ricochetLens,
            SurvivalItemId.hunterDrone,
            SurvivalItemId.recursiveTrigger,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.projectile,
            SurvivalItemTag.attack,
          },
        ),
        SurvivalBuildRecipe(
          id: 'gun.shrapnelCompiler',
          weapon: PlayerWeapon.gun,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.blastChamber,
            SurvivalItemId.splitProtocol,
            SurvivalItemId.volatileKernel,
            SurvivalItemId.terrainCompiler,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.projectile,
            SurvivalItemTag.explosion,
          },
        ),
        SurvivalBuildRecipe(
          id: 'gun.reflexVolley',
          weapon: PlayerWeapon.gun,
          coreItems: <SurvivalItemId>[
            SurvivalItemId.snapLoader,
            SurvivalItemId.hunterDrone,
            SurvivalItemId.mirrorGuard,
            SurvivalItemId.ricochetLens,
          ],
          primaryTags: <SurvivalItemTag>{
            SurvivalItemTag.attack,
            SurvivalItemTag.parry,
            SurvivalItemTag.projectile,
          },
        ),
      ];

  static SurvivalItemDefinition definition(SurvivalItemId id) =>
      all.firstWhere((definition) => definition.id == id);

  static List<SurvivalItemId> choices({
    required PlayerWeapon weapon,
    required Set<SurvivalItemId> owned,
    required Set<CampaignTraversalAbility> unlockedAbilities,
    required int rewardIndex,
  }) {
    final available = all
        .where(
          (definition) =>
              definition.supports(weapon) &&
              !owned.contains(definition.id) &&
              (definition.requiredAbility == null ||
                  unlockedAbilities.contains(definition.requiredAbility)),
        )
        .toList(growable: false);
    if (available.isEmpty) return const <SurvivalItemId>[];

    final weaponItems = available
        .where((definition) => definition.weapon == weapon)
        .toList(growable: false);
    final sharedItems = available
        .where((definition) => definition.weapon == null)
        .toList(growable: false);
    final choices = <SurvivalItemId>[];
    final preferTwoWeaponItems = rewardIndex.isEven;
    _takeRotated(
      choices,
      weaponItems,
      count: preferTwoWeaponItems ? 2 : 1,
      offset: rewardIndex,
    );
    _takeRotated(
      choices,
      sharedItems,
      count: preferTwoWeaponItems ? 1 : 2,
      offset: rewardIndex * 2 + 1,
    );
    _takeRotated(
      choices,
      available,
      count: 3 - choices.length,
      offset: rewardIndex * 3 + 2,
    );
    return List<SurvivalItemId>.unmodifiable(choices);
  }

  static void _takeRotated(
    List<SurvivalItemId> target,
    List<SurvivalItemDefinition> source, {
    required int count,
    required int offset,
  }) {
    if (count <= 0 || source.isEmpty) return;
    for (var step = 0; step < source.length && count > 0; step += 1) {
      final definition = source[(offset + step) % source.length];
      if (target.contains(definition.id)) continue;
      target.add(definition.id);
      count -= 1;
    }
  }
}

/// Run-local item layer. Items stay binary so their power comes from authored
/// combinations and tag thresholds rather than repeatable permanent stats.
final class SurvivalItemBuildState {
  final Set<SurvivalItemId> _items = <SurvivalItemId>{};
  int rewardIndex = 0;
  int perfectParries = 0;

  Set<SurvivalItemId> get items => Set<SurvivalItemId>.unmodifiable(_items);
  bool contains(SurvivalItemId id) => _items.contains(id);
  bool acquire(SurvivalItemId id) => _items.add(id);

  int tagCount(SurvivalItemTag tag) => _items
      .where((id) => SurvivalItemCatalog.definition(id).tags.contains(tag))
      .length;

  int synergyTier(SurvivalItemTag tag) {
    final count = tagCount(tag);
    if (count >= 4) return 2;
    if (count >= 2) return 1;
    return 0;
  }

  Map<SurvivalItemTag, int> get activeSynergyTiers => <SurvivalItemTag, int>{
    for (final tag in SurvivalItemTag.values)
      if (synergyTier(tag) > 0) tag: synergyTier(tag),
  };

  int damageBonusFor(
    PlayerWeapon weapon, {
    required int motionIndex,
    required bool counter,
  }) {
    var bonus = synergyTier(SurvivalItemTag.attack);
    if (counter && contains(SurvivalItemId.mirrorGuard)) bonus += 1;
    switch (weapon) {
      case PlayerWeapon.sword:
        if ((motionIndex == 4 || motionIndex == 6) &&
            contains(SurvivalItemId.phaseWhetstone)) {
          bonus += 1;
        }
        if (counter && contains(SurvivalItemId.riposteCoil)) bonus += 1;
      case PlayerWeapon.gauntlet:
        if (motionIndex % 3 == 0 && contains(SurvivalItemId.kineticWraps)) {
          bonus += 1;
        }
        if (counter && contains(SurvivalItemId.counterweight)) bonus += 1;
      case PlayerWeapon.gun:
        if (motionIndex == 4 && contains(SurvivalItemId.railCapacitor)) {
          bonus += 1;
        }
    }
    return bonus;
  }

  double attackCooldownMultiplierFor(PlayerWeapon weapon) {
    var multiplier = switch (synergyTier(SurvivalItemTag.attack)) {
      2 => .90,
      1 => .95,
      _ => 1.0,
    };
    if (contains(SurvivalItemId.recursiveTrigger)) multiplier *= .94;
    if (weapon == PlayerWeapon.gauntlet &&
        contains(SurvivalItemId.impactReservoir)) {
      multiplier *= .90;
    }
    if (weapon == PlayerWeapon.gun && contains(SurvivalItemId.snapLoader)) {
      multiplier *= .88;
    }
    return multiplier.clamp(.70, 1).toDouble();
  }

  double specialCooldownMultiplierFor(PlayerWeapon weapon) {
    var multiplier = switch (synergyTier(SurvivalItemTag.dash)) {
      2 => .84,
      1 => .92,
      _ => 1.0,
    };
    if (weapon == PlayerWeapon.sword && contains(SurvivalItemId.pursuitSigil)) {
      multiplier *= .88;
    }
    if (contains(SurvivalItemId.ghostStep)) multiplier *= .90;
    return multiplier.clamp(.68, 1).toDouble();
  }

  double get parryWindowMultiplier =>
      1 +
      synergyTier(SurvivalItemTag.parry) * .20 +
      (contains(SurvivalItemId.mirrorGuard) ? .25 : 0) +
      (contains(SurvivalItemId.guardRecompiler) ? .15 : 0);

  double get parryRecoveryMultiplier =>
      (1 - synergyTier(SurvivalItemTag.parry) * .10).clamp(.75, 1);

  bool recordPerfectParryAndShouldHeal() {
    perfectParries += 1;
    return contains(SurvivalItemId.guardRecompiler) && perfectParries % 3 == 0;
  }

  double get swordReachMultiplier =>
      1 + (contains(SurvivalItemId.wallScript) ? .16 : 0);
  double get gauntletReachMultiplier =>
      1 +
      (contains(SurvivalItemId.magnetKnuckle) ? .22 : 0) +
      (contains(SurvivalItemId.wallScript) ? .10 : 0);
  double get swordSpecialDistanceBonus =>
      (contains(SurvivalItemId.blinkSheath) ? 36 : 0) +
      synergyTier(SurvivalItemTag.dash) * 12;
  int get swordSpecialDamageBonus =>
      contains(SurvivalItemId.pursuitSigil) ? 1 : 0;
  double get gauntletQuakeRadiusBonus =>
      (contains(SurvivalItemId.quakeAmplifier) ? 32 : 0) +
      (contains(SurvivalItemId.wallScript) ? 16 : 0);
  int get gauntletQuakeDamageBonus =>
      contains(SurvivalItemId.aftershockFork) ? 1 : 0;

  int get gunBonusShots =>
      (contains(SurvivalItemId.splitProtocol) ? 1 : 0) +
      (contains(SurvivalItemId.hunterDrone) ? 1 : 0) +
      (synergyTier(SurvivalItemTag.projectile) >= 2 ? 1 : 0);
  int get gunBonusHits =>
      (contains(SurvivalItemId.ricochetLens) ? 1 : 0) +
      (synergyTier(SurvivalItemTag.projectile) >= 2 ? 1 : 0);
  double get gunRicochetRadians =>
      contains(SurvivalItemId.ricochetLens) ? .22 : 0;
  double get gunProjectileSpeedMultiplier =>
      1 + synergyTier(SurvivalItemTag.projectile) * .10;

  double explosionRadiusFor(PlayerWeapon weapon, {required bool heavy}) {
    if (!heavy) {
      if (weapon == PlayerWeapon.gun &&
          (contains(SurvivalItemId.blastChamber) ||
              contains(SurvivalItemId.terrainCompiler))) {
        return 42 + synergyTier(SurvivalItemTag.explosion) * 10;
      }
      return 0;
    }
    final enabled = switch (weapon) {
      PlayerWeapon.sword => contains(SurvivalItemId.fractureEdge),
      PlayerWeapon.gauntlet => contains(SurvivalItemId.aftershockFork),
      PlayerWeapon.gun =>
        contains(SurvivalItemId.blastChamber) ||
            contains(SurvivalItemId.terrainCompiler),
    };
    if (!enabled) return 0;
    return 54 + synergyTier(SurvivalItemTag.explosion) * 12;
  }

  int get explosionDamage =>
      1 +
      synergyTier(SurvivalItemTag.explosion) +
      (contains(SurvivalItemId.volatileKernel) ? 1 : 0);

  List<SurvivalItemId> choices({
    required PlayerWeapon weapon,
    required Set<CampaignTraversalAbility> unlockedAbilities,
  }) => SurvivalItemCatalog.choices(
    weapon: weapon,
    owned: _items,
    unlockedAbilities: unlockedAbilities,
    rewardIndex: rewardIndex,
  );

  void advanceReward() => rewardIndex += 1;

  void reset() {
    _items.clear();
    rewardIndex = 0;
    perfectParries = 0;
  }

  /// A compact score used only by deterministic balance tests. It deliberately
  /// rewards several tags instead of one universally dominant item.
  int buildPotentialFor(PlayerWeapon weapon) {
    final weaponItems = _items.where(
      (id) => SurvivalItemCatalog.definition(id).supports(weapon),
    );
    final activeTags = SurvivalItemTag.values.where(
      (tag) => synergyTier(tag) > 0,
    );
    return weaponItems.length * 2 +
        activeTags.length * 3 +
        math.min(2, synergyTier(SurvivalItemTag.attack));
  }
}
