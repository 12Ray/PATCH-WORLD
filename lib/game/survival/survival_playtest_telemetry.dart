import 'dart:math' as math;

enum SurvivalMeaningfulEvent {
  kill,
  hit,
  patchInstalled,
  elite,
  composite,
  temporalStorm,
  optimizerFragment,
  endlessTier,
  dataSurge,
  fusionUnlocked,
}

final class SurvivalPacingSnapshot {
  const SurvivalPacingSnapshot({
    required this.meaningfulEventCount,
    required this.longestQuietSeconds,
    required this.eventsPerMinute,
  });

  final int meaningfulEventCount;
  final double longestQuietSeconds;
  final double eventsPerMinute;

  bool get hasPacingGap => longestQuietSeconds > 20;
}

final class SurvivalPlaytestTelemetry {
  final List<double> _eventTimes = <double>[];

  void record(double elapsedSeconds, SurvivalMeaningfulEvent event) {
    final safeTime = math.max(0.0, elapsedSeconds);
    _eventTimes.add(safeTime);
  }

  SurvivalPacingSnapshot snapshot(double elapsedSeconds) {
    final safeElapsed = math.max(0.0, elapsedSeconds);
    var longestGap = 0.0;
    var previous = 0.0;
    for (final time in _eventTimes) {
      final boundedTime = time.clamp(previous, safeElapsed).toDouble();
      longestGap = math.max(longestGap, boundedTime - previous);
      previous = boundedTime;
    }
    longestGap = math.max(longestGap, safeElapsed - previous);
    final eventsPerMinute = safeElapsed <= 0
        ? 0.0
        : _eventTimes.length * 60 / safeElapsed;
    return SurvivalPacingSnapshot(
      meaningfulEventCount: _eventTimes.length,
      longestQuietSeconds: longestGap,
      eventsPerMinute: eventsPerMinute,
    );
  }

  void reset() => _eventTimes.clear();
}

final class SurvivalSessionSummary {
  const SurvivalSessionSummary({
    required this.runCount,
    required this.topPatchId,
    required this.topPatchSelectionRate,
  });

  factory SurvivalSessionSummary.fromPatchRuns(
    Iterable<Set<String>> patchRuns, {
    int limit = 5,
  }) {
    final safeLimit = math.max(1, limit);
    final recentRuns = patchRuns.toList(growable: false);
    final start = math.max(0, recentRuns.length - safeLimit);
    final selectedRuns = recentRuns.sublist(start);
    final counts = <String, int>{};
    for (final run in selectedRuns) {
      for (final patchId in run) {
        counts.update(patchId, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    String? topPatchId;
    var topCount = 0;
    final sortedPatchIds = counts.keys.toList()..sort();
    for (final patchId in sortedPatchIds) {
      final count = counts[patchId]!;
      if (count > topCount) {
        topPatchId = patchId;
        topCount = count;
      }
    }
    return SurvivalSessionSummary(
      runCount: selectedRuns.length,
      topPatchId: topPatchId,
      topPatchSelectionRate: selectedRuns.isEmpty
          ? 0
          : topCount / selectedRuns.length,
    );
  }

  final int runCount;
  final String? topPatchId;
  final double topPatchSelectionRate;

  bool get hasSelectionBias => runCount >= 5 && topPatchSelectionRate > 0.8;
}
