import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/effects/volatile_cache_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';
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

  testWidgets('volatile cache pays collection and punishes expiration', (
    tester,
  ) async {
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
            OverlayIds.survivalResult: (_, _) => const SizedBox.shrink(),
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
    final room = game.world.activeRoom! as SurvivalArenaController;
    game.world.player.integrity = 999;

    game.survivalRun.elapsedSeconds = 29.95;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 16));
    final firstCache = room.children.whereType<VolatileCacheComponent>().single;
    expect(game.survivalRun.hotCachesSpawned, 1);
    firstCache.position.setFrom(game.world.player.position);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 400));
    expect(game.survivalRun.hotCachesCollected, 1);
    expect(game.survivalRun.bonusScore, 400);
    expect(game.world.player.dataShardCharge, 3);

    game.survivalRun.elapsedSeconds = 74.95;
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 16));
    final secondCache = room.children
        .whereType<VolatileCacheComponent>()
        .single;
    final crawlersBefore = room.children.whereType<CrawlerComponent>().length;
    final sentinelsBefore = room.children.whereType<SentinelComponent>().length;
    secondCache.remainingSeconds = 0.001;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 50));
    expect(game.survivalRun.hotCachesExpired, 1);
    expect(
      room.children.whereType<CrawlerComponent>().length,
      greaterThanOrEqualTo(crawlersBefore + 2),
    );
    expect(
      room.children.whereType<SentinelComponent>().length,
      greaterThanOrEqualTo(sentinelsBefore + 1),
    );
  });
}

Future<void> _waitForSurvival(WidgetTester tester, PatchWorldGame game) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == RoomId.survivalArena &&
        game.world.isReady &&
        !game.paused) {
      return;
    }
  }
  throw StateError('Timed out waiting for survival arena');
}
