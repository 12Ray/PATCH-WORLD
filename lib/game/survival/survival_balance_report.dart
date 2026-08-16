import 'dart:math' as math;

import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

final class SurvivalPlaytestRecord {
  const SurvivalPlaytestRecord({
    required this.recordedAtEpochMs,
    required this.weapon,
    required this.elapsedSeconds,
    required this.finalBossDefeated,
    required this.deathCauseId,
    required this.damageByCause,
    required this.patchIds,
    required this.itemIds,
    required this.weaponBuildTiers,
    required this.completedWeaponBuilds,
    required this.visitedRegionCount,
    required this.regionEventsCompleted,
    required this.survivalBossesDefeated,
  });

  factory SurvivalPlaytestRecord.fromResult(
    SurvivalResultSnapshot result, {
    DateTime? recordedAt,
  }) => SurvivalPlaytestRecord(
    recordedAtEpochMs: (recordedAt ?? DateTime.now()).millisecondsSinceEpoch,
    weapon: result.selectedWeapon,
    elapsedSeconds: result.elapsedSeconds,
    finalBossDefeated: result.finalBossDefeated,
    deathCauseId: result.deathCauseId,
    damageByCause: Map<String, int>.unmodifiable(result.damageByCause),
    patchIds: Set<String>.unmodifiable(result.patchTiers.keys),
    itemIds: Set<String>.unmodifiable(result.itemIds),
    weaponBuildTiers: Map<String, int>.unmodifiable(result.weaponBuildTiers),
    completedWeaponBuilds: result.completedWeaponBuilds,
    visitedRegionCount: result.visitedRegionCount,
    regionEventsCompleted: result.regionEventsCompleted,
    survivalBossesDefeated: result.survivalBossesDefeated,
  );

  factory SurvivalPlaytestRecord.fromJson(Map<String, Object?> json) {
    final damage = <String, int>{};
    final rawDamage = json['damageByCause'];
    if (rawDamage is Map) {
      for (final entry in rawDamage.entries) {
        if (entry.key is String && entry.value is num) {
          damage[entry.key as String] = (entry.value as num).round();
        }
      }
    }
    return SurvivalPlaytestRecord(
      recordedAtEpochMs: (json['recordedAtEpochMs'] as num).round(),
      weapon: PlayerWeapon.values.byName(json['weapon'] as String),
      elapsedSeconds: (json['elapsedSeconds'] as num).toDouble(),
      finalBossDefeated: json['finalBossDefeated'] as bool,
      deathCauseId: json['deathCauseId'] as String,
      damageByCause: Map<String, int>.unmodifiable(damage),
      patchIds: Set<String>.unmodifiable(
        (json['patchIds'] as List).whereType<String>(),
      ),
      itemIds: Set<String>.unmodifiable(
        (json['itemIds'] as List).whereType<String>(),
      ),
      weaponBuildTiers: Map<String, int>.unmodifiable(
        _integerMap(json['weaponBuildTiers']),
      ),
      completedWeaponBuilds: (json['completedWeaponBuilds'] as num).round(),
      visitedRegionCount: (json['visitedRegionCount'] as num).round(),
      regionEventsCompleted: (json['regionEventsCompleted'] as num).round(),
      survivalBossesDefeated: (json['survivalBossesDefeated'] as num).round(),
    );
  }

  final int recordedAtEpochMs;
  final PlayerWeapon weapon;
  final double elapsedSeconds;
  final bool finalBossDefeated;
  final String deathCauseId;
  final Map<String, int> damageByCause;
  final Set<String> patchIds;
  final Set<String> itemIds;
  final Map<String, int> weaponBuildTiers;
  final int completedWeaponBuilds;
  final int visitedRegionCount;
  final int regionEventsCompleted;
  final int survivalBossesDefeated;

  bool get completed => finalBossDefeated;
  bool get metRegionEngagement =>
      visitedRegionCount >= 3 && regionEventsCompleted >= 2;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'recordedAtEpochMs': recordedAtEpochMs,
    'weapon': weapon.name,
    'elapsedSeconds': elapsedSeconds,
    'finalBossDefeated': finalBossDefeated,
    'deathCauseId': deathCauseId,
    'damageByCause': damageByCause,
    'patchIds': patchIds.toList(growable: false)..sort(),
    'itemIds': itemIds.toList(growable: false)..sort(),
    'weaponBuildTiers': weaponBuildTiers,
    'completedWeaponBuilds': completedWeaponBuilds,
    'visitedRegionCount': visitedRegionCount,
    'regionEventsCompleted': regionEventsCompleted,
    'survivalBossesDefeated': survivalBossesDefeated,
  };

  static Map<String, int> _integerMap(Object? value) {
    final result = <String, int>{};
    if (value is! Map) return result;
    for (final entry in value.entries) {
      if (entry.key is String && entry.value is num) {
        result[entry.key as String] = (entry.value as num).round();
      }
    }
    return result;
  }
}

final class SurvivalWeaponBalanceStats {
  const SurvivalWeaponBalanceStats({
    required this.weapon,
    required this.runCount,
    required this.completionCount,
    required this.averageSurvivalSeconds,
  });

