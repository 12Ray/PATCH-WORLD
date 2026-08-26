/// Grants one primary attack turn at a time to enemies sharing an encounter.
///
/// Movement and recovery continue independently; only telegraph/active windows
/// are serialized so a two-enemy wave reads as a deliberate exchange instead
/// of two identical attacks firing on the same frame.
final class EnemyAttackCoordinator {
  Object? _owner;

  bool tryAcquire(Object contender) {
    if (_owner == null || identical(_owner, contender)) {
      _owner = contender;
      return true;
    }
    return false;
  }

  void release(Object contender) {
    if (identical(_owner, contender)) _owner = null;
  }

  bool isOwner(Object contender) => identical(_owner, contender);
  bool get hasOwner => _owner != null;
}

/// Stable first-attack offset derived from authored placement rather than a
/// random number. Re-entering a room therefore preserves a learnable rhythm.
double enemyActivationStagger({
  required int archetypeIndex,
  required double spawnX,
}) {
  final slot = ((spawnX ~/ 96) + archetypeIndex).abs() % 3;
  return .35 + slot * .20;
}
