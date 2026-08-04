import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/systems/survival_crowd_separation.dart';

void main() {
  test('neighbors outside the separation radius contribute no force', () {
    final steering = SurvivalCrowdSeparation.steering(
      entityId: 'a',
      position: Vector2.zero(),
      separationRadius: 40,
      neighbors: <SurvivalCrowdNeighbor>[
        SurvivalCrowdNeighbor(entityId: 'b', position: Vector2(41, 0)),
      ],
    );

    expect(steering.length2, 0);
  });

  test('separation force increases linearly at close range', () {
    final steering = SurvivalCrowdSeparation.steering(
      entityId: 'a',
      position: Vector2.zero(),
      separationRadius: 40,
      neighbors: <SurvivalCrowdNeighbor>[
        SurvivalCrowdNeighbor(entityId: 'b', position: Vector2(20, 0)),
      ],
    );

    expect(steering.x, closeTo(-0.5, 0.001));
    expect(steering.y, closeTo(0, 0.001));
  });

  test('exact overlap resolves symmetrically and total force is capped', () {
    final neighbors = <SurvivalCrowdNeighbor>[
      SurvivalCrowdNeighbor(entityId: 'a', position: Vector2.zero()),
      SurvivalCrowdNeighbor(entityId: 'b', position: Vector2.zero()),
      SurvivalCrowdNeighbor(entityId: 'c', position: Vector2(1, 0)),
    ];
    final a = SurvivalCrowdSeparation.steering(
      entityId: 'a',
      position: Vector2.zero(),
      separationRadius: 40,
      neighbors: neighbors.take(2),
    );
    final b = SurvivalCrowdSeparation.steering(
      entityId: 'b',
      position: Vector2.zero(),
      separationRadius: 40,
      neighbors: neighbors.take(2),
    );
    final crowded = SurvivalCrowdSeparation.steering(
      entityId: 'a',
      position: Vector2.zero(),
      separationRadius: 40,
      neighbors: neighbors,
    );

    expect(a.x, closeTo(-b.x, 0.001));
    expect(a.y, closeTo(-b.y, 0.001));
    expect(a.length, closeTo(1, 0.001));
    expect(crowded.length, lessThanOrEqualTo(1.000001));
  });
}
