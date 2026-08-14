import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'xyz.luan/audioplayers.global/events',
          (message) async =>
              const StandardMethodCodec().encodeSuccessEnvelope(null),
        );
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('xyz.luan/audioplayers.global/events', null);
  });

  testWidgets(
    'campaign rejects illegal travel and survives repeated door transitions',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      await _mountGame(tester, game);
      await tester.runAsync(
        () => game.selectStartingWeapon(PlayerWeapon.sword),
      );
      await tester.pump(const Duration(milliseconds: 16));

      expect(game.campaignExploration.currentNode, CampaignNodeId.bootSector);
      expect(
        game.travelToCampaignNode(
          CampaignNodeId.damageAssembly,
          entry: CampaignNodeEntry.west,
        ),
        isFalse,
      );
      expect(
        game.travelToCampaignNode(
          CampaignNodeId.optimizerCore,
          entry: CampaignNodeEntry.west,
        ),
        isFalse,
      );
      expect(
        game.travelToCampaignNode(
          CampaignNodeId.temporalAscent,
          entry: CampaignNodeEntry.west,
        ),
        isFalse,
      );

      await _useDoor(
        tester,
        game,
        'interaction.enterDamageLab',
        CampaignNodeId.damageWorkshop,
      );
      expect(
        game.travelToCampaignNode(
          CampaignNodeId.damageAssembly,
          entry: CampaignNodeEntry.west,
        ),
        isFalse,
        reason: 'The uncleared encounter must keep the forward route locked.',
      );

      final workshop = game.world.activeRoom! as DamageLabNodeController;
      final integrityBeforeFall = game.world.player.integrity;
      game.world.player.position.setValues(480, workshop.killPlaneY + 20);
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.world.player.integrity, integrityBeforeFall - 1);
      expect(
        game.world.player.position.x,
        closeTo(workshop.playerSpawn.x, .01),
      );
      expect(
        game.world.player.position.y,
        closeTo(workshop.playerSpawn.y, .01),
      );

      final enemies = workshop.children
          .whereType<PlatformerEnemyComponent>()
          .toList(growable: false);
      expect(enemies, hasLength(2));
      for (final enemy in enemies) {
        enemy.receiveDamage(99);
      }
      await tester.pump(const Duration(milliseconds: 80));

      final firstForwardDoor = workshop.children
          .whereType<CampaignDoorComponent>()
          .singleWhere(
            (door) => door.labelLocalizationKey == 'interaction.nextRoom',
          );
      game.world.player.position.setValues(
        firstForwardDoor.position.x,
        firstForwardDoor.position.y - 36,
      );
      expect(firstForwardDoor.tryEnter(game.world.player), isTrue);
      expect(
        firstForwardDoor.tryEnter(game.world.player),
        isFalse,
        reason: 'A door may queue only one transition while it is active.',
      );
      await _waitForNode(tester, game, CampaignNodeId.damageAssembly);
      expect(game.world.player.position.x, closeTo(166, .01));

      for (var cycle = 0; cycle < 8; cycle += 1) {
        await _useDoor(
          tester,
          game,
          'interaction.previousRoom',
          CampaignNodeId.damageWorkshop,
        );
        expect(game.world.player.position.x, closeTo(794, .01));
        await _useDoor(
          tester,
          game,
          'interaction.nextRoom',
          CampaignNodeId.damageAssembly,
        );
        expect(game.world.player.position.x, closeTo(166, .01));
        expect(game.isRoomTransitionInProgress, isFalse);
      }

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
      expect(game.isRoomTransitionInProgress, isFalse);
      expect(game.world.isReady, isTrue);
      expect(game.campaignExploration.currentNode, CampaignNodeId.bootSector);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _mountGame(WidgetTester tester, PatchWorldGame game) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GameWidget<PatchWorldGame>(
        game: game,
        overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
          OverlayIds.title: (_, _) => const SizedBox.shrink(),
          OverlayIds.hud: (_, _) => const SizedBox.shrink(),
          OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
        },
      ),
    ),
  );
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  await tester.pump(const Duration(milliseconds: 16));
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
  for (var attempt = 0; attempt < 180; attempt += 1) {
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
  throw StateError('Timed out waiting for ${target.name}.');
}
