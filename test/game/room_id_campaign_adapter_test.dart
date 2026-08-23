import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
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

  testWidgets('RoomId adapter resumes only after objective completion', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.temporalHall);
    game.temporalHallProgress
      ..clearedEncounterIds.add(0)
      ..completedObjectiveIds.add(0);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final room = game.world.activeRoom! as RegionalCampaignNodeController;
    expect(room.campaignNodeId, CampaignNodeId.temporalFracture);
    expect(
      room.layout,
      same(game.regionalRoomLayouts.room(CampaignNodeId.temporalFracture)),
    );
    expect(
      game.campaignExploration.currentNode,
      CampaignNodeId.temporalFracture,
    );

    game.openRoomTwoPatchSelection();
    expect(game.pendingPatchSelection, isNull);
    game.selectPatch(PatchCatalog.roomTwoChoices.first.id);
    expect(game.runState.selectedPatchIds, isEmpty);
    expect(game.temporalHallProgress.patchApplied, isFalse);
  });

  test('damage secret route waits for the assembly encounter clear', () {
    final game = PatchWorldGame(initialRoom: RoomId.damageLab);
    final connection = game.campaignWorld.connectionBetween(
      CampaignNodeId.damageAssembly,
      CampaignNodeId.damageDashCache,
    );
    expect(
      game.isCampaignConnectionUnlocked(connection, weapon: PlayerWeapon.sword),
      isFalse,
    );
    game.damageLabProgress.clearedEncounterIds.add(1);
    expect(
      game.isCampaignConnectionUnlocked(connection, weapon: PlayerWeapon.sword),
      isTrue,
    );
  });
}
