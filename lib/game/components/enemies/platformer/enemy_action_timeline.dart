enum EnemyActionPhase { telegraph, active, recovery, completed }

final class EnemyActionTick {
  const EnemyActionTick({required this.previous, required this.current});

  final EnemyActionPhase previous;
  final EnemyActionPhase current;

  bool get enteredActive =>
      previous.index < EnemyActionPhase.active.index &&
      current.index >= EnemyActionPhase.active.index;
  bool get enteredRecovery =>
      previous.index < EnemyActionPhase.recovery.index &&
      current.index >= EnemyActionPhase.recovery.index;
  bool get completed => current == EnemyActionPhase.completed;
}

/// Deterministic gameplay timeline shared by enemy tells, damaging frames, and
/// recovery windows. Visuals observe this timeline instead of owning timing.
final class EnemyActionTimeline {
  EnemyActionTimeline({
    required this.id,
    required this.telegraphSeconds,
    required this.activeSeconds,
    required this.recoverySeconds,
  }) : assert(telegraphSeconds >= 0),
       assert(activeSeconds > 0),
       assert(recoverySeconds >= 0);

  final String id;
  final double telegraphSeconds;
  final double activeSeconds;
  final double recoverySeconds;

  double _elapsed = 0;
  EnemyActionPhase _phase = EnemyActionPhase.telegraph;

  double get elapsed => _elapsed;
  EnemyActionPhase get phase => _phase;
  bool get isDamaging => _phase == EnemyActionPhase.active;
  bool get isComplete => _phase == EnemyActionPhase.completed;

  EnemyActionTick advance(double dt) {
    final previous = _phase;
    if (dt <= 0 || isComplete) {
      return EnemyActionTick(previous: previous, current: _phase);
    }
    _elapsed += dt;
    final activeAt = telegraphSeconds;
    final recoveryAt = activeAt + activeSeconds;
    final completeAt = recoveryAt + recoverySeconds;
    _phase = switch (_elapsed) {
      final value when value < activeAt => EnemyActionPhase.telegraph,
      final value when value < recoveryAt => EnemyActionPhase.active,
      final value when value < completeAt => EnemyActionPhase.recovery,
      _ => EnemyActionPhase.completed,
    };
    return EnemyActionTick(previous: previous, current: _phase);
  }
}
