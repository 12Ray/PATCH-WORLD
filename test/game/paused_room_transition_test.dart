import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/patch_exit_terminal_component.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('confirmed patch reloads its boss before graph travel', (
    tester,
  ) async {
    final game = PatchWorldGame();
    game.damageLabProgress
      ..clearedEncounterIds.addAll(const <int>{0, 1, 2})
      ..bossDefeated = true
      ..bossRewardClaimed = true;
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget(
          game: game,
          overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
            OverlayIds.patchSelection: (_, _) => const SizedBox.shrink(),
            OverlayIds.patchApplied: (_, _) => const SizedBox.shrink(),
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    expect(game.world.activeRoom, isA<DamageLabNodeController>());
    expect(
      (game.world.activeRoom! as DamageLabNodeController).campaignNodeId,
      CampaignNodeId.overflowWarden,
    );
    game.openRoomOnePatchSelection();
    expect(game.paused, isTrue);

    game.selectPatch(PatchCatalog.roomOneChoices.first.id);
    await _waitForNode(tester, game, CampaignNodeId.overflowWarden);

    expect(game.currentRoom, RoomId.damageLab);
    expect(game.damageLabProgress.patchApplied, isTrue);
    expect(game.world.activeRoom, isA<DamageLabNodeController>());
    expect(game.paused, isFalse);
    expect(
      game.world.activeRoom!.children.whereType<PatchExitTerminalComponent>(),
      isEmpty,
    );
    game.openRoomOnePatchSelection();
    expect(game.pendingPatchSelection, isNull);
    game.selectPatch(PatchCatalog.roomOneChoices.last.id);
    await tester.pump();
    expect(game.runState.selectedPatchIds, hasLength(1));
    expect(game.canTravelToCampaignNode(CampaignNodeId.temporalAscent), isTrue);

    expect(
      game.travelToCampaignNode(
        CampaignNodeId.temporalAscent,
        entry: CampaignNodeEntry.west,
      ),
      isTrue,
    );
    await _waitForNode(tester, game, CampaignNodeId.temporalAscent);
    expect(game.currentRoom, RoomId.temporalHall);
    expect(game.world.activeRoom, isA<RegionalCampaignNodeController>());
    await tester.pump(const Duration(seconds: 7));
  });
}

Future<void> _waitForNode(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId target,
) async {
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
        !game.paused) {
      return;
    }
  }
  throw StateError('Timed out waiting for $target');
}
