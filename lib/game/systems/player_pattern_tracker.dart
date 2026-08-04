enum DirectionBucket { up, down, left, right }

final class PatternSnapshot {
  const PatternSnapshot({
    required this.preferredDirection,
    required this.confidence,
    required this.averageAttackInterval,
  });
  final DirectionBucket? preferredDirection;
  final double confidence;
  final double? averageAttackInterval;
}

final class PlayerPatternTracker {
  final List<DirectionBucket> _directions = <DirectionBucket>[];
  final List<double> _attackIntervals = <double>[];
  double _sinceAttack = 0;
  bool _hasAttack = false;

  void update(double dt) {
    if (dt > 0) _sinceAttack += dt;
  }

  void recordMovement(double x, double y) {
    if (x == 0 && y == 0) return;
    final bucket = x.abs() >= y.abs()
        ? (x < 0 ? DirectionBucket.left : DirectionBucket.right)
        : (y < 0 ? DirectionBucket.up : DirectionBucket.down);
    _directions.add(bucket);
    if (_directions.length > 120) _directions.removeAt(0);
  }

  void recordAttack() {
    if (_hasAttack) _attackIntervals.add(_sinceAttack);
    _hasAttack = true;
    _sinceAttack = 0;
    if (_attackIntervals.length > 12) _attackIntervals.removeAt(0);
  }

  PatternSnapshot get snapshot {
    if (_directions.isEmpty) {
      return PatternSnapshot(
        preferredDirection: null,
        confidence: 0,
        averageAttackInterval: _averageInterval,
      );
    }
    final counts = <DirectionBucket, int>{};
    for (final direction in _directions) {
      counts[direction] = (counts[direction] ?? 0) + 1;
    }
    final preferred = counts.entries.reduce(
      (a, b) => a.value >= b.value ? a : b,
    );
    return PatternSnapshot(
      preferredDirection: preferred.key,
      confidence: preferred.value / _directions.length,
      averageAttackInterval: _averageInterval,
    );
  }

  double? get _averageInterval => _attackIntervals.isEmpty
      ? null
      : _attackIntervals.reduce((a, b) => a + b) / _attackIntervals.length;

  void reset() {
    _directions.clear();
    _attackIntervals.clear();
    _sinceAttack = 0;
    _hasAttack = false;
  }
}
