import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';

void main() {
  test('duplicates each eligible enemy at most once', () {
    final state = RunState()..selectPatch(RuleIds.duplicateFault);
    var spawned = 0;
    final system = DuplicateFaultSystem(
      runState: state,
      spawnDuplicate:
          ({required archetype, required position, required sourceEntityId}) {
            spawned += 1;
          },
    );
    final crawler = CrawlerComponent(
      entityId: 'source',
      position: Vector2.zero(),
    );
    system.onPlayerDamageCommitted(crawler);
    system.onPlayerDamageCommitted(crawler);
    expect(spawned, 1);
  });

  test('echo crawlers cannot duplicate', () {
    final crawler = CrawlerComponent(
      entityId: 'echo',
      position: Vector2.zero(),
      canDuplicate: false,
    );
    expect(crawler.claimDuplicate(), isFalse);
  });
}
