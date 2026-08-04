enum PhaseLeakPhase { solid, warning, open }

final class PhaseLeakController {
  PhaseLeakController({
    this.solidSeconds = 6,
    this.warningSeconds = 0.6,
    this.openSeconds = 1.5,
  });

  final double solidSeconds;
  final double warningSeconds;
  final double openSeconds;
  PhaseLeakPhase _phase = PhaseLeakPhase.solid;
  double _elapsed = 0;

  PhaseLeakPhase get phase => _phase;

  bool update(double dt) {
    if (dt <= 0) return false;
    _elapsed += dt;
    final before = _phase;
    final duration = switch (_phase) {
      PhaseLeakPhase.solid => solidSeconds,
      PhaseLeakPhase.warning => warningSeconds,
      PhaseLeakPhase.open => openSeconds,
    };
    if (_elapsed >= duration) {
      _elapsed = 0;
      _phase = switch (_phase) {
        PhaseLeakPhase.solid => PhaseLeakPhase.warning,
        PhaseLeakPhase.warning => PhaseLeakPhase.open,
        PhaseLeakPhase.open => PhaseLeakPhase.solid,
      };
    }
    return before != _phase;
  }

  void reset() {
    _phase = PhaseLeakPhase.solid;
    _elapsed = 0;
  }
}
