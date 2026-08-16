final class CombatEntityBudget {
  CombatEntityBudget({this.maximumEnemyProjectiles = 48});

  final int maximumEnemyProjectiles;
  int _activeEnemyProjectiles = 0;

  int get activeEnemyProjectiles => _activeEnemyProjectiles;

  bool tryReserveEnemyProjectile() {
    if (_activeEnemyProjectiles >= maximumEnemyProjectiles) return false;
    _activeEnemyProjectiles += 1;
    return true;
  }

  void releaseEnemyProjectile() {
    if (_activeEnemyProjectiles > 0) _activeEnemyProjectiles -= 1;
  }
}
