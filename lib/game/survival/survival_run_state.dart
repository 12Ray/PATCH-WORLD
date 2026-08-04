import 'dart:math' as math;

import 'package:patch_world/game/survival/survival_playtest_telemetry.dart';
import 'package:patch_world/game/survival/survival_patch_fusions.dart';

enum PatchWorldMode { campaign, survival }

final class SurvivalRunState {
  static const int maxReroutes = 2;
  static const double criticalFlowDuration = 5;

  final SurvivalPlaytestTelemetry telemetry = SurvivalPlaytestTelemetry();
  final Map<String, int> _patchTiers = <String, int>{};
  final List<double> _killTimes = <double>[];
  final List<int> _pendingUpgradeLevels = <int>[];
  double elapsedSeconds = 0;
  int kills = 0;
  int eliteKills = 0;
  int miniBossKills = 0;
  int combo = 0;
  int maxCombo = 0;
  double comboRemaining = 0;
  int level = 1;
  int experience = 0;
  int experienceToNext = 6;
  int riskTierTotal = 0;
  int bonusScore = 0;
  int hotCachesSpawned = 0;
  int hotCachesCollected = 0;
  int hotCachesExpired = 0;
  int perfectDodges = 0;
  int houndBreaks = 0;
  int phaseExecutions = 0;
  String? firstPatchId;
  double turboOverclockRemaining = 0;
  double frameOverclockRemaining = 0;
  double dataSurgeRemaining = 0;
  double criticalFlowRemaining = 0;
  int reroutesRemaining = 1;

  Map<String, int> get patchTiers => Map<String, int>.unmodifiable(_patchTiers);

  int patchTier(String patchId) => _patchTiers[patchId] ?? 0;

  double get riskMultiplier => (1 + riskTierTotal * 0.12).clamp(1, 2.5);

  static int flowMultiplierForCombo(int combo) {
    if (combo >= 20) return 4;
    if (combo >= 10) return 3;
    if (combo >= 5) return 2;
    return 1;
  }

  static double comboWindowForCombo(int combo) =>
      3 + math.min(1.5, math.max(0, combo) * 0.04);

  static int flowDataRewardForCombo(int combo) {
    if (combo == 5 || combo == 10) return 1;
    if (combo >= 20 && combo % 20 == 0) return 2;
    return 0;
  }

  int get flowMultiplier => flowMultiplierForCombo(combo);
  bool get criticalFlowActive => criticalFlowRemaining > 0;
  int get criticalFlowDamageBonus => criticalFlowActive ? 1 : 0;
  double get criticalFlowCooldownMultiplier => criticalFlowActive ? 0.75 : 1;
  double get criticalFlowProgress =>
      (criticalFlowRemaining / criticalFlowDuration).clamp(0, 1).toDouble();
  double get comboProgress {
    if (combo <= 0 || comboRemaining <= 0) return 0;
    return (comboRemaining / comboWindowForCombo(combo)).clamp(0, 1).toDouble();
  }

  int get pendingUpgradeCount => _pendingUpgradeLevels.length;
  bool get hasPendingUpgrade => _pendingUpgradeLevels.isNotEmpty;

  int? takePendingUpgradeLevel() =>
      _pendingUpgradeLevels.isEmpty ? null : _pendingUpgradeLevels.removeAt(0);

  void seedComboForQa(int value) {
    combo = math.max(0, value);
    maxCombo = math.max(maxCombo, combo);
    comboRemaining = combo == 0 ? 0 : comboWindowForCombo(combo);
  }

  double recentKillsPerSecond({double windowSeconds = 20}) {
    final safeWindow = math.max(1.0, windowSeconds);
    final cutoff = elapsedSeconds - safeWindow;
    _killTimes.removeWhere((time) => time < cutoff);
    final observedSeconds = math.max(1.0, math.min(elapsedSeconds, safeWindow));
    return _killTimes.length / observedSeconds;
  }

  int get score =>
      ((elapsedSeconds * 10 +
                  kills * 25 +
                  eliteKills * 250 +
                  miniBossKills * 1000 +
                  bonusScore) *
              riskMultiplier)
          .round();

