import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/combat_entity_budget.dart';

void main() {
  test('enemy projectile budget enforces its cap and releases slots', () {
    final budget = CombatEntityBudget(maximumEnemyProjectiles: 3);

    expect(budget.tryReserveEnemyProjectile(), isTrue);
    expect(budget.tryReserveEnemyProjectile(), isTrue);
    expect(budget.tryReserveEnemyProjectile(), isTrue);
    expect(budget.tryReserveEnemyProjectile(), isFalse);
    expect(budget.activeEnemyProjectiles, 3);

    budget.releaseEnemyProjectile();
    expect(budget.activeEnemyProjectiles, 2);
    expect(budget.tryReserveEnemyProjectile(), isTrue);
    expect(budget.activeEnemyProjectiles, 3);
  });

  test('projectile budget release is safe after an empty lifecycle', () {
    final budget = CombatEntityBudget(maximumEnemyProjectiles: 1);
    budget.releaseEnemyProjectile();
    expect(budget.activeEnemyProjectiles, 0);
  });
}