  final PlayerWeapon weapon;
  final int runCount;
  final int completionCount;
  final double averageSurvivalSeconds;

  double get completionRate => runCount == 0 ? 0 : completionCount / runCount;
}

final class SurvivalItemBalanceStats {
  const SurvivalItemBalanceStats({
    required this.itemId,
    required this.selectionCount,
    required this.completionCount,
    required this.totalRunCount,
    required this.totalCompletionCount,
  });

  final String itemId;
  final int selectionCount;
  final int completionCount;
  final int totalRunCount;
  final int totalCompletionCount;

  double get pickRate =>
      totalRunCount == 0 ? 0 : selectionCount / totalRunCount;
  double get completionRate =>
      selectionCount == 0 ? 0 : completionCount / selectionCount;
  double get completedRunPickRate =>
      totalCompletionCount == 0 ? 0 : completionCount / totalCompletionCount;
}

final class SurvivalBuildBalanceStats {
  const SurvivalBuildBalanceStats({
    required this.buildId,
    required this.selectionCount,
    required this.maxTierCount,
    required this.completionCount,
    required this.totalRunCount,
    required this.totalTier,
  });

  final String buildId;
  final int selectionCount;
  final int maxTierCount;
  final int completionCount;
  final int totalRunCount;
  final int totalTier;

  double get pickRate =>
      totalRunCount == 0 ? 0 : selectionCount / totalRunCount;
  double get maxTierRate =>
      selectionCount == 0 ? 0 : maxTierCount / selectionCount;
  double get completionRate =>
      selectionCount == 0 ? 0 : completionCount / selectionCount;
  double get averageTier =>
      selectionCount == 0 ? 0 : totalTier / selectionCount;
}

final class SurvivalBalanceReport {
  const SurvivalBalanceReport._({
    required this.records,
    required this.weaponStats,
    required this.itemStats,
    required this.buildStats,
    required this.deathCauseCounts,
    required this.damageCauseTotals,
    required this.topDeathCauseId,
    required this.topDamageSourceId,
    required this.topDeathCauseShare,
    required this.completionRateSpread,
    required this.regionEngagementRate,
  });

