import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/effects/volatile_cache_component.dart';

void main() {
  test('cache collects once inside its pickup radius', () {
    final player = Vector2(27, 0);
    var collected = 0;
    var expired = 0;
    final cache = VolatileCacheComponent(
      position: Vector2.zero(),
      playerPosition: () => player,
      onCollected: (_) => collected += 1,
      onExpired: (_) => expired += 1,
    );

    cache.update(0.016);
    cache.update(20);

    expect(cache.isResolved, isTrue);
    expect(collected, 1);
    expect(expired, 0);
  });

  test('cache expires once after twelve seconds', () {
    final player = Vector2(200, 200);
    var collected = 0;
    var expired = 0;
    final cache = VolatileCacheComponent(
      position: Vector2.zero(),
      playerPosition: () => player,
      onCollected: (_) => collected += 1,
      onExpired: (_) => expired += 1,
    );

    cache.update(11.9);
    expect(cache.isResolved, isFalse);
    cache.update(0.2);
    cache.update(1);

    expect(cache.isResolved, isTrue);
    expect(collected, 0);
    expect(expired, 1);
  });
}
