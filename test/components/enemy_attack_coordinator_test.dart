import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer/enemy_attack_coordinator.dart';

void main() {
  test('only one enemy owns the primary attack window', () {
    final coordinator = EnemyAttackCoordinator();
    final first = Object();
    final second = Object();

    expect(coordinator.tryAcquire(first), isTrue);
    expect(coordinator.tryAcquire(second), isFalse);
    expect(coordinator.isOwner(first), isTrue);

    coordinator.release(first);
    expect(coordinator.tryAcquire(second), isTrue);
  });

  test('activation staggering is deterministic and bounded', () {
    final delays = <double>{
      for (var index = 0; index < 15; index += 1)
        enemyActivationStagger(archetypeIndex: index, spawnX: index * 91),
    };
    expect(delays, everyElement(inInclusiveRange(.35, .75)));
    expect(delays.length, greaterThan(1));
    expect(
      enemyActivationStagger(archetypeIndex: 4, spawnX: 512),
      enemyActivationStagger(archetypeIndex: 4, spawnX: 512),
    );
  });
}
