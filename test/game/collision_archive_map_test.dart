import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';

import '../support/room_boot_assertion.dart';

void main() {
  testWidgets('loads Collision Archive platformer roster and geometry', (
    tester,
  ) async {
    await expectPlatformerRoomBoot(
      tester,
      roomId: RoomId.collisionArchive,
      expectedSpawn: Vector2(70, 988),
      expectedArchetypes: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.vectorRam,
        PlatformerEnemyArchetype.polarityDrone,
        PlatformerEnemyArchetype.phaseMimic,
        PlatformerEnemyArchetype.shardLobber,
      ],
    );
  });
}
