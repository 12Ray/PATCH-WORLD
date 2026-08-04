import 'dart:math' as math;

enum PatchWorldMode { campaign, survival }

final class SurvivalRunState {
  final Map<String, int> _patchTiers = <String, int>{};
  double elapsedSeconds = 0;
  int kills = 0;
  int eliteKills = 0;
  int miniBossKills = 0;
  int combo = 0;
  double comboRemaining = 0;
  int level = 1;
  int experience = 0;
  int experienceToNext = 6;
  int riskTierTotal = 0;
  int bonusScore = 0;

  Map<String, int> get patchTiers => Map<String, int>.unmodifiable(_patchTiers);

  int patchTier(String patchId) => _patchTiers[patchId] ?? 0;

  double get riskMultiplier => (1 + riskTierTotal * 0.12).clamp(1, 2.5);

  int get score =>
      ((elapsedSeconds * 10 +
                  kills * 25 +
                  eliteKills * 250 +
                  miniBossKills * 1000 +
                  bonusScore) *
              riskMultiplier)
          .round();

  void update(double dt) {
    if (dt <= 0) return;
    elapsedSeconds += dt;
    if (comboRemaining <= 0) return;
    comboRemaining = math.max(0, comboRemaining - dt);
    if (comboRemaining == 0) combo = 0;
  }

  bool recordKill({
    bool elite = false,
    bool miniBoss = false,
    int rewardMultiplier = 1,
  }) {
    final safeRewardMultiplier = math.max(1, rewardMultiplier);
    kills += 1;
    if (elite) eliteKills += 1;
    if (miniBoss) miniBossKills += 1;
    combo += 1;
    comboRemaining = 3;
    final baseExperience = miniBoss
        ? 20
        : elite
        ? 5
        : 1;
    experience += baseExperience * safeRewardMultiplier;
    bonusScore +=
        (safeRewardMultiplier - 1) *
        (miniBoss
            ? 1000
            : elite
            ? 250
            : 25);
    var leveledUp = false;
    while (experience >= experienceToNext) {
      experience -= experienceToNext;
      level += 1;
      experienceToNext = 6 + (level - 1) * 4;
      leveledUp = true;
    }
    return leveledUp;
  }

  void recordHit() {
    combo = combo ~/ 2;
    comboRemaining = combo == 0 ? 0 : 3;
  }

  void addRiskTier(int tier) {
    if (tier > 0) riskTierTotal += tier;
  }

  int upgradePatch(String patchId, {required int riskTier}) {
    final nextTier = math.min(3, patchTier(patchId) + 1);
    if (nextTier == patchTier(patchId)) return nextTier;
    _patchTiers[patchId] = nextTier;
    addRiskTier(riskTier);
    return nextTier;
  }

  void reset() {
    elapsedSeconds = 0;
    kills = 0;
    eliteKills = 0;
    miniBossKills = 0;
    combo = 0;
    comboRemaining = 0;
    level = 1;
    experience = 0;
    experienceToNext = 6;
    riskTierTotal = 0;
    bonusScore = 0;
    _patchTiers.clear();
  }
}
