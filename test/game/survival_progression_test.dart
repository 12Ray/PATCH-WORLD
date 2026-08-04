import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/composite_component.dart';
import 'package:patch_world/game/components/enemies/sentinel_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('survival starts, levels up, and installs a patch', (
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
    expect(game.mode, PatchWorldMode.survival);
    expect(game.world.activeRoom, isA<SurvivalArenaController>());
    final arena = game.world.activeRoom! as SurvivalArenaController;
    expect(
      arena.children.whereType<CrawlerComponent>().every(
        (crawler) => crawler.healthState.max == 2,
      ),
      isTrue,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(game.world.children.whereType<PatchPulseComponent>(), isEmpty);

    final target = arena.children.whereType<CrawlerComponent>().first;
    target.position.setFrom(game.world.player.position);
    game.world.player.tryAttack();
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.world.children.whereType<PatchPulseComponent>(), isNotEmpty);
    await tester.pump(const Duration(milliseconds: 16));
    expect(target.health, 1);
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    target.position.setFrom(game.world.player.position);
    game.world.player.tryAttack();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.survivalRun.kills, 1);

    for (var index = 0; index < 5; index += 1) {
      game.recordSurvivalKill();
    }
    await tester.pump();
    expect(game.survivalRun.level, 2);
    expect(game.pendingSurvivalUpgrade, isNotNull);
    expect(game.overlays.isActive(OverlayIds.survivalUpgrade), isTrue);
    expect(game.paused, isTrue);

    final chosen = game.pendingSurvivalUpgrade!.choices.first;
    game.selectSurvivalUpgrade(chosen.id);
    await tester.pump();
    expect(game.pendingSurvivalUpgrade, isNull);
    expect(game.runState.hasPatch(chosen.id), isTrue);
    expect(game.survivalRun.patchTier(chosen.id), 1);
    expect(game.survivalModifiers.pulseDamage, 2);
    expect(game.survivalModifiers.pulseRadiusMultiplier, closeTo(1.14, 0.001));
    expect(
      arena.children.whereType<TextComponent>().any(
        (label) => label.text.contains('COMBO x5'),
      ),
      isTrue,
    );
    expect(
      arena.children.whereType<TextComponent>().any(
        (label) => label.text.contains('POWER ONLINE'),
      ),
      isTrue,
    );
    expect(game.paused, isFalse);

    game.world.player.integrity = 999;
    game.survivalRun.elapsedSeconds = 88;
    await _pumpUntil(
      tester,
      () => arena.children.whereType<SentinelComponent>().any(
        (sentinel) => sentinel.isElite,
      ),
    );
    expect(
      arena.children
          .whereType<SentinelComponent>()
          .singleWhere((sentinel) => sentinel.isElite)
          .health
          .max,
      5,
    );

    game.survivalRun.elapsedSeconds = 176;
    await _pumpUntil(
      tester,
      () => arena.children.whereType<CompositeComponent>().isNotEmpty,
    );
    expect(arena.children.whereType<CompositeComponent>().first.health.max, 10);

    final firstPatchId = game.survivalRun.firstPatchId;
    game.handlePlayerDefeat(causeId: 'test.survival');
    await tester.pump();
    expect(game.overlays.isActive(OverlayIds.survivalResult), isTrue);
    expect(game.survivalResult.value, isNotNull);
    expect(game.survivalResult.value!.elapsedSeconds, greaterThan(176));
    expect(game.survivalResult.value!.firstPatchId, firstPatchId);
    expect(game.paused, isTrue);

    game.retrySurvivalRun(keepStartingPatch: true);
    await _waitForSurvival(tester, game);
    expect(game.overlays.isActive(OverlayIds.survivalResult), isFalse);
    expect(game.survivalResult.value, isNull);
    expect(game.survivalRun.elapsedSeconds, lessThan(1));
    expect(game.survivalRun.patchTier(firstPatchId!), 1);
    expect(game.runState.hasPatch(firstPatchId), isTrue);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 120; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
  }
  throw StateError('Timed out waiting for survival milestone');
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
