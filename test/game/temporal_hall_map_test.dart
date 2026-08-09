import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

import '../support/room_boot_assertion.dart';

void main() {
  testWidgets('loads Temporal Hall platformer roster and geometry', (
    tester,
  ) async {
    await expectPlatformerRoomBoot(
      tester,
      roomId: RoomId.temporalHall,
      expectedSpawn: Vector2(70, 448),
      expectedArchetypes: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.tickRunner,
        PlatformerEnemyArchetype.echoBat,
        PlatformerEnemyArchetype.delaySniper,
        PlatformerEnemyArchetype.rewindSkater,
        PlatformerEnemyArchetype.chronoJailer,
      ],
    );
  });
}
