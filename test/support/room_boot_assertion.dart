import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/rule_context.dart';

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
    hasLength(greaterThanOrEqualTo(9)),
  );
  final enemies = game.world.activeRoom!.children
      .whereType<PlatformerEnemyComponent>()
      .toList(growable: false);
  expect(enemies, hasLength(5));
  expect(enemies.where((enemy) => enemy.archetype.isMidBoss), hasLength(1));
  expect(
    enemies.map((enemy) => enemy.archetype).toSet(),
    expectedArchetypes.toSet(),
  );
}
