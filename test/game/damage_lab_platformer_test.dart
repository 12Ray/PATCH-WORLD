import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('Damage Lab RoomId boots the JSON workshop node', (tester) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final room = game.world.activeRoom! as DamageLabNodeController;
    expect(room.campaignNodeId, CampaignNodeId.damageWorkshop);
    expect(room.layout, same(game.damageLabRoomLayouts.room(room.nodeId)));
    expect(room.worldSize, Vector2(1920, 1080));
    expect(
      room.children.whereType<PlatformSurfaceComponent>().length,
      greaterThanOrEqualTo(room.layout.surfaces.length),
    );
    expect(
      room.children
          .whereType<PlatformerEnemyComponent>()
          .map((enemy) => enemy.archetype)
          .toSet(),
      const <PlatformerEnemyArchetype>{
        PlatformerEnemyArchetype.patchMite,
        PlatformerEnemyArchetype.checksumHopper,
      },
    );
    expect(game.world.player.position, room.playerSpawn);

    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));
    game.world.player.position.y = room.killPlaneY + 10;
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.world.player.position, room.playerSpawn);
    expect(game.world.player.integrity, game.world.player.maxIntegrity - 1);

    game.world.player.position.x = 1500;
    game.syncCampaignExploration();
    expect(
      game.campaignExploration.currentNode,
      CampaignNodeId.damageWorkshop,
      reason: 'independent scenes must not infer another node from player X',
    );
  });
}
