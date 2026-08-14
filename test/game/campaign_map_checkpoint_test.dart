import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/app/overlays/campaign_map_overlay.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_map_terminal_component.dart';
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

  testWidgets(
    'map terminal reveals region and checkpoint owns defeat respawn',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      await tester.pumpWidget(
        MaterialApp(
          home: GameWidget<PatchWorldGame>(
            game: game,
            overlayBuilderMap:
                <String, Widget Function(BuildContext, PatchWorldGame)>{
                  OverlayIds.campaignMap: (_, activeGame) =>
                      CampaignMapOverlay(game: activeGame),
                  OverlayIds.defeat: (_, _) => const SizedBox.shrink(),
                },
          ),
        ),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);

      expect(
        game.campaignExploration.revealedNodeIds,
        isNot(contains(CampaignNodeId.damageDashCache)),
      );
      final mapTerminal = game.world.activeRoom!.children
          .whereType<CampaignMapTerminalComponent>()
          .single;
      game.world.player.position.setFrom(mapTerminal.position);
      expect(game.world.tryInteract(game.world.player), isTrue);
      await tester.pump();

      expect(game.overlays.isActive(OverlayIds.campaignMap), isTrue);
      expect(game.paused, isTrue);
      expect(
        game.campaignExploration.mappedRegions,
        contains(CampaignRegion.damageLab),
      );
      expect(
        game.campaignExploration.revealedNodeIds,
        containsAll(<CampaignNodeId>{
          CampaignNodeId.damageWorkshop,
          CampaignNodeId.damageAssembly,
          CampaignNodeId.damageOverflow,
          CampaignNodeId.overflowWarden,
          CampaignNodeId.damageDashCache,
          CampaignNodeId.damageUpperArchive,
          CampaignNodeId.damageTurretControl,
        }),
      );
      expect(find.byKey(const Key('campaign-map-canvas')), findsOneWidget);

      game.closeCampaignMap();
      await tester.pump();
      expect(game.paused, isFalse);

      game.damageLabProgress.clearedEncounterIds.add(0);
      await _useDoor(
        tester,
        game,
        'interaction.enterDamageLab',
        CampaignNodeId.damageWorkshop,
      );
      final checkpoint = game.world.activeRoom!.children
          .whereType<CampaignCheckpointComponent>()
          .single;
      game.world.player
        ..integrity = 1
        ..position.setFrom(checkpoint.position);
      expect(game.world.tryInteract(game.world.player), isTrue);
      expect(
        game.campaignExploration.checkpointNodeId,
        CampaignNodeId.damageWorkshop,
      );
      expect(game.world.player.integrity, game.world.player.maxIntegrity);

      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );
      expect(
        game.campaignExploration.checkpointNodeId,
        CampaignNodeId.damageWorkshop,
      );

      game.handlePlayerDefeat(causeId: 'test.checkpoint');
      game.restartDefeatedRoom();
      await _waitForNode(tester, game, CampaignNodeId.damageWorkshop);
      expect(game.world.player.position.x, closeTo(166, 1));
      expect(
        game.campaignExploration.checkpointNodeId,
        CampaignNodeId.damageWorkshop,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
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
  for (var attempt = 0; attempt < 120; attempt += 1) {
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
  throw StateError(
    'Timed out waiting for ${target.name}; '
    'current=${game.campaignExploration.currentNode?.name}',
  );
}
