import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';

Future<void> expectTiledRoomBoot(
  WidgetTester tester, {
  required RoomId roomId,
  required Vector2 expectedSpawn,
}) async {
  final game = PatchWorldGame(initialRoom: roomId);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.pump();
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  await tester.pump();
  expect(game.world.player.position, expectedSpawn);
  expect(
    game.world.activeRoom!.children.whereType<WallComponent>().length,
    greaterThanOrEqualTo(4),
  );
}

Future<void> expectPlatformerRoomBoot(
  WidgetTester tester, {
  required RoomId roomId,
  required Vector2 expectedSpawn,
  required List<PlatformerEnemyArchetype> expectedArchetypes,
}) async {
  final game = PatchWorldGame(initialRoom: roomId);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.pump();
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  await tester.pump();
  expect(game.world.player.position, expectedSpawn);
  expect(
    game.world.activeRoom!.children.whereType<PlatformSurfaceComponent>(),
    hasLength(greaterThanOrEqualTo(20)),
  );
  final geometry = game.world.activeRoom! as PlatformerRoomGeometry;
  expect(geometry.worldSize.x, greaterThanOrEqualTo(2880));
  expect(
    game.world.activeRoom!.children.whereType<RoomHazardComponent>(),
    hasLength(greaterThanOrEqualTo(2)),
  );
  expect(
    game.world.activeRoom!.children.whereType<JumpPadComponent>(),
    hasLength(greaterThanOrEqualTo(2)),
  );
  expect(
    game.world.activeRoom!.children.whereType<CheckpointBeaconComponent>(),
    hasLength(3),
  );
  final enemies = game.world.activeRoom!.children
      .whereType<PlatformerEnemyComponent>()
      .toList(growable: false);
  expect(enemies, hasLength(6));
  expect(enemies.where((enemy) => enemy.archetype.isMidBoss), isEmpty);
  expect(
    enemies.map((enemy) => enemy.archetype).toSet(),
    expectedArchetypes.toSet(),
  );
  expect(
    game.world.activeRoom!.children.whereType<CampaignChapterBossComponent>(),
    hasLength(1),
  );
}
