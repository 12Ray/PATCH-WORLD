import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('mini-boss XP pays every queued patch draft before resume', (
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

    game.recordSurvivalKill(miniBoss: true);
    await tester.pump();
    expect(game.survivalRun.level, 3);
    expect(game.pendingSurvivalUpgrade?.level, 2);
    expect(game.survivalRun.pendingUpgradeCount, 1);
    expect(game.survivalRun.reroutesRemaining, 2);
    expect(game.paused, isTrue);

    final firstPatch = game.pendingSurvivalUpgrade!.choices.first;
    expect(game.selectSurvivalUpgrade(firstPatch.id), isTrue);
    await tester.pump();
    expect(game.pendingSurvivalUpgrade?.level, 3);
    expect(game.survivalRun.pendingUpgradeCount, 0);
    expect(game.paused, isTrue);

    final secondPatch = game.pendingSurvivalUpgrade!.choices.first;
    expect(game.selectSurvivalUpgrade(secondPatch.id), isTrue);
    await tester.pump();
    expect(game.pendingSurvivalUpgrade, isNull);
    expect(game.pendingSurvivalWeaponUpgrade, isNotNull);
    final weaponUpgrade = game.pendingSurvivalWeaponUpgrade!.choices.first;
    expect(game.selectSurvivalWeaponUpgrade(weaponUpgrade), isFalse);
    await tester.pump();
    expect(game.pendingSurvivalWeaponUpgrade, isNull);
    expect(game.paused, isFalse);
    expect(game.survivalRun.patchTier(firstPatch.id), 1);
    expect(game.survivalRun.patchTier(secondPatch.id), 1);
    expect(game.survivalWeaponBuild.tier(weaponUpgrade), 1);
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
