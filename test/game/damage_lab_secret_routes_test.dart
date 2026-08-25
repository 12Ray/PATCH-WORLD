import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/ranged_route_switch_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_secret_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('each weapon opens one optional cache and returns to Assembly', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    game.damageLabProgress.clearedEncounterIds.addAll(<int>{0, 1});

    const routes =
        <
          PlayerWeapon,
          (CampaignNodeId, String, RunItemId, TraversalAbilityRequirement)
        >{
          PlayerWeapon.sword: (
            CampaignNodeId.damageDashCache,
            'interaction.enterDashCache',
            RunItemId.dashBuffer,
            TraversalAbilityRequirement.swordDash,
          ),
          PlayerWeapon.gauntlet: (
            CampaignNodeId.damageUpperArchive,
            'interaction.enterUpperArchive',
            RunItemId.airStack,
            TraversalAbilityRequirement.gauntletDoubleJump,
          ),
          PlayerWeapon.gun: (
            CampaignNodeId.damageTurretControl,
            'interaction.enterTurretControl',
            RunItemId.targetingDaemon,
            TraversalAbilityRequirement.gunRangedSwitch,
          ),
        };

    for (final entry in routes.entries) {
      final weapon = entry.key;
      final route = entry.value;
      game.world.player.configureLoadout(
        weapon,
        assistMode: game.settings.value.assistMode,
      );
      final maximumBeforeReward = game.world.player.maxIntegrity;

      await _useDoor(
        tester,
        game,
        'interaction.enterDamageLab',
        CampaignNodeId.damageWorkshop,
      );
      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );

      final availableSecretKeys = game.world.activeRoom!.children
          .whereType<CampaignDoorComponent>()
          .map((door) => door.labelLocalizationKey)
          .where((key) => key.startsWith('interaction.enter'));
      expect(availableSecretKeys, contains(route.$2));
      expect(availableSecretKeys, hasLength(1));

      await _useDoor(tester, game, route.$2, route.$1);
      final secret = game.world.activeRoom! as DamageLabSecretController;
      expect(secret.requiredWeapon, weapon);
      expect(secret.challengeSegment.requiredForCompletion, isFalse);
      expect(secret.challengeSegment.requirement, route.$4);
      final layers = secret.children
          .whereType<StoryRoomLayersComponent>()
          .single;
      expect(layers.theme, StoryRegionVisualTheme.damage);
      expect(layers.motif, _motifFor(weapon));
      expect(
        secret.children.whereType<PlatformSurfaceComponent>().where(
          (surface) => !surface.isBoundary,
        ),
        everyElement(
          isA<PlatformSurfaceComponent>().having(
            (surface) => surface.renderArtwork,
            'renderArtwork',
            isTrue,
          ),
        ),
      );

      if (weapon == PlayerWeapon.gun) {
        expect(secret.isGunGateOpen, isFalse);
        secret.children
            .whereType<RangedRouteSwitchComponent>()
            .single
            .receiveHealing(1);
        await tester.pump();
        expect(secret.isGunGateOpen, isTrue);
      }

      final reward = secret.children.whereType<ItemPedestalComponent>().single;
      game.world.player.position.setFrom(reward.position);
      expect(game.world.tryInteract(game.world.player), isTrue);
      expect(game.runItems.contains(route.$3), isTrue);
      expect(
        game.damageLabProgress.claimedSecretRewardIds,
        contains(route.$1.name),
      );
      if (weapon == PlayerWeapon.sword) {
        expect(game.world.player.effectiveDashCooldownSeconds, 4);
      }
      if (weapon == PlayerWeapon.gauntlet) {
        expect(game.world.player.maxIntegrity, maximumBeforeReward + 1);
      }

      await _useDoor(
        tester,
        game,
        'interaction.returnAssembly',
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
    }

    expect(game.damageLabProgress.claimedSecretRewardIds, hasLength(3));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

StoryRoomVisualMotif _motifFor(PlayerWeapon weapon) => switch (weapon) {
  PlayerWeapon.sword => StoryRoomVisualMotif.dashSecret,
  PlayerWeapon.gauntlet => StoryRoomVisualMotif.verticalSecret,
  PlayerWeapon.gun => StoryRoomVisualMotif.rangedSecret,
};

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
