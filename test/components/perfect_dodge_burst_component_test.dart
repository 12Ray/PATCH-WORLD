import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/perfect_dodge_burst_component.dart';

void main() {
  test('perfect dodge burst keeps score and expires after feedback window', () {
    final burst = PerfectDodgeBurstComponent(
      position: Vector2(300, 220),
      score: 326,
    );

    expect(burst.text, 'PERFECT DODGE  +326');
    burst.update(0.1);
    expect(burst.position.y, closeTo(217.6, 0.001));
    expect(burst.isExpired, isFalse);
    burst.update(PerfectDodgeBurstComponent.lifetimeSeconds);
    expect(burst.isExpired, isTrue);
  });
}
