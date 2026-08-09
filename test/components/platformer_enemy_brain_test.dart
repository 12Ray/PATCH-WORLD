import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer/platformer_enemy_brain.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

void main() {
  test('all fifteen enemies own a unique signature brain action', () {
    final actions = <String>{};
    for (final archetype in PlatformerEnemyArchetype.values) {
      actions.add(PlatformerEnemyBrain.forArchetype(archetype.name).actionId);
    }
    expect(actions, hasLength(15));
  });
}
