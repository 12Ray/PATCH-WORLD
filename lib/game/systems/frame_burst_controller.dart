enum FrameBurstPhase { normal, warning, active }

final class FrameBurstSnapshot {
  const FrameBurstSnapshot({
    required this.phase,
    required this.phaseProgress,
    required this.speedMultiplier,
  });
  final FrameBurstPhase phase;
  final double phaseProgress;
  final double speedMultiplier;
}

final class FrameBurstController {
  FrameBurstController({
    this.normalSeconds = 5,
    this.warningSeconds = 0.7,
    this.activeSeconds = 0.6,
    this.activeMultiplier = 2,
  });

  final double normalSeconds;
  final double warningSeconds;
  final double activeSeconds;
  final double activeMultiplier;
  FrameBurstPhase _phase = FrameBurstPhase.normal;
  double _elapsed = 0;

  FrameBurstPhase get phase => _phase;
  double get speedMultiplier =>
      _phase == FrameBurstPhase.active ? activeMultiplier : 1;

  FrameBurstSnapshot update(double dt) {
    if (dt <= 0) {
      return snapshot;
    }
    _elapsed += dt;
    switch (_phase) {
      case FrameBurstPhase.normal:
        if (_elapsed >= normalSeconds) _transitionTo(FrameBurstPhase.warning);
      case FrameBurstPhase.warning:
        if (_elapsed >= warningSeconds) _transitionTo(FrameBurstPhase.active);
      case FrameBurstPhase.active:
        if (_elapsed >= activeSeconds) _transitionTo(FrameBurstPhase.normal);
    }
    return snapshot;
  }

  FrameBurstSnapshot get snapshot {
    final duration = switch (_phase) {
      FrameBurstPhase.normal => normalSeconds,
      FrameBurstPhase.warning => warningSeconds,
      FrameBurstPhase.active => activeSeconds,
    };
    return FrameBurstSnapshot(
      phase: _phase,
      phaseProgress: duration <= 0
          ? 1
          : (_elapsed / duration).clamp(0, 1).toDouble(),
      speedMultiplier: speedMultiplier,
    );
  }

  void reset() {
    _phase = FrameBurstPhase.normal;
    _elapsed = 0;
  }

  void _transitionTo(FrameBurstPhase next) {
    _phase = next;
    _elapsed = 0;
  }
}
