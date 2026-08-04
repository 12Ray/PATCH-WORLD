import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rooms/room_three_controller.dart';

void main() {
  test('merge zone only accepts targets inside the containment core', () {
    final zone = MergeZoneComponent(position: Vector2(480, 270));

    expect(zone.containsTarget(Vector2(520, 270)), isTrue);
    expect(zone.containsTarget(Vector2(551, 270)), isFalse);
  });
}
