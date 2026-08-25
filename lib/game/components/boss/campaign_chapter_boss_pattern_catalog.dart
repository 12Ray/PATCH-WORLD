/// Readable, testable contract for the two connected-campaign chapter bosses.
///
/// This file intentionally has no Flame or Flutter dependency. Runtime code uses
/// the same timing and pattern metadata that pure unit tests validate.
enum CampaignBossAttackVisualPhase { idle, telegraph, active, recovery }

enum CampaignBossAttackCycleEvent { execute, activeEnded, recovered }

/// Shared health-gate and transition contract for the connected-campaign
/// chapter bosses.
///
/// Damage is clamped at the current phase's floor. Crossing that floor can
/// only advance one phase, and only after two different attacks have completed
/// in the current phase. The final floor deliberately leaves one health point
/// so the boss cannot enter a defeated health condition before phase three has
/// demonstrated a representative pattern pair.
abstract final class CampaignBossPhaseGateSpec {
  static const int maxHealth = 20;
  static const List<int> healthFloors = <int>[13, 6, 1];
  static const double transitionQuietSeconds = .75;
  static const int requiredDistinctPatternsPerPhase = 2;

  static int healthFloorForPhaseIndex(int phaseIndex) {
    if (phaseIndex < 0 || phaseIndex >= healthFloors.length) {
      throw RangeError.range(
        phaseIndex,
        0,
        healthFloors.length - 1,
        'phaseIndex',
      );
    }
    return healthFloors[phaseIndex];
  }
}

/// Art v3 enemy strips reserve frame 4 for telegraph, 5 for the damaging pose,
/// and 6-7 for follow-through/recovery. Idle returns -1 so the runtime can use
/// its health-phase locomotion frame.
int resolveCampaignBossAttackFrame(
  CampaignBossAttackVisualPhase phase,
  double visualClock,
) {
  final safeClock = visualClock >= 0 && visualClock.isFinite
      ? visualClock
      : 0.0;
  return switch (phase) {
    CampaignBossAttackVisualPhase.idle => -1,
    CampaignBossAttackVisualPhase.telegraph => 4,
    CampaignBossAttackVisualPhase.active => 5,
    CampaignBossAttackVisualPhase.recovery => 6 + (safeClock * 10).floor() % 2,
  };
}

bool campaignBossHasLiveExecutionWindow(
  List<CampaignBossAttackCycleEvent> events,
  CampaignBossAttackVisualPhase finalPhase,
) =>
    events.contains(CampaignBossAttackCycleEvent.execute) &&
    finalPhase == CampaignBossAttackVisualPhase.active;

final class CampaignChapterBossAttackSpec {
  const CampaignChapterBossAttackSpec({
    required this.id,
    required this.telegraphSeconds,
    required this.activeSeconds,
    required this.recoverySeconds,
    required this.attackSpace,
    required this.movement,
    required this.counterplay,
  }) : assert(telegraphSeconds > 0),
       assert(activeSeconds > 0),
       assert(recoverySeconds > 0);

  final String id;
  final double telegraphSeconds;
  final double activeSeconds;
  final double recoverySeconds;
  final String attackSpace;
  final String movement;
  final String counterplay;

  String get fingerprint => '$id/$attackSpace/$movement/$counterplay';
}

final class CampaignChapterBossPatternSet {
  const CampaignChapterBossPatternSet({
    required this.bossId,
    required this.patterns,
    required this.phasePatternIds,
  });

  final String bossId;
  final List<CampaignChapterBossAttackSpec> patterns;
  final List<List<String>> phasePatternIds;

  CampaignChapterBossAttackSpec byId(String id) =>
      patterns.firstWhere((pattern) => pattern.id == id);

  List<String> patternIdsForPhaseIndex(int phaseIndex) {
    if (phaseIndex < 0 || phaseIndex >= phasePatternIds.length) {
      throw RangeError.range(
        phaseIndex,
        0,
        phasePatternIds.length - 1,
        'phaseIndex',
      );
    }
    return phasePatternIds[phaseIndex];
  }