  factory SurvivalBalanceReport.fromRecords(
    Iterable<SurvivalPlaytestRecord> records,
  ) {
    final selected = records.toList(growable: false);
    final weaponStats = <PlayerWeapon, SurvivalWeaponBalanceStats>{};
    for (final weapon in PlayerWeapon.values) {
      final weaponRuns = selected
          .where((record) => record.weapon == weapon)
          .toList(growable: false);
      weaponStats[weapon] = SurvivalWeaponBalanceStats(
        weapon: weapon,
        runCount: weaponRuns.length,
        completionCount: weaponRuns.where((record) => record.completed).length,
        averageSurvivalSeconds: weaponRuns.isEmpty
            ? 0
            : weaponRuns.fold<double>(
                    0,
                    (total, record) => total + record.elapsedSeconds,
                  ) /
                  weaponRuns.length,
      );
    }

    final completionRates = weaponStats.values
        .where((stats) => stats.runCount > 0)
        .map((stats) => stats.completionRate)
        .toList(growable: false);
    final completionRateSpread =
        completionRates.length < PlayerWeapon.values.length
        ? 1.0
        : completionRates.reduce(math.max) - completionRates.reduce(math.min);

    final deathCauseCounts = <String, int>{};
    for (final record in selected.where((record) => !record.completed)) {
      deathCauseCounts.update(
        record.deathCauseId,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    String? topDeathCauseId;
    var topDeathCount = 0;
    final sortedDeathCauses = deathCauseCounts.keys.toList()..sort();
    for (final causeId in sortedDeathCauses) {
      final count = deathCauseCounts[causeId]!;
      if (count > topDeathCount) {
        topDeathCauseId = causeId;
        topDeathCount = count;
      }
    }
    final deathCount = deathCauseCounts.values.fold<int>(0, (a, b) => a + b);

    final itemSelections = <String, int>{};
    final itemCompletions = <String, int>{};
    for (final record in selected) {
      for (final itemId in record.itemIds) {
        itemSelections.update(itemId, (count) => count + 1, ifAbsent: () => 1);
        if (record.completed) {
          itemCompletions.update(
            itemId,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    final totalCompletions = selected
        .where((record) => record.completed)
        .length;
    final itemStats = <String, SurvivalItemBalanceStats>{};
    for (final itemId in itemSelections.keys) {
      itemStats[itemId] = SurvivalItemBalanceStats(
        itemId: itemId,
        selectionCount: itemSelections[itemId]!,
        completionCount: itemCompletions[itemId] ?? 0,
        totalRunCount: selected.length,
        totalCompletionCount: totalCompletions,
      );
    }

    final buildSelections = <String, int>{};
    final buildMaxTiers = <String, int>{};
    final buildCompletions = <String, int>{};
    final buildTierTotals = <String, int>{};
    for (final record in selected) {
      for (final entry in record.weaponBuildTiers.entries) {
        if (entry.value <= 0) continue;
        buildSelections.update(
          entry.key,
          (count) => count + 1,
          ifAbsent: () => 1,
        );
        buildTierTotals.update(
          entry.key,
          (total) => total + entry.value,
          ifAbsent: () => entry.value,
        );
        if (entry.value >= 3) {
          buildMaxTiers.update(
            entry.key,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
        if (record.completed) {
          buildCompletions.update(
            entry.key,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
    }
    final buildStats = <String, SurvivalBuildBalanceStats>{};
    for (final buildId in buildSelections.keys) {
      buildStats[buildId] = SurvivalBuildBalanceStats(
        buildId: buildId,
        selectionCount: buildSelections[buildId]!,
        maxTierCount: buildMaxTiers[buildId] ?? 0,
        completionCount: buildCompletions[buildId] ?? 0,
        totalRunCount: selected.length,
        totalTier: buildTierTotals[buildId]!,
      );
    }

    final damageCauseTotals = <String, int>{};
    for (final record in selected) {
      for (final entry in record.damageByCause.entries) {
        damageCauseTotals.update(
          entry.key,
          (total) => total + entry.value,
          ifAbsent: () => entry.value,
        );
      }
    }
    String? topDamageSourceId;
    var topDamage = 0;
    final sortedDamageCauses = damageCauseTotals.keys.toList()..sort();
    for (final causeId in sortedDamageCauses) {
      final damage = damageCauseTotals[causeId]!;
      if (damage > topDamage) {
        topDamageSourceId = causeId;
        topDamage = damage;
      }
    }

    final regionCompletions = selected
        .where((record) => record.metRegionEngagement)
        .length;
    return SurvivalBalanceReport._(
      records: List<SurvivalPlaytestRecord>.unmodifiable(selected),
      weaponStats: Map<PlayerWeapon, SurvivalWeaponBalanceStats>.unmodifiable(
        weaponStats,
      ),
      itemStats: Map<String, SurvivalItemBalanceStats>.unmodifiable(itemStats),
      buildStats: Map<String, SurvivalBuildBalanceStats>.unmodifiable(
        buildStats,
      ),
      deathCauseCounts: Map<String, int>.unmodifiable(deathCauseCounts),
      damageCauseTotals: Map<String, int>.unmodifiable(damageCauseTotals),
      topDeathCauseId: topDeathCauseId,
      topDamageSourceId: topDamageSourceId,
      topDeathCauseShare: deathCount == 0 ? 0 : topDeathCount / deathCount,
      completionRateSpread: completionRateSpread,
      regionEngagementRate: selected.isEmpty
          ? 0
          : regionCompletions / selected.length,
    );
  }

  static const int maximumStoredRuns = 90;
  static const int minimumRunsPerWeapon = 5;
  static const int minimumDeathSamples = 5;
  static const double maximumCompletionRateSpread = 0.10;
  static const double maximumDeathCauseShare = 0.35;

  final List<SurvivalPlaytestRecord> records;
  final Map<PlayerWeapon, SurvivalWeaponBalanceStats> weaponStats;
  final Map<String, SurvivalItemBalanceStats> itemStats;
  final Map<String, SurvivalBuildBalanceStats> buildStats;
  final Map<String, int> deathCauseCounts;
  final Map<String, int> damageCauseTotals;
  final String? topDeathCauseId;
  final String? topDamageSourceId;
  final double topDeathCauseShare;
  final double completionRateSpread;
  final double regionEngagementRate;

  int get runCount => records.length;
  int get deathSampleCount =>
      deathCauseCounts.values.fold<int>(0, (a, b) => a + b);
  bool get hasRequiredWeaponSamples => PlayerWeapon.values.every(
    (weapon) => weaponStats[weapon]!.runCount >= minimumRunsPerWeapon,
  );
  bool get hasRequiredDeathSamples => deathSampleCount >= minimumDeathSamples;
  bool get passesCompletionParity =>
      hasRequiredWeaponSamples &&
      completionRateSpread <= maximumCompletionRateSpread;
  bool get passesDeathCauseDiversity =>
      hasRequiredDeathSamples && topDeathCauseShare <= maximumDeathCauseShare;
  bool get passesRegionEngagement =>
      records.isNotEmpty && regionEngagementRate == 1;
  bool get statisticalGatesPassed =>
      passesCompletionParity &&
      passesDeathCauseDiversity &&
      passesRegionEngagement;

  SurvivalItemBalanceStats? get strongestCompletionItem {
    if (itemStats.isEmpty) return null;
    final candidates = itemStats.values.toList()
      ..sort((a, b) {
        final byRate = b.completedRunPickRate.compareTo(a.completedRunPickRate);
        return byRate != 0 ? byRate : a.itemId.compareTo(b.itemId);
      });
    return candidates.first;
  }

  SurvivalBuildBalanceStats? get strongestCompletionBuild {
    if (buildStats.isEmpty) return null;
    final candidates = buildStats.values.toList()
      ..sort((a, b) {
        final byRate = b.completionRate.compareTo(a.completionRate);
        return byRate != 0 ? byRate : a.buildId.compareTo(b.buildId);
      });
    return candidates.first;
  }
}
