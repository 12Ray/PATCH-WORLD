import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/wall_component.dart';
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
