import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

Future<void> expectLaterChapterOverhaul(
  WidgetTester tester, {
  required RoomId roomId,
  required CampaignChapterBossKind bossKind,
  required RunItemId questItem,
  required RunItemId bossItem,
}) async {
  final game = PatchWorldGame(initialRoom: roomId);
  final CampaignFloorState progress;
  final CampaignNodeId expectedBossNode;
  switch (roomId) {
    case RoomId.temporalHall:
      progress = game.temporalHallProgress;
      expectedBossNode = CampaignNodeId.chronoJailer;
    case RoomId.collisionArchive:
      progress = game.collisionArchiveProgress;
      expectedBossNode = CampaignNodeId.kernelChimera;
    case _:
      throw ArgumentError.value(roomId, 'roomId', 'Expected a regional room.');
  }
  progress
    ..clearedEncounterIds.addAll(const <int>{0, 1, 2})
    ..completedObjectiveIds.addAll(const <int>{0, 1, 2});

  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);

  final room = game.world.activeRoom! as RegionalCampaignNodeController;
  expect(room.campaignNodeId, expectedBossNode);
  expect(room.layout, same(game.regionalRoomLayouts.room(expectedBossNode)));
  expect(room.isBossRoom, isTrue);
  expect(room.worldSize, Vector2(960, 540));
  expect(room.questRewardItem, questItem);
  expect(room.bossRewardItem, bossItem);
  expect(progress.allRoomsComplete, isTrue);
  expect(game.campaignExploration.currentNode, expectedBossNode);
  expect(room.children.whereType<PlatformerEnemyComponent>(), isEmpty);
  expect(
    room.children.whereType<PlatformSurfaceComponent>().length,
    greaterThanOrEqualTo(room.layout.surfaces.length),
  );
  expect(
    room.children.whereType<CampaignChapterBossComponent>().single.kind,
    bossKind,
  );
}
