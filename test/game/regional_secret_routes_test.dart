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
import 'package:patch_world/game/rooms/regional_secret_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test(
    'regional secret routes stay locked until the second room is complete',
    () {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);

      final routes = <(CampaignNodeId, CampaignNodeId, PlayerWeapon, bool)>[
        (
          CampaignNodeId.temporalFracture,
          CampaignNodeId.temporalDashRift,
          PlayerWeapon.sword,
          true,
        ),
        (
          CampaignNodeId.temporalFracture,
          CampaignNodeId.temporalUpperLoop,
          PlayerWeapon.gauntlet,
          true,
        ),
        (
          CampaignNodeId.temporalFracture,
          CampaignNodeId.temporalRelayControl,
          PlayerWeapon.gun,
          true,
        ),
        (
          CampaignNodeId.collisionFracture,
          CampaignNodeId.collisionVectorCache,
          PlayerWeapon.sword,
          false,
        ),
        (
          CampaignNodeId.collisionFracture,
          CampaignNodeId.collisionUpperMatrix,
          PlayerWeapon.gauntlet,
          false,
        ),
        (
          CampaignNodeId.collisionFracture,
          CampaignNodeId.collisionPrismControl,
          PlayerWeapon.gun,
          false,
        ),
      ];

      for (final route in routes) {
        final progress = route.$4
            ? game.temporalHallProgress
            : game.collisionArchiveProgress;
        progress
          ..clearedEncounterIds.remove(1)
          ..completedObjectiveIds.remove(1);
        game.campaignExploration.enterNode(route.$1, game.campaignWorld);
        final connection = game.campaignWorld.connectionBetween(
          route.$1,
          route.$2,
        );

        expect(
          game.isCampaignConnectionUnlocked(connection, weapon: route.$3),
          isFalse,
        );
        expect(
          game.canTravelToCampaignNode(route.$2, weapon: route.$3),
          isFalse,
        );

        progress
          ..clearedEncounterIds.add(1)
          ..completedObjectiveIds.add(1);
        expect(
          game.isCampaignConnectionUnlocked(connection, weapon: route.$3),
          isTrue,
        );
        expect(
          game.canTravelToCampaignNode(route.$2, weapon: route.$3),
          isTrue,
        );
      }
    },
  );

  testWidgets(
    'Temporal and Collision expose six one-time weapon reward routes',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      game.damageLabProgress.patchApplied = true;
      game.temporalHallProgress
        ..bossDefeated = true
        ..patchApplied = true;
      game.temporalHallProgress.clearedEncounterIds.addAll(<int>{0, 1});
      game.temporalHallProgress.completedObjectiveIds.addAll(<int>{0, 1});
      game.collisionArchiveProgress.clearedEncounterIds.addAll(<int>{0, 1});
      game.collisionArchiveProgress.completedObjectiveIds.addAll(<int>{0, 1});
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);

      const routes =
          <
            (
              PlayerWeapon,
              CampaignNodeId,
              String,
              RunItemId,
              TraversalAbilityRequirement,
            )
          >[
            (
              PlayerWeapon.sword,
              CampaignNodeId.temporalDashRift,
              'interaction.enterTemporalDashRift',
              RunItemId.chronalBuffer,
              TraversalAbilityRequirement.swordDash,
            ),
            (
              PlayerWeapon.gauntlet,
              CampaignNodeId.temporalUpperLoop,
              'interaction.enterTemporalUpperLoop',
              RunItemId.echoSpring,
              TraversalAbilityRequirement.gauntletDoubleJump,
            ),
            (
              PlayerWeapon.gun,
              CampaignNodeId.temporalRelayControl,
              'interaction.enterTemporalRelayControl',
              RunItemId.predictiveScope,
              TraversalAbilityRequirement.gunRangedSwitch,
            ),
            (
              PlayerWeapon.sword,
              CampaignNodeId.collisionVectorCache,
              'interaction.enterCollisionVectorCache',
              RunItemId.vectorEdge,
              TraversalAbilityRequirement.swordDash,
            ),
            (
              PlayerWeapon.gauntlet,
              CampaignNodeId.collisionUpperMatrix,
              'interaction.enterCollisionUpperMatrix',
              RunItemId.impactLattice,
              TraversalAbilityRequirement.gauntletDoubleJump,
            ),
            (
              PlayerWeapon.gun,
              CampaignNodeId.collisionPrismControl,
              'interaction.enterCollisionPrismControl',
              RunItemId.splitChamber,
              TraversalAbilityRequirement.gunRangedSwitch,
            ),
          ];

      for (final route in routes) {
        final isTemporal = switch (route.$2) {
          CampaignNodeId.temporalDashRift ||
          CampaignNodeId.temporalUpperLoop ||
          CampaignNodeId.temporalRelayControl => true,
          _ => false,
        };
        final firstNode = isTemporal
            ? CampaignNodeId.temporalAscent
            : CampaignNodeId.collisionCompression;
        final secondNode = isTemporal
            ? CampaignNodeId.temporalFracture
            : CampaignNodeId.collisionFracture;
        final regionEntryKey = isTemporal
            ? 'interaction.enterTemporalHall'
            : 'interaction.enterCollisionArchive';
        final returnKey = isTemporal
            ? 'interaction.returnTemporalFracture'
            : 'interaction.returnCollisionFracture';
        final progress = isTemporal
            ? game.temporalHallProgress
            : game.collisionArchiveProgress;

        game.world.player.configureLoadout(
          route.$1,
          assistMode: game.settings.value.assistMode,
        );
        await _useDoor(tester, game, regionEntryKey, firstNode);
        await _useDoor(tester, game, 'interaction.nextRoom', secondNode);

        final doors = game.world.activeRoom!.children
            .whereType<CampaignDoorComponent>()
            .toList(growable: false);
        expect(
          doors.map((door) => door.labelLocalizationKey),
          contains('interaction.nextRoom'),
          reason: 'Optional route must not replace the main route.',
        );
        final secretKeys = doors
            .map((door) => door.labelLocalizationKey)
            .where((key) => key.startsWith('interaction.enter'));
        expect(secretKeys, <String>[route.$3]);

        await _useDoor(tester, game, route.$3, route.$2);
        final secret = game.world.activeRoom! as RegionalSecretController;
        expect(secret.requiredWeapon, route.$1);
        expect(secret.rewardItem, route.$4);
        expect(secret.challengeSegment.requiredForCompletion, isFalse);
        expect(secret.challengeSegment.requirement, route.$5);
        final layers = secret.children
            .whereType<StoryRoomLayersComponent>()
            .single;
        expect(
          layers.theme,
          isTemporal
              ? StoryRegionVisualTheme.temporal
              : StoryRegionVisualTheme.collision,
        );
        expect(layers.motif, _motifFor(route.$1));
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

        if (route.$1 == PlayerWeapon.gun) {
          expect(secret.isGunGateOpen, isFalse);
          secret.children
              .whereType<RangedRouteSwitchComponent>()
              .single
              .receiveHealing(1);
          await tester.pump();
          expect(secret.isGunGateOpen, isTrue);
        }

        final reward = secret.children
            .whereType<ItemPedestalComponent>()
            .single;
        game.world.player.position.setFrom(reward.position);
        expect(game.world.tryInteract(game.world.player), isTrue);
        expect(game.runItems.contains(route.$4), isTrue);
        expect(progress.claimedSecretRewardIds, contains(route.$2.name));
        _expectRewardEffect(game, route.$4);

        await _useDoor(tester, game, returnKey, secondNode);
        await _useDoor(tester, game, route.$3, route.$2);
        expect(
          game.world.activeRoom!.children.whereType<ItemPedestalComponent>(),
          isEmpty,
          reason: '${route.$4.name} must only be claimable once.',
        );
        await _useDoor(tester, game, returnKey, secondNode);
        await _useDoor(tester, game, 'interaction.previousRoom', firstNode);
        await _useDoor(
          tester,
          game,
          'interaction.returnBootSector',
          CampaignNodeId.bootSector,
        );
      }

      expect(game.temporalHallProgress.claimedSecretRewardIds, hasLength(3));
      expect(
        game.collisionArchiveProgress.claimedSecretRewardIds,
        hasLength(3),
      );
      expect(game.runItems.items, hasLength(6));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

