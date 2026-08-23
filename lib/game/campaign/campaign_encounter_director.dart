import 'dart:ui';

import 'package:patch_world/game/campaign/campaign_encounter_contract.dart';

enum CampaignEncounterPhase {
  idle,
  sealing,
  wave,
  intermission,
  objectiveHold,
  clearBeat,
  cleared,
}

typedef CampaignWaveActivationCallback =
    void Function(int waveIndex, List<String> enemyIds);
typedef CampaignEncounterPhaseCallback =
    void Function(CampaignEncounterPhase phase);

/// Deterministic pacing state for one authored campaign-room encounter.
///
/// The director owns time and wave order only. Room controllers remain
/// responsible for spawning enemies, sealing doors, camera framing and
/// persisting campaign progress.
final class CampaignEncounterDirector {
  CampaignEncounterDirector({
    required this.spec,
    required this.onWaveActivated,
    required this.onClearBeatStarted,
    required this.onCleared,
    this.onPhaseChanged,
    bool initiallyCleared = false,
    this.completionGateSatisfied = true,
    this.reverseWaves = false,
  }) : _phase = initiallyCleared
           ? CampaignEncounterPhase.cleared
           : CampaignEncounterPhase.idle;

  final CampaignEncounterSpec spec;
  final CampaignWaveActivationCallback onWaveActivated;
  final VoidCallback onClearBeatStarted;
  final VoidCallback onCleared;
  final CampaignEncounterPhaseCallback? onPhaseChanged;
  final bool reverseWaves;

  CampaignEncounterPhase _phase;
  int _waveIndex = -1;
  double _remainingSeconds = 0;
  final Set<String> _activeEnemyIds = <String>{};
  bool completionGateSatisfied;

  CampaignEncounterPhase get phase => _phase;
  int get waveIndex => _waveIndex;
  double get remainingSeconds => _remainingSeconds;
  Set<String> get activeEnemyIds => Set<String>.unmodifiable(_activeEnemyIds);
  int get activeEnemyCount => _activeEnemyIds.length;
  bool get isTriggered =>
      _phase != CampaignEncounterPhase.idle &&
      _phase != CampaignEncounterPhase.cleared;
  bool get isSealed => isTriggered;
  bool get usesCombatCamera => isTriggered;
  bool get isCleared => _phase == CampaignEncounterPhase.cleared;

  /// Starts the encounter only when the player crosses the authored trigger.
  bool tryTrigger(Offset playerPosition) {
    if (_phase != CampaignEncounterPhase.idle ||
        !spec.triggerZone.contains(playerPosition)) {
      return false;
    }
    _enterTimedPhase(CampaignEncounterPhase.sealing, spec.sealSeconds);
    _drainZeroDurationPhase();
    return true;
  }

  /// Advances presentation pacing in real time. Combat simulation may still
  /// be slowed or frozen independently by a region mechanic.
  void update(double realDt) {
    if (!realDt.isFinite || realDt <= 0 || !_isTimedPhase) return;
    var budget = realDt;
    while (_isTimedPhase && budget >= 0) {
      if (_remainingSeconds > budget) {
        _remainingSeconds -= budget;
        return;
      }
      budget -= _remainingSeconds;
      _remainingSeconds = 0;
      _finishTimedPhase();
      if (!_isTimedPhase || budget == 0) return;
    }
  }

  /// Records a defeat only for an enemy in the currently active wave.
  bool notifyEnemyDefeated(String enemyId) {
    if (_phase != CampaignEncounterPhase.wave ||
        !_activeEnemyIds.remove(enemyId)) {
      return false;
    }
    if (_activeEnemyIds.isNotEmpty) return true;

    if (_waveIndex + 1 < spec.waves.length) {
      _enterTimedPhase(
        CampaignEncounterPhase.intermission,
        spec.intermissionSeconds,
      );
    } else {
      _beginCompletionSequence();
    }
    _drainZeroDurationPhase();
    return true;
  }

  /// Releases a room-specific completion gate. Regional objectives can be
  /// solved before, during or after combat without bypassing the clear beat.
  void notifyCompletionGateSatisfied() {
    if (completionGateSatisfied) return;
    completionGateSatisfied = true;
    if (_phase == CampaignEncounterPhase.objectiveHold) {
      _beginClearBeat();
    }
  }

  bool get _isTimedPhase => switch (_phase) {
    CampaignEncounterPhase.sealing ||
    CampaignEncounterPhase.intermission ||
    CampaignEncounterPhase.clearBeat => true,
    _ => false,
  };

  void _enterTimedPhase(CampaignEncounterPhase phase, double duration) {
    _remainingSeconds = duration;
    _setPhase(phase);
  }

  void _drainZeroDurationPhase() {
    while (_isTimedPhase && _remainingSeconds <= 0) {
      _finishTimedPhase();
    }
  }

  void _finishTimedPhase() {
    switch (_phase) {
      case CampaignEncounterPhase.sealing:
        _activateWave(0);
      case CampaignEncounterPhase.intermission:
        _activateWave(_waveIndex + 1);
      case CampaignEncounterPhase.clearBeat:
        _setPhase(CampaignEncounterPhase.cleared);
        onCleared();
      case CampaignEncounterPhase.idle ||
          CampaignEncounterPhase.wave ||
          CampaignEncounterPhase.objectiveHold ||
          CampaignEncounterPhase.cleared:
        return;
    }
  }

  void _beginCompletionSequence() {
    if (completionGateSatisfied) {
      _beginClearBeat();
      return;
    }
    _remainingSeconds = 0;
    _setPhase(CampaignEncounterPhase.objectiveHold);
  }

  void _beginClearBeat() {
    _enterTimedPhase(CampaignEncounterPhase.clearBeat, spec.clearBeatSeconds);
    onClearBeatStarted();
  }

  void _activateWave(int index) {
    if (index < 0 || index >= spec.waves.length) {
      throw StateError('Encounter wave index $index is outside the spec.');
    }
    final authoredIndex = reverseWaves ? spec.waves.length - 1 - index : index;
    final ids = List<String>.unmodifiable(spec.waves[authoredIndex].enemyIds);
    if (ids.isEmpty || ids.length > spec.maxActiveEnemies) {
      throw StateError(
        'Encounter wave $index violates maxActiveEnemies '
        '(${spec.maxActiveEnemies}).',
      );
    }
    _waveIndex = index;
    _activeEnemyIds
      ..clear()
      ..addAll(ids);
    _remainingSeconds = 0;
    _setPhase(CampaignEncounterPhase.wave);
    onWaveActivated(index, ids);
  }

  void _setPhase(CampaignEncounterPhase next) {
    if (_phase == next) return;
    _phase = next;
    onPhaseChanged?.call(next);
  }
}
