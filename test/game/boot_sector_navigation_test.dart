import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boot_sector_controller.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('Boot Sector and Damage Lab form a two-way safe transition', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    expect(game.world.activeRoom, isA<BootSectorController>());
    expect(game.campaignExploration.currentNode, CampaignNodeId.bootSector);
    final bootDoor = game.world.activeRoom!.children
        .whereType<CampaignDoorComponent>()
        .single;
    game.world.player.position.setValues(
      bootDoor.position.x,
      bootDoor.position.y - 36,
    );
    expect(game.world.tryInteract(game.world.player), isTrue);
    await _waitForRoom(tester, game, RoomId.damageLab);

    expect(game.world.activeRoom, isA<DamageLabNodeController>());
    expect(game.campaignExploration.currentNode, CampaignNodeId.damageWorkshop);
    final returnDoor = game.world.activeRoom!.children
        .whereType<CampaignDoorComponent>()
        .single;
    game.world.player.position.setValues(
      returnDoor.position.x,
      returnDoor.position.y - 36,
    );
    expect(game.world.tryInteract(game.world.player), isTrue);
    await _waitForRoom(tester, game, RoomId.bootSector);

    expect(game.world.activeRoom, isA<BootSectorController>());
    expect(
      game.campaignExploration.visitedNodeIds,
      containsAll(<CampaignNodeId>[
        CampaignNodeId.bootSector,
        CampaignNodeId.damageWorkshop,
      ]),
    );
  });
}

Future<void> _waitForRoom(
  WidgetTester tester,
  PatchWorldGame game,
  RoomId target,
) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == target &&
        game.world.isReady &&
        !game.isRoomTransitionInProgress &&
        !game.paused) {
      return;
    }
  }
  throw StateError(
    'Timed out waiting for $target; current=${game.currentRoom}, '
    'ready=${game.world.isReady}, '
    'transition=${game.isRoomTransitionInProgress}, paused=${game.paused}, '
    'active=${game.world.activeRoom.runtimeType}, '
    'mounted=${game.world.activeRoom?.isMounted}, '
    'removing=${game.world.activeRoom?.isRemoving}',
  );
}
