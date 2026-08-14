import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
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

  test('all Damage Lab mandatory terrain is safe for every weapon', () {
    final progress = DamageLabFloorState();
    for (final nodeId in CampaignWorldGraph.damageMainPath) {
      final room = DamageLabNodeController(
        nodeId: nodeId,
        entry: CampaignNodeEntry.west,
        progress: progress,
      );
      for (final weapon in PlayerWeapon.values) {
        expect(
          PlatformerTraversalContract.validateRequiredRoute(
            room.requiredTraversalSegments,
            weapon: weapon,
          ),
          isEmpty,
          reason: '${weapon.name} must clear ${nodeId.name}',
        );
      }
    }
  });

  testWidgets('all weapons can traverse and backtrack every Damage room', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    game.damageLabProgress
      ..clearedEncounterIds.addAll(<int>{0, 1, 2})
      ..bossDefeated = true;

    for (final weapon in PlayerWeapon.values) {
      game.world.player.configureLoadout(
        weapon,
        assistMode: game.settings.value.assistMode,
      );
      await _useDoor(
        tester,
        game,
        'interaction.enterDamageLab',
        CampaignNodeId.damageWorkshop,
      );
      expect(game.world.player.selectedWeapon, weapon);

      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );
      await _useDoor(
        tester,
        game,
        'interaction.previousRoom',
        CampaignNodeId.damageWorkshop,
      );
      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );
      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageOverflow,
      );
      await _useDoor(
        tester,
        game,
        'interaction.enterBossRoom',
        CampaignNodeId.overflowWarden,
      );
      await _useDoor(
        tester,
        game,
        'interaction.previousRoom',
        CampaignNodeId.damageOverflow,
      );
      await _useDoor(
        tester,
        game,
        'interaction.previousRoom',
        CampaignNodeId.damageAssembly,
      );
      await _useDoor(
        tester,
        game,
        'interaction.previousRoom',
        CampaignNodeId.damageWorkshop,
      );
      await _useDoor(
        tester,
        game,
        'interaction.returnBootSector',
        CampaignNodeId.bootSector,
      );

      expect(
        game.campaignExploration.visitedNodeIds,
        containsAll(CampaignWorldGraph.damageMainPath),
      );
    }

    game.damageLabProgress.reset();
    await _useDoor(
      tester,
      game,
      'interaction.enterDamageLab',
      CampaignNodeId.damageWorkshop,
    );

    final room = game.world.activeRoom! as DamageLabNodeController;
    final doorKeys = room.children.whereType<CampaignDoorComponent>().map(
      (door) => door.labelLocalizationKey,
    );
    expect(doorKeys, <String>['interaction.returnBootSector']);
    expect(
      game.travelToCampaignNode(
        CampaignNodeId.damageAssembly,
        entry: CampaignNodeEntry.west,
      ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
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
    'current=${game.campaignExploration.currentNode?.name}, '
    'active=${game.world.activeRoom.runtimeType}',
  );
}
