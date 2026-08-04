import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/critical_flow_ring_component.dart';

void main() {
  test('critical flow ring expands for a short readable burst', () {
    final ring = CriticalFlowRingComponent(position: Vector2(480, 270));

    ring.update(0.2);
    expect(ring.age, closeTo(0.2, 0.001));
    expect(ring.isExpired, isFalse);

    ring.update(CriticalFlowRingComponent.duration);
    expect(ring.isExpired, isTrue);
  });
}
