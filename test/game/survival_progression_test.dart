import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
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

    for (var index = 0; index < 6; index += 1) {
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
    expect(game.paused, isFalse);
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
