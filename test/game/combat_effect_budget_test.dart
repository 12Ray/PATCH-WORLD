import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/patch_world.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('transient combat effects enforce and release the global cap', (
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
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    game.startRun();
    await tester.pump(const Duration(milliseconds: 16));

    for (var index = 0; index < 150; index += 1) {
      game.world.spawnCriticalFlowRing(Vector2(300, 220));
    }
    expect(game.world.canSpawnCombatEffect, isFalse);

    await tester.pump(const Duration(milliseconds: 16));
    expect(game.world.activeCombatEffectCount, PatchWorld.maximumCombatEffects);

    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();
    expect(game.world.activeCombatEffectCount, 0);
    expect(game.world.canSpawnCombatEffect, isTrue);
  });
}
