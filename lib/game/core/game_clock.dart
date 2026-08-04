final class GameClock {
  double _realDt = 0;
  double _playerStatusDt = 0;
  double _simulationDt = 0;
  double _enemyDt = 0;

  double get realDt => _realDt;
  double get playerStatusDt => _playerStatusDt;
  double get simulationDt => _simulationDt;
  double get enemyDt => _enemyDt;
  bool get isSimulationFrozen => _simulationDt == 0;

  void beginFrame({
    required double realDt,
    required bool simulationAdvances,
    required double enemySpeedMultiplier,
  }) {
    final safeDt = realDt.clamp(0, 1 / 15).toDouble();
    _realDt = safeDt;
    _playerStatusDt = safeDt;
    _simulationDt = simulationAdvances ? safeDt : 0;
    _enemyDt = _simulationDt * enemySpeedMultiplier;
  }

  void clear() {
    _realDt = 0;
    _playerStatusDt = 0;
    _simulationDt = 0;
    _enemyDt = 0;
  }
}
