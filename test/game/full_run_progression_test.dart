import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('modern campaign rejects patch bypass and restarts its node', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await _mountGame(tester, game);

    game.resumeEngine();
    await _waitForNode(tester, game, CampaignNodeId.damageWorkshop);
    expect(game.world.activeRoom, isA<DamageLabNodeController>());

    game.openRoomOnePatchSelection();
    expect(game.pendingPatchSelection, isNull);
    expect(game.overlays.isActive(OverlayIds.patchSelection), isFalse);
    game.selectPatch(PatchCatalog.roomOneChoices.first.id);
    await tester.pump();
    expect(game.runState.selectedPatchIds, isEmpty);
    expect(game.damageLabProgress.patchApplied, isFalse);
    expect(game.campaignExploration.currentNode, CampaignNodeId.damageWorkshop);

    game.world.player.takeDamage(99, causeId: 'test.defeat');
    expect(game.paused, isTrue);
    expect(game.defeatSnapshot.value, isNotNull);
    game.restartDefeatedRoom();
    await _waitForNode(tester, game, CampaignNodeId.damageWorkshop);
    expect(game.world.player.integrity, game.world.player.maxIntegrity);
    expect(game.defeatSnapshot.value, isNull);

    game.returnToTitle();
    await _waitForNode(
      tester,
      game,
      CampaignNodeId.damageWorkshop,
      requireRunning: false,
    );
    expect(game.world.activeRoom, isA<DamageLabNodeController>());
    expect(game.runState.selectedPatchIds, isEmpty);
    expect(game.overlays.isActive(OverlayIds.title), isTrue);
    expect(game.paused, isTrue);
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

Future<void> _waitForNode(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId target, {
  bool requireRunning = true,
}) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    final activeRoom = game.world.activeRoom;
    if (activeRoom is CampaignNodeRoom &&
        (activeRoom as CampaignNodeRoom).campaignNodeId == target &&
        game.world.isReady &&
        !game.isRoomTransitionInProgress &&
        (!requireRunning || !game.paused)) {
      return;
    }
  }
  throw StateError('Timed out waiting for $target');
}
