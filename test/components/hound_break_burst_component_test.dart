import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/hound_break_burst_component.dart';

void main() {
  test('hound break burst keeps score and expires after feedback window', () {
    final burst = HoundBreakBurstComponent(
      position: Vector2(200, 180),
      score: 320,
    );

    expect(burst.text, 'BREAK CONFIRMED  +320');
    expect(burst.score, 320);
    expect(burst.isExpired, isFalse);

    burst.update(HoundBreakBurstComponent.lifetimeSeconds + 0.01);
    expect(burst.isExpired, isTrue);
  });
}
