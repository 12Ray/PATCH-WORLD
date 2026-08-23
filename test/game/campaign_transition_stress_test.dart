import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';
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
      unawaited(game.selectStartingWeapon(PlayerWeapon.sword));
      await _waitForCampaignStart(tester, game, PlayerWeapon.sword);

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

      await _clearDamageEncounter(tester, game, workshop);
      expect(game.pendingWeaponBuildSelection, isNotNull);
      expect(
        game.selectRoomOneBuildUpgrade(WeaponBuildUpgradeId.swordDashCircuit),
        isTrue,
      );
      await tester.pump(const Duration(milliseconds: 32));

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
      final assembly = game.world.activeRoom! as DamageLabNodeController;
      expect(
        game.world.player.position.x,
        closeTo(assembly.playerSpawn.x, .01),
      );

      for (var cycle = 0; cycle < 8; cycle += 1) {
        await _useDoor(
          tester,
          game,
          'interaction.previousRoom',
          CampaignNodeId.damageWorkshop,
        );
        final workshop = game.world.activeRoom! as DamageLabNodeController;
        expect(
          game.world.player.position.x,
          closeTo(workshop.playerSpawn.x, .01),
        );
        await _useDoor(
          tester,
          game,
          'interaction.nextRoom',
          CampaignNodeId.damageAssembly,
        );
        final assembly = game.world.activeRoom! as DamageLabNodeController;
        expect(
          game.world.player.position.x,
          closeTo(assembly.playerSpawn.x, .01),
        );
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
          OverlayIds.buildSelection: (_, _) => const SizedBox.shrink(),
          OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
        },
      ),
    ),
  );
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  await tester.pump(const Duration(milliseconds: 16));
}

Future<void> _clearDamageEncounter(
  WidgetTester tester,
  PatchWorldGame game,
  DamageLabNodeController room,
) async {
  final encounter = room.layout.encounter!;
  final enemies = room.children.whereType<PlatformerEnemyComponent>().toList(
    growable: false,
  );
  expect(enemies, hasLength(2));
  expect(enemies.every((enemy) => !enemy.isActiveThreat), isTrue);

  game.world.player.position.setValues(
    encounter.triggerZone.center.dx,
    encounter.triggerZone.center.dy,
  );
  await _pumpRealSeconds(tester, encounter.sealSeconds + .1);
  expect(room.encounterPhase, CampaignEncounterPhase.wave);

  for (var wave = 0; wave < encounter.waves.length; wave += 1) {
    final activeEnemies = room.activeEncounterEnemies;
    expect(activeEnemies, hasLength(encounter.waves[wave].enemyIds.length));
    expect(activeEnemies.every((enemy) => enemy.isActiveThreat), isTrue);
    for (final enemy in activeEnemies) {
      enemy.receiveDamage(99);
    }
    await tester.pump(const Duration(milliseconds: 16));
    if (wave < encounter.waves.length - 1) {
      expect(room.encounterPhase, CampaignEncounterPhase.intermission);
      await _pumpRealSeconds(tester, encounter.intermissionSeconds + .1);
      expect(room.encounterPhase, CampaignEncounterPhase.wave);
    }
  }

  expect(room.encounterPhase, CampaignEncounterPhase.clearBeat);
  expect(game.pendingWeaponBuildSelection, isNull);
  await _pumpRealSeconds(tester, encounter.clearBeatSeconds + .1);
  expect(room.encounterPhase, CampaignEncounterPhase.cleared);
}

Future<void> _pumpRealSeconds(WidgetTester tester, double seconds) async {
  final frameCount = (seconds / .05).ceil();
  for (var frame = 0; frame < frameCount; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
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

Future<void> _waitForCampaignStart(
  WidgetTester tester,
  PatchWorldGame game,
  PlayerWeapon weapon,
) async {
  for (var attempt = 0; attempt < 180; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
    if (!game.overlays.isActive(OverlayIds.title) &&
        game.world.isReady &&
        game.world.player.selectedWeapon == weapon) {
      return;
    }
  }
  throw StateError('Timed out waiting for ${weapon.name} campaign start.');
}