  bool get turboOverclockActive => turboOverclockRemaining > 0;
  bool get frameOverclockActive => frameOverclockRemaining > 0;
  bool get overclockActive => turboOverclockActive || frameOverclockActive;
  double get overclockCooldownMultiplier => overclockActive ? 0.65 : 1;
  bool get dataSurgeActive => dataSurgeRemaining > 0;
  double get dataSurgeCooldownMultiplier => dataSurgeActive ? 0.70 : 1;
  int get dataSurgeDamageBonus => dataSurgeActive ? 1 : 0;

  void update(double dt) {
    if (dt <= 0) return;
    elapsedSeconds += dt;
    turboOverclockRemaining = math.max(0, turboOverclockRemaining - dt);
    frameOverclockRemaining = math.max(0, frameOverclockRemaining - dt);
    dataSurgeRemaining = math.max(0, dataSurgeRemaining - dt);
    criticalFlowRemaining = math.max(0, criticalFlowRemaining - dt);
    if (comboRemaining <= 0) return;
    comboRemaining = math.max(0, comboRemaining - dt);
    if (comboRemaining == 0) combo = 0;
  }

  bool recordKill({
    bool elite = false,
    bool miniBoss = false,
    int rewardMultiplier = 1,
  }) {
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.kill);
    final safeRewardMultiplier = math.max(1, rewardMultiplier);
    kills += 1;
    _killTimes.add(elapsedSeconds);
    if (elite) eliteKills += 1;
    if (miniBoss) {
      miniBossKills += 1;
      grantReroute();
    }
    combo += 1;
    if (combo % 20 == 0) {
      criticalFlowRemaining = criticalFlowDuration;
    }
    maxCombo = math.max(maxCombo, combo);
    comboRemaining = comboWindowForCombo(combo);
    final baseExperience = miniBoss
        ? 20
        : elite
        ? 5
        : 1;
    experience += baseExperience * safeRewardMultiplier;
    final baseKillScore = 25 + (elite ? 250 : 0) + (miniBoss ? 1000 : 0);
    bonusScore += (safeRewardMultiplier * flowMultiplier - 1) * baseKillScore;
    var leveledUp = false;
    while (experience >= experienceToNext) {
      experience -= experienceToNext;
      level += 1;
      experienceToNext = 6 + (level - 1) * 4;
      _pendingUpgradeLevels.add(level);
      leveledUp = true;
    }
    return leveledUp;
  }

  void recordHit() {
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.hit);
    combo = combo ~/ 2;
    comboRemaining = combo == 0 ? 0 : comboWindowForCombo(combo);
  }

  void addRiskTier(int tier) {
    if (tier > 0) riskTierTotal += tier;
  }

  void triggerTurboOverclock() => turboOverclockRemaining = 1.5;

  void triggerFrameOverclock() => frameOverclockRemaining = 1.5;

  void triggerDataSurge() {
    dataSurgeRemaining = 2;
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.dataSurge);
  }

  bool consumeReroute() {
    if (reroutesRemaining <= 0) return false;
    reroutesRemaining -= 1;
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.reroute);
    return true;
  }

  void grantReroute() {
    reroutesRemaining = math.min(maxReroutes, reroutesRemaining + 1);
  }

  void recordMaxedBuildLevel() => bonusScore += 250;

  void recordHotCacheSpawned() => hotCachesSpawned += 1;

  int recordHotCacheCollected() {
    hotCachesCollected += 1;
    final reward = 400 * flowMultiplier;
    bonusScore += reward;
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.volatileCache);
    return reward;
  }

  void recordHotCacheExpired() => hotCachesExpired += 1;

  int recordPerfectDodge() {
    perfectDodges += 1;
    final reward = 120 * flowMultiplier;
    bonusScore += reward;
    if (combo > 0) comboRemaining = comboWindowForCombo(combo);
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.perfectDodge);
    return reward;
  }

  int recordHoundBreak() {
    houndBreaks += 1;
    final reward = 160 * flowMultiplier;
    bonusScore += reward;
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.houndBreak);
    return reward;
  }

  int recordPhaseExecution() {
    phaseExecutions += 1;
    final reward = 240 * flowMultiplier;
    bonusScore += reward;
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.phaseExecution);
    return reward;
  }

  int upgradePatch(String patchId, {required int riskTier}) {
    final nextTier = math.min(3, patchTier(patchId) + 1);
    if (nextTier == patchTier(patchId)) return nextTier;
    _patchTiers[patchId] = nextTier;
    telemetry.record(elapsedSeconds, SurvivalMeaningfulEvent.patchInstalled);
    firstPatchId ??= patchId;
    addRiskTier(riskTier);
    return nextTier;
  }

  void reset() {
    elapsedSeconds = 0;
    kills = 0;
    eliteKills = 0;
    miniBossKills = 0;
    combo = 0;
    maxCombo = 0;
    comboRemaining = 0;
    level = 1;
    experience = 0;
    experienceToNext = 6;
    riskTierTotal = 0;
    bonusScore = 0;
    hotCachesSpawned = 0;
    hotCachesCollected = 0;
    hotCachesExpired = 0;
    perfectDodges = 0;
    houndBreaks = 0;
    phaseExecutions = 0;
    firstPatchId = null;
    turboOverclockRemaining = 0;
    frameOverclockRemaining = 0;
    dataSurgeRemaining = 0;
    criticalFlowRemaining = 0;
    reroutesRemaining = 1;
    _patchTiers.clear();
    _killTimes.clear();
    _pendingUpgradeLevels.clear();
    telemetry.reset();
  }
}

