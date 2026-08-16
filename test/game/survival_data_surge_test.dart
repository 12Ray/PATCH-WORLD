import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/effects/data_shard_component.dart';
import 'package:patch_world/game/components/effects/data_surge_ring_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'six data charge triggers surge, preserves remainder, and buffs weapon',
    (tester) async {
      final game = PatchWorldGame();
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget<PatchWorldGame>(
            game: game,
            overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
              OverlayIds.title: (_, _) => const SizedBox.shrink(),
              OverlayIds.hud: (_, _) => const SizedBox.shrink(),
              OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
              OverlayIds.survivalUpgrade: (_, _) => const SizedBox.shrink(),
              OverlayIds.survivalWeaponUpgrade: (_, _) =>
                  const SizedBox.shrink(),
            },
          ),
        ),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      game.startSurvivalRun();
      await _waitForSurvival(tester, game);

      game.world.player.integrity = 4;
      game.world.player.absorbDataShard(amount: 5);
      expect(game.world.player.dataShardCharge, 5);
      await game.world.add(
        DataShardComponent(
          position: game.world.player.position.clone(),
          scatterDirection: Vector2.zero(),
          isCorrupted: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.world.player.dataShardCharge, 1);
      expect(game.world.player.integrity, 5);
      expect(game.survivalRun.dataSurgeActive, isTrue);
      expect(game.uiSnapshot.value.survivalDataSurge, isTrue);
      expect(
        game.world.children.whereType<DataSurgeRingComponent>(),
        isNotEmpty,
      );

      final arena = game.world.activeRoom! as SurvivalArenaController;
      final target = CrawlerComponent(
        entityId: 'data-surge-weapon-target',
        position: game.world.player.position + Vector2(32, 0),
        initialHealth: 99,
        healthMaximum: 99,
      );
      await arena.add(target);
      game.world.player.tryAttack();
      for (var frame = 0; frame < 60 && target.health == 99; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(99 - target.health, 2);
      game.survivalRun.update(2.01);
      expect(game.survivalRun.dataSurgeActive, isFalse);
    },
  );
}

Future<void> _waitForSurvival(WidgetTester tester, PatchWorldGame game) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == RoomId.survivalArena && game.world.isReady) return;
  }
  throw StateError('Timed out waiting for survival arena');
}
