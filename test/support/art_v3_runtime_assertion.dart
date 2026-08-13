import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
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
  await waitForArtV3(
    tester,
    () =>
        game.world.player.hasCompleteArtV3Visuals &&
        (roomId != RoomId.damageLab ||
            room.children
                .whereType<OverflowWardenBossComponent>()
                .single
                .hasArtV3Visual) &&
        (roomId == RoomId.damageLab ||
            room.children
                .whereType<CampaignChapterBossComponent>()
                .single
                .hasArtV3Visual) &&
        room.children.whereType<PlatformerEnemyComponent>().every(
          (enemy) => enemy.hasArtV3Visual,
        ) &&
        room.children.whereType<PlatformSurfaceComponent>().every(
          (surface) => surface.hasArtV3Foreground,
        ),
  );

  expect(game.world.player.hasCompleteArtV3Visuals, isTrue);
  if (roomId == RoomId.damageLab) {
    expect(
      room.children
          .whereType<OverflowWardenBossComponent>()
          .single
          .hasArtV3Visual,
      isTrue,
    );
  } else {
    expect(
      room.children
          .whereType<CampaignChapterBossComponent>()
          .single
          .hasArtV3Visual,
      isTrue,
    );
  }
  expect(room.children.whereType<PlatformerEnemyComponent>(), hasLength(6));
  expect(
    room.children.whereType<PlatformerEnemyComponent>().every(
      (enemy) => enemy.hasArtV3Visual,
    ),
    isTrue,
  );
  expect(
    room.children.whereType<PlatformSurfaceComponent>().every(
      (surface) => surface.hasArtV3Foreground,
    ),
    isTrue,
  );
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
        room.children.whereType<PlatformSurfaceComponent>().every(
          (surface) => surface.hasArtV3Foreground,
        ),
  );

  expect(game.world.player.hasCompleteArtV3Visuals, isTrue);
  expect(room.boss.hasArtV3Visual, isTrue);
  expect(room.terminal.hasArtV3Foreground, isTrue);
  expect(
    room.children.whereType<PlatformSurfaceComponent>().every(
      (surface) => surface.hasArtV3Foreground,
    ),
    isTrue,
  );
}

Future<void> waitForArtV3(
  WidgetTester tester,
  bool Function() predicate,
) async {
  for (var attempt = 0; attempt < 60; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (predicate()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
  }
}
