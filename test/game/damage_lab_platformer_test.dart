import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
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

  testWidgets('Damage Lab boots with platform geometry and resets pit falls', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final room = game.world.activeRoom! as RoomOneController;
    expect(room.children.whereType<PlatformSurfaceComponent>(), hasLength(9));
    expect(room.children.whereType<PlatformerEnemyComponent>(), hasLength(5));
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
        PlatformerEnemyArchetype.overflowWarden,
      },
    );
    expect(game.world.player.position, room.playerSpawn);

    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));
    game.world.player.position.y = PatchWorldGame.logicalHeight + 60;
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.world.player.position, room.playerSpawn);
    expect(game.world.player.integrity, game.world.player.maxIntegrity - 1);

    game.world.player.position.setValues(220, 448);
    for (var frame = 0; frame < 100; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final actions = <PlatformerEnemyArchetype, String?>{
      for (final enemy in room.children.whereType<PlatformerEnemyComponent>())
        enemy.archetype: enemy.activeActionId,
    };
    expect(actions[PlatformerEnemyArchetype.patchMite], 'patchMite.bite');
    expect(
      actions[PlatformerEnemyArchetype.checksumHopper],
      'checksumHopper.leap',
    );
    expect(
      actions[PlatformerEnemyArchetype.pulseTurret],
      'pulseTurret.lockedShot',
    );
    expect(
      actions[PlatformerEnemyArchetype.repairLeech],
      'repairLeech.channel',
    );
    final warden = room.children
        .whereType<PlatformerEnemyComponent>()
        .singleWhere(
          (enemy) => enemy.archetype == PlatformerEnemyArchetype.overflowWarden,
        );
    expect(actions[PlatformerEnemyArchetype.overflowWarden], isNull);
    expect(warden.isDormant, isTrue);

    for (final enemy
        in room.children
            .whereType<PlatformerEnemyComponent>()
            .where((enemy) => !enemy.archetype.isMidBoss)
            .toList()) {
      enemy.receiveDamage(99);
    }
    await tester.pump();
    expect(room.defeatedCount, 4);
    expect(warden.isDormant, isFalse);
  });
}
