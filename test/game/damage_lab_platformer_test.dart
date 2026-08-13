import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('Damage Lab is three combat cells followed by a staged boss', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final room = game.world.activeRoom! as RoomOneController;
    final encounterGates = room.children
        .whereType<BossSealGateComponent>()
        .toList(growable: false);
    expect(encounterGates, hasLength(3));
    expect(encounterGates.every((gate) => !gate.isUnlocked), isTrue);
    expect(
      room.children.whereType<PlatformSurfaceComponent>(),
      hasLength(greaterThanOrEqualTo(20)),
    );
    expect(room.worldSize.x, 3840);
    expect(room.children.whereType<PlatformerEnemyComponent>(), hasLength(6));
    expect(
      room.children
          .whereType<PlatformerEnemyComponent>()
          .map((enemy) => enemy.archetype)
          .toSet(),
      const <PlatformerEnemyArchetype>{
        PlatformerEnemyArchetype.patchMite,
        PlatformerEnemyArchetype.checksumHopper,
        PlatformerEnemyArchetype.pulseTurret,
        PlatformerEnemyArchetype.repairLeech,
      },
    );
    expect(game.world.player.position, room.playerSpawn);

    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));
    game.world.player.position.y = room.killPlaneY + 10;
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.world.player.position, room.playerSpawn);
    expect(game.world.player.integrity, game.world.player.maxIntegrity - 1);

    for (final x in <double>[855, 1810, 2750]) {
      game.world.player.position.setValues(x, 1018);
      expect(room.tryInteract(game.world.player), isTrue);
      await tester.pump();
    }
    expect(game.damageLabProgress.questComplete, isTrue);
    expect(room.qaRecordCount, 3);
    game.world.player.position.setValues(2515, 1018);
    expect(room.tryInteract(game.world.player), isTrue);
    expect(game.runItems.contains(RunItemId.conduitHeart), isTrue);
    expect(game.damageLabProgress.questRewardClaimed, isTrue);

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
      expect(encounterGates[cell].isUnlocked, isTrue);
    }

    game.world.player.position.setValues(3100, 988);
    for (var frame = 0; frame < 70; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final boss = room.children.whereType<OverflowWardenBossComponent>().single;
    expect(boss.phase, OverflowWardenPhase.shielded);
    boss.receiveHealing(99);
    expect(boss.phase, OverflowWardenPhase.overflowing);
    for (var frame = 0; frame < 34; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(room.isCompleted, isTrue);
  });
}
