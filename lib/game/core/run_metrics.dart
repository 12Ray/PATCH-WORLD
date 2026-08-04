import 'dart:math' as math;

final class RunMetrics {
  double elapsedSeconds = 0;
  int deaths = 0;
  int damageTaken = 0;
  int overflowCount = 0;

  void update(double dt) => elapsedSeconds += math.max(0, dt);

  void recordDeath() => deaths += 1;

  void recordDamage(int amount) => damageTaken += math.max(0, amount);

  void recordOverflow() => overflowCount += 1;

  RunSummary finish({
    required int integrity,
    required List<String> selectedPatchIds,
    required String endingId,
  }) {
    final timeBonus = math.max(0, 500 - elapsedSeconds.round() * 2);
    final noDeathBonus = deaths == 0 ? 450 : 0;
    final score =
        1000 + integrity * 100 + overflowCount * 100 + timeBonus + noDeathBonus;
    return RunSummary(
      elapsedSeconds: elapsedSeconds,
      deaths: deaths,
      damageTaken: damageTaken,
      overflowCount: overflowCount,
      score: score,
      selectedPatchIds: List<String>.unmodifiable(selectedPatchIds),
      endingId: endingId,
    );
  }

  void reset() {
    elapsedSeconds = 0;
    deaths = 0;
    damageTaken = 0;
    overflowCount = 0;
  }
}

final class RunSummary {
  const RunSummary({
    required this.elapsedSeconds,
    required this.deaths,
    required this.damageTaken,
    required this.overflowCount,
    required this.score,
    required this.selectedPatchIds,
    required this.endingId,
  });

  final double elapsedSeconds;
  final int deaths;
  final int damageTaken;
  final int overflowCount;
  final int score;
  final List<String> selectedPatchIds;
  final String endingId;

  String get formattedTime {
    final total = elapsedSeconds.round();
    final minutes = total ~/ 60;
    final seconds = total % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

final class DefeatSnapshot {
  const DefeatSnapshot({required this.causeId, required this.deathStreak});

  final String causeId;
  final int deathStreak;
  bool get shouldOfferAssist => deathStreak >= 3;
}
