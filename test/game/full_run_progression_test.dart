import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('full run transitions and paused restarts never deadlock', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await _mountGame(tester, game);

    game.openRoomOnePatchSelection();
    game.selectPatch(PatchCatalog.roomOneChoices.first.id);
    await _waitForRoom(tester, game, RoomId.temporalHall);

    game.openRoomTwoPatchSelection();
    game.selectPatch(PatchCatalog.roomTwoChoices.first.id);
    await _waitForRoom(tester, game, RoomId.collisionArchive);

    game.openRoomThreePatchSelection();
    game.selectPatch(PatchCatalog.roomThreeChoices.first.id);
    await _waitForRoom(tester, game, RoomId.optimizerCore);

    expect(game.world.activeRoom, isA<BossRoomController>());
    expect(game.runState.selectedPatchIds, hasLength(3));
    expect(game.paused, isFalse);

    game.showEnding();
    expect(game.paused, isTrue);
    expect(game.overlays.isActive(OverlayIds.ending), isTrue);
    game.chooseEnding('preserve');
    await tester.pump();
    expect(game.completedRun.value?.endingId, 'preserve');
    expect(game.completedRun.value?.selectedPatchIds, hasLength(3));

    game.returnToTitle();
    await _waitForRoom(tester, game, RoomId.damageLab, requireRunning: false);
    expect(game.world.activeRoom, isA<RoomOneController>());
    expect(game.runState.selectedPatchIds, isEmpty);
    expect(game.overlays.isActive(OverlayIds.title), isTrue);
    expect(game.paused, isTrue);

    game.startRun();
    await _waitForRoom(tester, game, RoomId.damageLab);
    game.world.player.takeDamage(5, causeId: 'test.defeat');
    expect(game.paused, isTrue);
    expect(game.defeatSnapshot.value, isNotNull);

    game.restartDefeatedRoom();
    await _waitForRoom(tester, game, RoomId.damageLab);
    expect(game.world.player.integrity, game.world.player.maxIntegrity);
    expect(game.defeatSnapshot.value, isNull);
    expect(game.paused, isFalse);
    await tester.pump(const Duration(seconds: 7));
  });
}

Future<void> _mountGame(WidgetTester tester, PatchWorldGame game) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GameWidget(
        game: game,
        overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
          OverlayIds.patchSelection: (_, _) => const SizedBox.shrink(),
          OverlayIds.patchApplied: (_, _) => const SizedBox.shrink(),
          OverlayIds.defeat: (_, _) => const SizedBox.shrink(),
          OverlayIds.ending: (_, _) => const SizedBox.shrink(),
          OverlayIds.title: (_, _) => const SizedBox.shrink(),
          OverlayIds.hud: (_, _) => const SizedBox.shrink(),
          OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
        },
      ),
    ),
  );
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
}

Future<void> _waitForRoom(
  WidgetTester tester,
  PatchWorldGame game,
  RoomId target, {
  bool requireRunning = true,
}) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == target &&
        game.world.isReady &&
        (!requireRunning || !game.paused)) {
      return;
    }
  }
  throw StateError('Timed out waiting for $target');
}