final class SurvivalResultSnapshot {
  const SurvivalResultSnapshot({
    required this.elapsedSeconds,
    required this.kills,
    required this.eliteKills,
    required this.miniBossKills,
    required this.score,
    required this.maxCombo,
    required this.hotCachesSpawned,
    required this.hotCachesCollected,
    this.perfectDodges = 0,
    this.houndBreaks = 0,
    this.phaseExecutions = 0,
    required this.patchTiers,
    required this.riskMultiplier,
    required this.firstPatchId,
    required this.isBestScore,
    required this.isBestTime,
    required this.meaningfulEventCount,
    required this.longestQuietSeconds,
    required this.eventsPerMinute,
  });

  factory SurvivalResultSnapshot.fromRun(
    SurvivalRunState run, {
    required bool isBestScore,
    required bool isBestTime,
  }) {
    final pacing = run.telemetry.snapshot(run.elapsedSeconds);
    return SurvivalResultSnapshot(
      elapsedSeconds: run.elapsedSeconds,
      kills: run.kills,
      eliteKills: run.eliteKills,
      miniBossKills: run.miniBossKills,
      score: run.score,
      maxCombo: run.maxCombo,
      hotCachesSpawned: run.hotCachesSpawned,
      hotCachesCollected: run.hotCachesCollected,
      perfectDodges: run.perfectDodges,
      houndBreaks: run.houndBreaks,
      phaseExecutions: run.phaseExecutions,
      patchTiers: Map<String, int>.unmodifiable(run.patchTiers),
      riskMultiplier: run.riskMultiplier,
      firstPatchId: run.firstPatchId,
      isBestScore: isBestScore,
      isBestTime: isBestTime,
      meaningfulEventCount: pacing.meaningfulEventCount,
      longestQuietSeconds: pacing.longestQuietSeconds,
      eventsPerMinute: pacing.eventsPerMinute,
    );
  }

  final double elapsedSeconds;
  final int kills;
  final int eliteKills;
  final int miniBossKills;
  final int score;
  final int maxCombo;
  final int hotCachesSpawned;
  final int hotCachesCollected;
  final int perfectDodges;
  final int houndBreaks;
  final int phaseExecutions;
  final Map<String, int> patchTiers;
  final double riskMultiplier;
  final String? firstPatchId;
  final bool isBestScore;
  final bool isBestTime;
  final int meaningfulEventCount;
  final double longestQuietSeconds;
  final double eventsPerMinute;

  bool get hasPacingGap => longestQuietSeconds > 20;
  List<String> get activeFusionIds =>
      SurvivalPatchFusions.activeFor(patchTiers);

  String get formattedTime {
    final total = elapsedSeconds.floor();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
