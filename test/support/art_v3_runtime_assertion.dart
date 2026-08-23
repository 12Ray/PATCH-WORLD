import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

Future<void> expectCampaignRoomArtV3Loaded(
  WidgetTester tester,
  RoomId roomId,
) async {
  final game = PatchWorldGame(initialRoom: roomId);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);

  final room = game.world.activeRoom!;
  final expectedNode = switch (roomId) {
    RoomId.damageLab => CampaignNodeId.damageWorkshop,
    RoomId.temporalHall => CampaignNodeId.temporalAscent,
    RoomId.collisionArchive => CampaignNodeId.collisionCompression,
    _ => throw ArgumentError.value(roomId, 'roomId', 'Expected campaign room.'),
  };
  expect(room, isA<CampaignNodeRoom>());
  expect((room as CampaignNodeRoom).campaignNodeId, expectedNode);

  final environmentAsset = switch (room) {
    DamageLabNodeController controller => controller.environmentAsset,
    RegionalCampaignNodeController controller => controller.environmentAsset,
    _ => null,
  };
  expect(environmentAsset, isNotNull);

  bool visualsReady() {
    final enemies = room.children.whereType<PlatformerEnemyComponent>();
    final renderedSurfaces = room.children
        .whereType<PlatformSurfaceComponent>()
        .where((surface) => surface.renderArtwork);
    return game.world.player.hasCompleteArtV3Visuals &&
        enemies.isNotEmpty &&
        enemies.every((enemy) => enemy.hasArtV3Visual) &&
        renderedSurfaces.every((surface) => surface.hasArtV3Foreground);
  }

  await waitForArtV3(tester, visualsReady);
  expect(visualsReady(), isTrue);
}

Future<void> expectOptimizerArtV3Loaded(WidgetTester tester) async {
  final game = PatchWorldGame(initialRoom: RoomId.optimizerCore);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);

  final room = game.world.activeRoom! as BossRoomController;
  await waitForArtV3(
    tester,
    () =>
        game.world.player.hasCompleteArtV3Visuals &&
        room.boss.hasArtV3Visual &&
        room.terminal.hasArtV3Foreground &&
        room.children
            .whereType<PlatformSurfaceComponent>()
            .where((surface) => surface.renderArtwork)
            .every((surface) => surface.hasArtV3Foreground),
  );

  expect(game.world.player.hasCompleteArtV3Visuals, isTrue);
  expect(room.boss.hasArtV3Visual, isTrue);
  expect(room.terminal.hasArtV3Foreground, isTrue);
  expect(
    room.children
        .whereType<PlatformSurfaceComponent>()
        .where((surface) => surface.renderArtwork)
        .every((surface) => surface.hasArtV3Foreground),
    isTrue,
  );
}

Future<void> waitForArtV3(
  WidgetTester tester,
  bool Function() predicate,
) async {
  // GitHub's shared Linux runners decode the full campaign image cache much
  // more slowly than a local desktop. Keep polling the real readiness state.
  for (var attempt = 0; attempt < 240; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (predicate()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
}
