import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
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
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'Damage room seals both exits, stages waves, and stays clear on revisit',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      game.damageLabProgress.claimedBuildRewardIds.addAll(<int>{0, 1});
      await _mountGame(tester, game);
      await _useDoor(
        tester,
        game,
        'interaction.enterDamageLab',
        CampaignNodeId.damageWorkshop,
      );

      var room = game.world.activeRoom! as DamageLabNodeController;
      final encounter = room.layout.encounter!;
      final doors = room.children.whereType<CampaignDoorComponent>().toList(
        growable: false,
      );
      final back = doors.singleWhere(
        (door) => door.labelLocalizationKey == 'interaction.returnBootSector',
      );
      final forward = doors.singleWhere(
        (door) => door.labelLocalizationKey == 'interaction.nextRoom',
      );
      final enemies = room.children
          .whereType<PlatformerEnemyComponent>()
          .toList(growable: false);

      expect(room.encounterPhase, CampaignEncounterPhase.idle);
      expect(enemies, hasLength(room.layout.enemies.length));
      expect(enemies.every((enemy) => enemy.isDormant), isTrue);
      expect(room.activeEncounterEnemyCount, 0);
      expect(back.isUnlocked, isTrue);
      expect(forward.isUnlocked, isFalse);

      final trigger = encounter.triggerZone.center;
      game.world.player.position.setValues(trigger.dx, trigger.dy);
      await tester.pump(const Duration(milliseconds: 16));
      expect(room.encounterPhase, CampaignEncounterPhase.sealing);
      expect(room.isEncounterSealed, isTrue);
      expect(back.isUnlocked, isFalse);
      expect(forward.isUnlocked, isFalse);
      expect(game.canTravelToCampaignNode(CampaignNodeId.bootSector), isFalse);

      await _pumpRealSeconds(tester, encounter.sealSeconds + .1);
      expect(room.encounterPhase, CampaignEncounterPhase.wave);
      expect(room.activeWaveIndex, 0);
      expect(
        room.activeEncounterEnemyCount,
        lessThanOrEqualTo(encounter.maxActiveEnemies),
      );
      for (final enemy in room.activeEncounterEnemies.toList()) {
        enemy.receiveDamage(99);
      }
      expect(room.encounterPhase, CampaignEncounterPhase.intermission);
      expect(game.damageLabProgress.clearedEncounterIds, isNot(contains(0)));

      await _pumpRealSeconds(tester, encounter.intermissionSeconds + .1);
      expect(room.encounterPhase, CampaignEncounterPhase.wave);
      expect(room.activeWaveIndex, 1);
      for (final enemy in room.activeEncounterEnemies.toList()) {
        enemy.receiveDamage(99);
      }
      expect(room.encounterPhase, CampaignEncounterPhase.clearBeat);
      expect(game.damageLabProgress.clearedEncounterIds, isNot(contains(0)));
      expect(back.isUnlocked, isFalse);
      expect(forward.isUnlocked, isFalse);

      await _pumpRealSeconds(tester, encounter.clearBeatSeconds + .1);
      expect(room.encounterPhase, CampaignEncounterPhase.cleared);
      expect(game.damageLabProgress.clearedEncounterIds, contains(0));
      expect(room.isEncounterSealed, isFalse);
      expect(back.isUnlocked, isTrue);
      expect(forward.isUnlocked, isTrue);

      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );
      final assembly = game.world.activeRoom! as DamageLabNodeController;
      final assemblyEncounter = assembly.layout.encounter!;
      game.world.player.position.setValues(
        assemblyEncounter.triggerZone.center.dx,
        assemblyEncounter.triggerZone.center.dy,
      );
      await tester.pump(const Duration(milliseconds: 16));
      await _pumpRealSeconds(tester, assemblyEncounter.sealSeconds + .1);
      for (final enemy in assembly.activeEncounterEnemies.toList()) {
        enemy.receiveDamage(99);
      }
      await _pumpRealSeconds(
        tester,
        assemblyEncounter.intermissionSeconds + .1,
      );
      for (final enemy in assembly.activeEncounterEnemies.toList()) {
        enemy.receiveDamage(99);
      }
      await _pumpRealSeconds(tester, assemblyEncounter.clearBeatSeconds + .1);
      await tester.pump(const Duration(milliseconds: 16));
      expect(assembly.encounterPhase, CampaignEncounterPhase.cleared);
      expect(game.damageLabProgress.clearedEncounterIds, contains(1));
      expect(
        assembly.children.whereType<CampaignDoorComponent>().map(
          (door) => door.labelLocalizationKey,
        ),
        contains('interaction.enterDashCache'),
      );

      await _useDoor(
        tester,
        game,
        'interaction.previousRoom',
        CampaignNodeId.damageWorkshop,
      );
      room = game.world.activeRoom! as DamageLabNodeController;
      expect(room.encounterPhase, CampaignEncounterPhase.cleared);
      expect(room.children.whereType<PlatformerEnemyComponent>(), isEmpty);
      expect(room.isEncounterSealed, isFalse);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _pumpRealSeconds(WidgetTester tester, double seconds) async {
  final frames = (seconds * 15).ceil() + 2;
  for (var frame = 0; frame < frames; frame += 1) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _mountGame(WidgetTester tester, PatchWorldGame game) async {
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  game.resumeEngine();
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
  for (var attempt = 0; attempt < 140; attempt += 1) {
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