  String get fingerprint =>
      '$bossId:${patterns.map((pattern) => pattern.fingerprint).join('|')}';
}

abstract final class CampaignChapterBossPatternCatalog {
  static const CampaignChapterBossPatternSet chronoJailer =
      CampaignChapterBossPatternSet(
        bossId: 'chronoJailer',
        phasePatternIds: <List<String>>[
          <String>['rewindCharge', 'clockFan', 'clockSweep'],
          <String>['timeCage', 'clockSweep', 'rewindCharge', 'clockFan'],
          <String>[
            'hourglassMine',
            'rewindCharge',
            'timeCage',
            'clockFan',
            'clockSweep',
          ],
        ],
        patterns: <CampaignChapterBossAttackSpec>[
          CampaignChapterBossAttackSpec(
            id: 'rewindCharge',
            telegraphSeconds: .58,
            activeSeconds: .34,
            recoverySeconds: .44,
            attackSpace: 'recorded-anchor-to-player-line',
            movement: 'flank-dash-then-rewind-to-recorded-anchor',
            counterplay: 'cross-the-line-then-punish-the-recorded-return',
          ),
          CampaignChapterBossAttackSpec(
            id: 'clockFan',
            telegraphSeconds: .45,
            activeSeconds: .36,
            recoverySeconds: .30,
            attackSpace: 'five-player-aimed-clock-hands',
            movement: 'stationary-clock-face',
            counterplay: 'parry-the-gold-center-hand-or-step-between-hands',
          ),
          CampaignChapterBossAttackSpec(
            id: 'timeCage',
            telegraphSeconds: .78,
            activeSeconds: .34,
            recoverySeconds: .46,
            attackSpace: 'three-sided-clock-cage-with-lateral-exit',
            movement: 'hold-the-recorded-clock-anchor',
            counterplay: 'run-through-the-lit-open-side-before-the-cage-locks',
          ),
          CampaignChapterBossAttackSpec(
            id: 'hourglassMine',
            telegraphSeconds: .48,
            activeSeconds: .62,
            recoverySeconds: .28,
            attackSpace: 'crossing-gravity-hourglass-arcs',
            movement: 'short-recoil-away-from-player',
            counterplay: 'wait-for-the-bounce-then-pass-under-the-arc',
          ),
          CampaignChapterBossAttackSpec(
            id: 'clockSweep',
            telegraphSeconds: .50,
            activeSeconds: .38,
            recoverySeconds: .34,
            attackSpace: 'simultaneous-three-hand-radial-clock-sweep',
            movement: 'pivot-around-current-clock-center',
            counterplay: 'jump-the-low-hand-and-stand-between-diagonals',
          ),
        ],
      );

