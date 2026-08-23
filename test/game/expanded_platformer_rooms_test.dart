import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'independent JSON scene uses a persistent checkpoint and camera',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.damageLab);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);

      final room = game.world.activeRoom! as DamageLabNodeController;
      expect(room.campaignNodeId, CampaignNodeId.damageWorkshop);
      expect(room.worldSize, Vector2(1920, 1080));

      final checkpoint = room.children
          .whereType<CampaignCheckpointComponent>()
          .single;
      game.world.player.position.setFrom(checkpoint.position);
      expect(room.tryInteract(game.world.player), isTrue);
      expect(checkpoint.isActive, isTrue);
      expect(
        game.campaignExploration.checkpointNodeId,
        CampaignNodeId.damageWorkshop,
      );
      expect(
        room.respawnPointFor(Vector2(1500, room.killPlaneY)),
        checkpoint.position - Vector2(0, 36),
      );

      game.resumeEngine();
      game.world.player.position.setValues(1500, 540);
      for (var frame = 0; frame < 20; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.camera.viewfinder.position.x, greaterThan(480));
      expect(room.killPlaneY, greaterThan(room.worldSize.y));
      game.syncCampaignExploration();
      expect(
        game.campaignExploration.currentNode,
        CampaignNodeId.damageWorkshop,
      );
    },
  );
}
