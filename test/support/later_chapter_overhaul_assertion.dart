import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/four_cell_chapter_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

Future<void> expectLaterChapterOverhaul(
  WidgetTester tester, {
  required RoomId roomId,
  required CampaignChapterBossKind bossKind,
  required RunItemId questItem,
  required RunItemId bossItem,
}) async {
  final game = PatchWorldGame(initialRoom: roomId);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  final room = game.world.activeRoom! as FourCellChapterController;
  game.resumeEngine();
  await tester.pump(const Duration(milliseconds: 16));

  expect(room.worldSize, Vector2(3840, 1080));
  expect(room.encounterGates, hasLength(3));
  expect(room.encounterGates.every((gate) => !gate.isUnlocked), isTrue);
  expect(room.boss?.kind, bossKind);

  for (final x in <double>[855, 1810, 2750]) {
    game.world.player.position.setValues(x, 1018);
    expect(room.tryInteract(game.world.player), isTrue);
    await tester.pump();
  }
  game.world.player.position.setValues(2515, 1018);
  expect(room.tryInteract(game.world.player), isTrue);
  expect(game.runItems.contains(questItem), isTrue);

  for (var cell = 0; cell < 3; cell += 1) {
    game.world.player.position.setValues(cell * 960 + 140, 988);
    await tester.pump(const Duration(milliseconds: 16));
    final cellEnemies = room.children
        .whereType<PlatformerEnemyComponent>()
        .where(
          (enemy) =>
              enemy.position.x >= cell * 960 &&
              enemy.position.x < (cell + 1) * 960,
        )
        .toList(growable: false);
    expect(cellEnemies, hasLength(2));
    for (final enemy in cellEnemies) {
      expect(enemy.isDormant, isFalse);
      enemy.receiveDamage(99);
    }
    await tester.pump();
    expect(room.clearedEncounterCount, cell + 1);
    expect(room.encounterGates[cell].isUnlocked, isTrue);
  }

  game.world.player.position.setValues(3100, 988);
  for (var frame = 0; frame < 70; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final boss = room.boss!;
  expect(boss.phase, CampaignChapterBossPhase.phaseOne);
  boss.receiveDamage(7);
  expect(boss.phase, CampaignChapterBossPhase.phaseTwo);
  boss.receiveDamage(7);
  expect(boss.phase, CampaignChapterBossPhase.phaseThree);
  boss.receiveDamage(6);
  expect(boss.phase, CampaignChapterBossPhase.defeated);
  for (var frame = 0; frame < 24; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(room.isCompleted, isTrue);

  game.world.player.position.setValues(3450, 1018);
  expect(room.tryInteract(game.world.player), isTrue);
  expect(game.runItems.contains(bossItem), isTrue);
}
