import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/survival_anomaly_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'xyz.luan/audioplayers.global/events',
          (message) async =>
              const StandardMethodCodec().encodeSuccessEnvelope(null),
        );
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('xyz.luan/audioplayers.global/events', null);
  });

  testWidgets('survival crawler contact becomes a readable dodgeable bite', (
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
            OverlayIds.survivalWeaponUpgrade: (_, _) => const SizedBox.shrink(),
            OverlayIds.survivalItemReward: (_, _) => const SizedBox.shrink(),
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

    final arena = game.world.activeRoom! as SurvivalArenaController;
    final crawlers = arena.children.whereType<CrawlerComponent>().toList(
      growable: false,
    );
    final crawler = crawlers.first;
    for (final other in crawlers.skip(1)) {
      other.removeFromParent();
    }
    final anomalies = arena.children
        .whereType<SurvivalAnomalyComponent>()
        .toList(growable: false);
    for (final anomaly in anomalies) {
      anomaly.removeFromParent();
    }
    await tester.pump();

    final player = game.world.player;
    final integrityBefore = player.integrity;
    crawler.position.setFrom(player.position + Vector2(20, 0));
    await _pumpFrames(tester, 2);

    expect(crawler.survivalAttackState, SurvivalCrawlerAttackState.telegraph);
    expect(crawler.survivalAttackTimer, greaterThan(0));
    expect(player.integrity, integrityBefore);

    await _pumpSeconds(
      tester,
      CrawlerComponent.survivalBiteTelegraphSeconds * 0.65,
    );
    expect(player.integrity, integrityBefore);

    player.position += Vector2(150, 0);
    await _pumpSeconds(
      tester,
      CrawlerComponent.survivalBiteTelegraphSeconds * 0.45,
    );
    expect(crawler.survivalAttackState, SurvivalCrawlerAttackState.recovery);
    expect(player.integrity, integrityBefore);

    crawler.position.setFrom(player.position + Vector2(20, 0));
    await _pumpSeconds(
      tester,
      CrawlerComponent.survivalBiteRecoverySeconds + 0.05,
    );
    await _pumpFrames(tester, 2);
    expect(crawler.survivalAttackState, SurvivalCrawlerAttackState.telegraph);
    expect(player.integrity, integrityBefore);

    await _pumpSeconds(
      tester,
      CrawlerComponent.survivalBiteTelegraphSeconds + 0.04,
    );
    expect(player.integrity, integrityBefore - 1);
    expect(player.lastDamageCauseId, 'enemy.crawler.bite');

    await _pumpSeconds(tester, 0.25);
    expect(player.integrity, integrityBefore - 1);
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

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpSeconds(WidgetTester tester, double seconds) async {
  final frames = (seconds * 60).ceil();
  await _pumpFrames(tester, frames);
}
