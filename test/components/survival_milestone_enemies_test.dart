import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/composite_component.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';

void main() {
  test('elite sentinel exposes its stronger readable combat profile', () {
    final elite = SentinelComponent(
      entityId: 'elite-test',
      position: Vector2.zero(),
      isElite: true,
      healthMaximum: 5,
      fireInterval: 1,
      telegraphSeconds: 0.42,
      projectileSpeed: 165,
    );

    expect(elite.isElite, isTrue);
    expect(elite.health.max, 5);
    expect(elite.fireInterval, 1);
    expect(elite.projectileSpeed, 165);
  });

  test('survival composite reports a mini-boss defeat once', () {
    var defeats = 0;
    final composite = CompositeComponent(
      entityId: 'composite-test',
      position: Vector2.zero(),
      combinedHealth: 8,
      onDefeated: () => defeats += 1,
    );

    composite.receiveDamage(10);

    expect(composite.health.isDefeated, isTrue);
    expect(defeats, 1);
  });
}
