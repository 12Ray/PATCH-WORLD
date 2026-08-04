import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/phase_execution_burst_component.dart';

void main() {
  test('phase execution burst exposes the linked reward and expires', () {
    final burst = PhaseExecutionBurstComponent(
      position: Vector2(200, 180),
      score: 800,
    );

    expect(burst.text, 'PHASE EXECUTION  +800  // DATA +1');
    expect(burst.score, 800);
    expect(burst.isExpired, isFalse);

    burst.update(PhaseExecutionBurstComponent.lifetimeSeconds + 0.01);
    expect(burst.isExpired, isTrue);
  });
}