  static const CampaignChapterBossPatternSet kernelChimera =
      CampaignChapterBossPatternSet(
        bossId: 'kernelChimera',
        phasePatternIds: <List<String>>[
          <String>['mergeSlam', 'splitKernel', 'gravityShard'],
          <String>['polarityCross', 'splitKernel', 'mergeSlam', 'gravityShard'],
          <String>[
            'vectorCage',
            'gravityShard',
            'polarityCross',
            'splitKernel',
            'mergeSlam',
          ],
        ],
        patterns: <CampaignChapterBossAttackSpec>[
          CampaignChapterBossAttackSpec(
            id: 'mergeSlam',
            telegraphSeconds: .62,
            activeSeconds: .42,
            recoverySeconds: .52,
            attackSpace: 'vertical-core-impact-plus-two-floor-waves',
            movement: 'merge-above-target-slam-then-return',
            counterplay: 'leave-the-core-column-then-hop-the-floor-wave',
          ),
          CampaignChapterBossAttackSpec(
            id: 'splitKernel',
            telegraphSeconds: .52,
            activeSeconds: .46,
            recoverySeconds: .48,
            attackSpace: 'mirrored-left-right-emitter-lanes',
            movement: 'split-across-two-flanking-positions',
            counterplay: 'change-lanes-and-parry-one-inner-kernel',
          ),
          CampaignChapterBossAttackSpec(
            id: 'polarityCross',
            telegraphSeconds: .56,
            activeSeconds: .42,
            recoverySeconds: .38,
            attackSpace: 'offset-orthogonal-positive-negative-crosses',
            movement: 'split-across-two-polarity-origins',
            counterplay: 'move-diagonally-through-the-cross-quadrants',
          ),
          CampaignChapterBossAttackSpec(
            id: 'vectorCage',
            telegraphSeconds: .76,
            activeSeconds: .36,
            recoverySeconds: .46,
            attackSpace: 'three-edge-diamond-with-readable-gap',
            movement: 'hold-opposite-the-open-diamond-edge',
            counterplay: 'dash-or-jump-through-the-missing-edge',
          ),
          CampaignChapterBossAttackSpec(
            id: 'gravityShard',
            telegraphSeconds: .48,
            activeSeconds: .64,
            recoverySeconds: .30,
            attackSpace: 'converging-dual-origin-gravity-arcs',
            movement: 'rapid-polarity-side-swap',
            counterplay: 'bait-the-convergence-then-run-beneath-the-apex',
          ),
        ],
      );

  static CampaignChapterBossPatternSet forBossId(String bossId) =>
      switch (bossId) {
        'chronoJailer' => chronoJailer,
        'kernelChimera' => kernelChimera,
        _ => throw ArgumentError.value(bossId, 'bossId', 'Unknown boss'),
      };
}

/// Advances one complete attack without losing intermediate transitions when a
/// frame has a large delta. Simulation freeze is represented by passing zero.
final class CampaignBossAttackCycle {
  CampaignBossAttackVisualPhase phase = CampaignBossAttackVisualPhase.idle;
  CampaignChapterBossAttackSpec? _attack;
  double _remaining = 0;

  CampaignChapterBossAttackSpec? get attack => _attack;
  double get remaining => _remaining;
  bool get isIdle => phase == CampaignBossAttackVisualPhase.idle;

  bool start(CampaignChapterBossAttackSpec attack) {
    if (!isIdle) return false;
    _attack = attack;
    phase = CampaignBossAttackVisualPhase.telegraph;
    _remaining = attack.telegraphSeconds;
    return true;
  }

  List<CampaignBossAttackCycleEvent> advance(double dt) {
    if (dt <= 0 || !dt.isFinite || _attack == null) {
      return const <CampaignBossAttackCycleEvent>[];
    }
    var budget = dt;
    final events = <CampaignBossAttackCycleEvent>[];
    while (_attack != null && budget >= _remaining) {
      budget -= _remaining;
      final attack = _attack!;
      switch (phase) {
        case CampaignBossAttackVisualPhase.telegraph:
          phase = CampaignBossAttackVisualPhase.active;
          _remaining = attack.activeSeconds;
          events.add(CampaignBossAttackCycleEvent.execute);
        case CampaignBossAttackVisualPhase.active:
          phase = CampaignBossAttackVisualPhase.recovery;
          _remaining = attack.recoverySeconds;
          events.add(CampaignBossAttackCycleEvent.activeEnded);
        case CampaignBossAttackVisualPhase.recovery:
          phase = CampaignBossAttackVisualPhase.idle;
          _remaining = 0;
          _attack = null;
          events.add(CampaignBossAttackCycleEvent.recovered);
        case CampaignBossAttackVisualPhase.idle:
          _attack = null;
          _remaining = 0;
      }
    }
    if (_attack != null) _remaining -= budget;
    return events;
  }

  void reset() {
    phase = CampaignBossAttackVisualPhase.idle;
    _remaining = 0;
    _attack = null;
  }
}