StoryRoomVisualMotif _motifFor(PlayerWeapon weapon) => switch (weapon) {
  PlayerWeapon.sword => StoryRoomVisualMotif.dashSecret,
  PlayerWeapon.gauntlet => StoryRoomVisualMotif.verticalSecret,
  PlayerWeapon.gun => StoryRoomVisualMotif.rangedSecret,
};

void _expectRewardEffect(PatchWorldGame game, RunItemId item) {
  switch (item) {
    case RunItemId.chronalBuffer:
      expect(game.world.player.effectiveDashCooldownSeconds, 4.5);
    case RunItemId.echoSpring:
      expect(game.world.player.effectiveAirJumpSpeedMultiplier, .92);
    case RunItemId.predictiveScope:
      expect(
        game.runItems.attackCooldownMultiplierFor(PlayerWeapon.gun),
        closeTo(.93, .0001),
      );
    case RunItemId.vectorEdge:
      expect(game.runItems.weaponDamageBonusFor(PlayerWeapon.sword, 4), 1);
      expect(game.runItems.weaponDamageBonusFor(PlayerWeapon.sword, 1), 0);
    case RunItemId.impactLattice:
      expect(game.runItems.weaponDamageBonusFor(PlayerWeapon.gauntlet, 3), 1);
      expect(game.runItems.weaponDamageBonusFor(PlayerWeapon.gauntlet, 2), 0);
    case RunItemId.splitChamber:
      expect(game.runItems.weaponDamageBonusFor(PlayerWeapon.gun, 4), 1);
      expect(game.runItems.weaponDamageBonusFor(PlayerWeapon.gun, 3), 0);
    default:
      fail('Unexpected regional reward: $item');
  }
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
