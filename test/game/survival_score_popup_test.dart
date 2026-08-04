import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/effects/survival_score_popup_component.dart';
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

  testWidgets('kill confirmation matches actual survival score deltas', (
    tester,
  ) async {
    final game = await _bootGame(tester);
    expect(game.mode.name, 'campaign');
    expect(game.recordSurvivalKillAt(Vector2(200, 200)), 0);
    expect(
      game.world.children.whereType<SurvivalScorePopupComponent>(),
      isEmpty,
    );
    game.startSurvivalRun();
    await _waitForSurvival(tester, game);
    game.survivalRun.experienceToNext = 999;

    expect(game.recordSurvivalKillAt(Vector2(300, 200)), 25);
    for (var index = 0; index < 3; index += 1) {
      game.recordSurvivalKillAt(Vector2(310 + index * 10, 200));
    }
    expect(game.recordSurvivalKillAt(Vector2(350, 200)), 50);
    expect(game.survivalRun.flowMultiplier, 2);
    expect(game.recordSurvivalKillAt(Vector2(400, 200), elite: true), 550);
    expect(game.recordSurvivalKillAt(Vector2(450, 200), miniBoss: true), 2050);
    expect(
      game.recordSurvivalKillAt(Vector2(500, 200), rewardMultiplier: 3),
      150,
    );
    await tester.pump();

    final popups = game.world.children
        .whereType<SurvivalScorePopupComponent>()
        .toList(growable: false);
    expect(
      popups.map((popup) => popup.score),
      containsAll(<int>[25, 50, 550, 2050, 150]),
    );
    expect(
      popups.singleWhere((popup) => popup.score == 550).kind,
      SurvivalScorePopupKind.elite,
    );
    expect(
      popups.singleWhere((popup) => popup.score == 2050).kind,
      SurvivalScorePopupKind.miniBoss,
    );

    for (var index = 0; index < 20; index += 1) {
      game.world.spawnSurvivalScorePopup(
        Vector2(200 + index.toDouble(), 250),
        score: index + 1,
      );
    }
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      game.world.children.whereType<SurvivalScorePopupComponent>().length,
      lessThanOrEqualTo(16),
    );
  });
}

Future<PatchWorldGame> _bootGame(WidgetTester tester) async {
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
  return game;
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
