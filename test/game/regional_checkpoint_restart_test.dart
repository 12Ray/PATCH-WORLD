import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
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

  testWidgets('ROOM 2 and ROOM 3 checkpoint defeats restart at region entry', (
    tester,
  ) async {
    const expectations = <(String, CampaignNodeId, CampaignNodeId, bool)>[
      (
        'interaction.enterTemporalHall',
        CampaignNodeId.temporalAscent,
        CampaignNodeId.temporalFracture,
        true,
      ),
      (
        'interaction.enterCollisionArchive',
        CampaignNodeId.collisionCompression,
        CampaignNodeId.collisionFracture,
        false,
      ),
    ];

    for (final expectation in expectations) {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      game.damageLabProgress.patchApplied = true;
      final progress = expectation.$4
          ? game.temporalHallProgress
          : game.collisionArchiveProgress;
      progress.clearedEncounterIds.add(0);
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget<PatchWorldGame>(
            game: game,
            overlayBuilderMap:
                <String, Widget Function(BuildContext, PatchWorldGame)>{
                  OverlayIds.defeat: (_, _) => const SizedBox.shrink(),
                },
          ),
        ),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);

      await _useDoor(tester, game, expectation.$1, expectation.$2);
      final entryRoom =
          game.world.activeRoom! as RegionalCampaignNodeController;
      final checkpoint = entryRoom.children
          .whereType<CampaignCheckpointComponent>()
          .single;
      game.world.player
        ..integrity = 1
        ..position.setFrom(checkpoint.position);
      expect(entryRoom.tryInteract(game.world.player), isTrue);
      expect(game.world.player.integrity, game.world.player.maxIntegrity);
      expect(game.campaignExploration.checkpointNodeId, expectation.$2);

      await _useDoor(tester, game, 'interaction.nextRoom', expectation.$3);
      game.handlePlayerDefeat(causeId: 'test.regional-checkpoint');
      game.restartDefeatedRoom();
      await _waitForNode(tester, game, expectation.$2);

      final restarted =
          game.world.activeRoom! as RegionalCampaignNodeController;
      expect(restarted.nodeId, expectation.$2);
      expect(game.campaignExploration.checkpointNodeId, expectation.$2);
      expect(game.world.player.position.x, closeTo(restarted.playerSpawn.x, 1));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });
}

Future<void> _useDoor(
  WidgetTester tester,
  PatchWorldGame game,
  String labelLocalizationKey,
  CampaignNodeId target,
) async {
  final door = game.world.activeRoom!.children
      .whereType<CampaignDoorComponent>()
      .singleWhere(
        (candidate) => candidate.labelLocalizationKey == labelLocalizationKey,
      );
  game.world.player.position.setValues(door.position.x, door.position.y - 36);
  expect(game.world.tryInteract(game.world.player), isTrue);
  await _waitForNode(tester, game, target);
}

Future<void> _waitForNode(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId target,
) async {
  for (var attempt = 0; attempt < 160; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
    if (game.world.isReady &&
        !game.isRoomTransitionInProgress &&
        game.campaignExploration.currentNode == target) {
      return;
    }
  }
  throw StateError('Timed out waiting for ${target.name}');
}
