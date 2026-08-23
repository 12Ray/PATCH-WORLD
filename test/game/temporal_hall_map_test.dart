import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
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
      expectedNode: CampaignNodeId.temporalAscent,
      expectedSpawn: Vector2(90, 864),
      expectedArchetypes: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.tickRunner,
        PlatformerEnemyArchetype.echoBat,
        PlatformerEnemyArchetype.delaySniper,
        PlatformerEnemyArchetype.rewindSkater,
      ],
    );
  });
}
