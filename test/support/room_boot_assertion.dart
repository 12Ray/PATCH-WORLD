import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

Future<void> expectPlatformerRoomBoot(
  WidgetTester tester, {
  required RoomId roomId,
  required CampaignNodeId expectedNode,
  required Vector2 expectedSpawn,
  required List<PlatformerEnemyArchetype> expectedArchetypes,
}) async {
  final game = PatchWorldGame(initialRoom: roomId);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.pump();
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  await tester.pump();

  final room = game.world.activeRoom! as RegionalCampaignNodeController;
  expect(room.campaignNodeId, expectedNode);
  expect(room.layout, same(game.regionalRoomLayouts.room(expectedNode)));
  expect(game.world.player.position, expectedSpawn);
  expect(room.worldSize, Vector2(1920, 1080));
  expect(room.environmentAsset, isNotNull);
  expect(
    room.children.whereType<PlatformSurfaceComponent>().length,
    greaterThanOrEqualTo(room.layout.surfaces.length),
  );
  expect(room.children.whereType<CampaignCheckpointComponent>(), hasLength(1));

  final enemies = room.children.whereType<PlatformerEnemyComponent>().toList(
    growable: false,
  );
  expect(enemies, hasLength(expectedArchetypes.length));
  expect(enemies.where((enemy) => enemy.archetype.isMidBoss), isEmpty);
  expect(
    enemies.map((enemy) => enemy.archetype).toSet(),
    expectedArchetypes.toSet(),
  );
  expect(room.children.whereType<CampaignChapterBossComponent>(), isEmpty);
}
