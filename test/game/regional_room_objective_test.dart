import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/regional_room_objective.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/maps/regional_campaign_room_layout.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  late RegionalCampaignRoomLayoutCatalog layouts;

  setUpAll(() async {
    layouts = await RegionalCampaignRoomLayoutCatalog.load();
  });

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

  test('six regional rooms own distinct objective contracts', () {
    final specs = RegionalRoomObjectiveCatalog.values.toList(growable: false);

    expect(specs, hasLength(6));
    expect(specs.map((spec) => spec.nodeId).toSet(), hasLength(6));
    expect(
      specs.map((spec) => spec.objectiveLocalizationKey).toSet(),
      hasLength(6),
    );
    expect(specs.map((spec) => spec.visualStyle).toSet(), hasLength(6));
    expect(
      specs.map((spec) => spec.mode).toSet(),
      containsAll(RegionalRoomObjectiveMode.values),
    );
    expect(
      specs
          .where(
            (spec) =>
                spec.completionWindow !=
                RegionalRoomObjectiveCompletionWindow.none,
          )
          .map((spec) => spec.completionWindow),
      containsAll(<RegionalRoomObjectiveCompletionWindow>[
        RegionalRoomObjectiveCompletionWindow.hazardInactive,
        RegionalRoomObjectiveCompletionWindow.platformMerged,
      ]),
    );
  });

  test('regional floor progress requires combat and room objectives', () {
    final progress = CampaignFloorState();

    progress.clearedEncounterIds.addAll(<int>{0, 1, 2});
    expect(progress.allEncountersCleared, isTrue);
    expect(progress.allRoomsComplete, isFalse);
    progress.completedObjectiveIds.addAll(<int>{0, 1, 2});
    expect(progress.allObjectivesComplete, isTrue);
    expect(progress.allRoomsComplete, isTrue);

    progress.reset();
    expect(progress.completedObjectiveIds, isEmpty);
    expect(progress.allRoomsComplete, isFalse);
  });

  test('regional resume and boss gates require every room contract', () {
    final progress = CampaignFloorState();
    progress.clearedEncounterIds.addAll(<int>{0, 1, 2});
    expect(progress.resumeCell, 0);
    progress.completedObjectiveIds.add(0);
    expect(progress.resumeCell, 1);
    progress.completedObjectiveIds.add(1);
    expect(progress.resumeCell, 2);
    progress.completedObjectiveIds.add(2);
    expect(progress.resumeCell, 3);

    for (final route in <(CampaignNodeId, CampaignNodeId, CampaignFloorState)>[
      (
        CampaignNodeId.temporalPendulum,
        CampaignNodeId.chronoJailer,
        CampaignFloorState(),
      ),
      (
        CampaignNodeId.collisionMerge,
        CampaignNodeId.kernelChimera,
        CampaignFloorState(),
      ),
    ]) {
      final room = RegionalCampaignNodeController(
        nodeId: route.$1,
        entry: CampaignNodeEntry.west,
        progress: route.$3,
        layout: layouts.room(route.$1),
      );
      route.$3
        ..clearedEncounterIds.add(2)
        ..completedObjectiveIds.add(2);
      expect(room.roomExitUnlocked, isFalse);
      route.$3
        ..clearedEncounterIds.addAll(<int>{0, 1})
        ..completedObjectiveIds.addAll(<int>{0, 1});
      expect(room.roomExitUnlocked, isTrue);
    }
  });

  testWidgets(
    'all six rooms show a locked exit and persist their unique objective',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      await _mountGame(tester, game);

      var roomIndex = 0;
      for (final spec in RegionalRoomObjectiveCatalog.values) {
        final entry = roomIndex.isOdd
            ? CampaignNodeEntry.east
            : CampaignNodeEntry.west;
        roomIndex += 1;
        await _loadRegionalNode(tester, game, spec.nodeId, entry: entry);
        var room = game.world.activeRoom! as RegionalCampaignNodeController;
        expect(room.objectiveNodes, hasLength(spec.requiredNodeCount));
        expect(room.roomObjectiveComplete, isFalse);

        var forwardDoor = _forwardDoor(room);
        expect(forwardDoor.isUnlocked, isFalse);
        expect(
          forwardDoor.currentLabelLocalizationKey,
          'interaction.clearThreats',
        );
        game.world.player.position.setValues(
          forwardDoor.position.x,
          forwardDoor.position.y - 36,
        );
        expect(game.world.tryInteract(game.world.player), isTrue);
        await tester.pump(const Duration(milliseconds: 16));
        expect(game.campaignExploration.currentNode, spec.nodeId);
        expect(
          _doorLabel(forwardDoor),
          contains(game.localization.text('interaction.clearThreats')),
        );

        if (spec.mode == RegionalRoomObjectiveMode.ordered) {
          await _verifyWrongOrderedActivation(tester, game, room);
        }
        final objectiveBeforeCombat =
            spec.nodeId == CampaignNodeId.temporalAscent;
        if (objectiveBeforeCombat) {
          await _completeObjective(tester, game, room);
          await _pumpFrames(tester, 2);
          expect(room.roomObjectiveComplete, isTrue);
          expect(
            room.children.whereType<BossNameCardComponent>(),
            hasLength(1),
          );
          expect(forwardDoor.isUnlocked, isFalse);
          expect(
            forwardDoor.currentLabelLocalizationKey,
            'interaction.clearThreats',
          );
        }
        game.world.player.position.setValues(
          forwardDoor.position.x,
          forwardDoor.position.y - 36,
        );
        await tester.pump(const Duration(milliseconds: 16));

        await _defeatEncounterWaves(tester, game, room);
        if (objectiveBeforeCombat) {
          expect(room.encounterPhase, CampaignEncounterPhase.clearBeat);
          expect(forwardDoor.isUnlocked, isFalse);
          await _pumpRealSeconds(
            tester,
            room.layout.encounter!.clearBeatSeconds + .1,
          );
          expect(room.encounterPhase, CampaignEncounterPhase.cleared);
          expect(forwardDoor.isUnlocked, isTrue);
        } else {
          expect(room.encounterPhase, CampaignEncounterPhase.objectiveHold);
          expect(forwardDoor.isUnlocked, isFalse);
          expect(
            forwardDoor.currentLabelLocalizationKey,
            'interaction.completeRoomTask',
          );
          game.world.player.position.setValues(
            forwardDoor.position.x,
            forwardDoor.position.y - 36,
          );
          await tester.pump(const Duration(milliseconds: 16));
          expect(
            _doorLabel(forwardDoor),
            contains(game.localization.text('interaction.completeRoomTask')),
            reason:
                'The visible door label must update while the player stays nearby.',
          );
        }

        if (spec.mode == RegionalRoomObjectiveMode.timedAnyOrder) {
          final firstNode = room.objectiveNodes.singleWhere(
            (node) => node.nodeIndex == spec.activationOrder.first,
          );
          game.world.player.position.setFrom(firstNode.position);
          expect(game.world.tryInteract(game.world.player), isTrue);
          await tester.pump(const Duration(milliseconds: 16));
          expect(room.objectiveProgress, 1);
          game.world.player
            ..position.setFrom(room.playerSpawn)
            ..restoreIntegrity(game.world.player.maxIntegrity);
          // Temporal Hall intentionally freezes its simulation while the
          // player is idle. Keep a tiny intent active so this in-world relay
          // timer advances without moving through the room meaningfully.
          game.input.setVirtualMovement(.001, 0);
          for (
            var frame = 0;
            frame < ((spec.timeLimitSeconds! + 1) * 15).ceil();
            frame += 1
          ) {
            await tester.pump(const Duration(milliseconds: 67));
          }
          game.input.clearVirtualMovement();
          expect(room.objectiveProgress, 0);
          expect(room.objectiveNodes.every((node) => !node.activated), isTrue);
        }

        if (spec.disabledHazardSourceId case final sourceId?) {
          expect(_hasHazard(room, sourceId), isTrue);
        }

        if (spec.completionWindow !=
            RegionalRoomObjectiveCompletionWindow.none) {
          await _verifyUnsafeCompletionWindow(tester, game, room);
        }
        await _completeObjective(tester, game, room);
        await _pumpFrames(tester, 2);
        expect(room.roomObjectiveComplete, isTrue);
        if (!objectiveBeforeCombat) {
          expect(room.encounterPhase, CampaignEncounterPhase.clearBeat);
          expect(room.roomExitUnlocked, isFalse);
          await _pumpRealSeconds(
            tester,
            room.layout.encounter!.clearBeatSeconds + .1,
          );
          expect(room.encounterPhase, CampaignEncounterPhase.cleared);
        }
        expect(room.roomExitUnlocked, isTrue);
        expect(forwardDoor.isUnlocked, isTrue);
        if (!objectiveBeforeCombat) {
          expect(
            room.children.whereType<BossNameCardComponent>(),
            hasLength(1),
          );
        }
        if (spec.disabledHazardSourceId case final sourceId?) {
          expect(_hasHazard(room, sourceId), isFalse);
        }
        if (spec.nodeId == CampaignNodeId.collisionMerge) {
          expect(
            room.children
                .whereType<MergingPlatformComponent>()
                .single
                .isLockedMerged,
            isTrue,
          );
        }

        await _loadRegionalNode(tester, game, spec.nodeId);
        room = game.world.activeRoom! as RegionalCampaignNodeController;
        forwardDoor = _forwardDoor(room);
        expect(room.objectiveNodes.every((node) => node.activated), isTrue);
        expect(forwardDoor.isUnlocked, isTrue);
        expect(
          room.children.whereType<BossNameCardComponent>(),
          isEmpty,
          reason: 'A persisted completion must not replay its title card.',
        );
        if (spec.disabledHazardSourceId case final sourceId?) {
          expect(_hasHazard(room, sourceId), isFalse);
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

CampaignDoorComponent _forwardDoor(RegionalCampaignNodeController room) =>
    room.children.whereType<CampaignDoorComponent>().singleWhere(
      (door) =>
          door.labelLocalizationKey == 'interaction.nextRoom' ||
          door.labelLocalizationKey == 'interaction.enterBossRoom',
    );

String _doorLabel(CampaignDoorComponent door) =>
    door.children.whereType<TextComponent>().single.text;

bool _hasHazard(RegionalCampaignNodeController room, String sourceId) =>
    room.children.whereType<PulsingLaserComponent>().any(
      (hazard) => hazard.sourceId == sourceId,
    ) ||
    room.children.whereType<CrusherHazardComponent>().any(
      (hazard) => hazard.sourceId == sourceId,
    );

Future<void> _completeObjective(
  WidgetTester tester,
  PatchWorldGame game,
  RegionalCampaignNodeController room,
) async {
  final activationOrder =
      room.roomObjectiveSpec.mode == RegionalRoomObjectiveMode.anyOrder
      ? room.roomObjectiveSpec.activationOrder.reversed
      : room.roomObjectiveSpec.activationOrder;
  for (final nodeIndex in activationOrder) {
    final node = room.objectiveNodes.singleWhere(
      (candidate) => candidate.nodeIndex == nodeIndex,
    );
    if (node.activated) continue;
    for (var attempt = 0; attempt < 180; attempt += 1) {
      game.world.player.position.setFrom(node.position);
      expect(
        game.world.tryInteract(game.world.player),
        isTrue,
        reason: '${room.nodeId.name} node $nodeIndex ignored attempt $attempt.',
      );
      await tester.pump(const Duration(milliseconds: 50));
      if (node.activated || room.roomObjectiveComplete) break;
    }
    expect(
      node.activated || room.roomObjectiveComplete,
      isTrue,
      reason: '${room.nodeId.name} objective node $nodeIndex did not sync.',
    );
  }
}

Future<void> _defeatEncounterWaves(
  WidgetTester tester,
  PatchWorldGame game,
  RegionalCampaignNodeController room,
) async {
  final encounter = room.layout.encounter!;
  final enemies = room.children.whereType<PlatformerEnemyComponent>().toList(
    growable: false,
  );
  expect(enemies, hasLength(4));
  expect(enemies.every((enemy) => !enemy.isActiveThreat), isTrue);

  game.world.player.position.setValues(
    encounter.triggerZone.center.dx,
    encounter.triggerZone.center.dy,
  );
  await _pumpRealSeconds(tester, encounter.sealSeconds + .1);
  expect(room.encounterPhase, CampaignEncounterPhase.wave);

  for (var wave = 0; wave < encounter.waves.length; wave += 1) {
    final authoredWave = room.entry == CampaignNodeEntry.east
        ? encounter.waves.length - 1 - wave
        : wave;
    final expectedIds = encounter.waves[authoredWave].enemyIds.toSet();
    final expectedArchetypes = room.layout.enemies
        .where((enemy) => expectedIds.contains(enemy.id))
        .map((enemy) => enemy.archetype);
    final activeEnemies = room.activeEncounterEnemies;
    expect(activeEnemies, hasLength(expectedIds.length));
    expect(
      activeEnemies.map((enemy) => enemy.archetype),
      unorderedEquals(expectedArchetypes),
      reason: '${room.nodeId.name}/${room.entry.name} wave $wave',
    );
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
}

Future<void> _verifyWrongOrderedActivation(
  WidgetTester tester,
  PatchWorldGame game,
  RegionalCampaignNodeController room,
) async {
  final expectedFirst = room.roomObjectiveSpec.activationOrder.first;
  final wrongNode = room.objectiveNodes.firstWhere(
    (node) => node.nodeIndex != expectedFirst,
  );
  game.world.player.position.setFrom(wrongNode.position);
  expect(game.world.tryInteract(game.world.player), isTrue);
  await tester.pump(const Duration(milliseconds: 16));
  expect(room.objectiveProgress, 0);
  expect(room.objectiveNodes.every((node) => !node.activated), isTrue);
}

Future<void> _verifyUnsafeCompletionWindow(
  WidgetTester tester,
  PatchWorldGame game,
  RegionalCampaignNodeController room,
) async {
  final order = room.roomObjectiveSpec.activationOrder;
  for (final nodeIndex in order.take(order.length - 1)) {
    final node = room.objectiveNodes.singleWhere(
      (candidate) => candidate.nodeIndex == nodeIndex,
    );
    game.world.player.position.setFrom(node.position);
    expect(game.world.tryInteract(game.world.player), isTrue);
    await tester.pump(const Duration(milliseconds: 16));
    expect(node.activated, isTrue);
  }

  switch (room.roomObjectiveSpec.completionWindow) {
    case RegionalRoomObjectiveCompletionWindow.none:
      return;
    case RegionalRoomObjectiveCompletionWindow.hazardInactive:
      final laser = room.children
          .whereType<PulsingLaserComponent>()
          .singleWhere(
            (hazard) =>
                hazard.sourceId ==
                room.roomObjectiveSpec.disabledHazardSourceId,
          );
      await _pumpUntil(tester, () => laser.isActive);
    case RegionalRoomObjectiveCompletionWindow.platformMerged:
      final platform = room.children
          .whereType<MergingPlatformComponent>()
          .single;
      await _pumpUntil(tester, () => !platform.isMerged);
  }

  final finalNode = room.objectiveNodes.singleWhere(
    (candidate) => candidate.nodeIndex == order.last,
  );
  game.world.player.position.setFrom(finalNode.position);
  expect(game.world.tryInteract(game.world.player), isTrue);
  await tester.pump(const Duration(milliseconds: 16));
  expect(finalNode.activated, isFalse);
  expect(room.roomObjectiveComplete, isFalse);
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 240; frame += 1) {
    if (condition()) return;
    await tester.pump(const Duration(milliseconds: 16));
  }
  throw StateError('Timed out waiting for an objective completion window.');
}

Future<void> _loadRegionalNode(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId nodeId, {
  CampaignNodeEntry entry = CampaignNodeEntry.west,
}) async {
  game.currentRoom = switch (game.campaignWorld.nodes[nodeId]!.region) {
    CampaignRegion.temporalHall => RoomId.temporalHall,
    CampaignRegion.collisionArchive => RoomId.collisionArchive,
    _ => throw StateError('Not a regional exploration node: $nodeId'),
  };
  unawaited(game.world.loadCampaignNode(nodeId, entry: entry));
  game.resumeEngine();
  for (var attempt = 0; attempt < 180; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    final activeRoom = game.world.activeRoom;
    if (game.world.isReady &&
        activeRoom is RegionalCampaignNodeController &&
        activeRoom.nodeId == nodeId) {
      return;
    }
  }
  throw StateError('Timed out loading regional node ${nodeId.name}.');
}

Future<void> _mountGame(WidgetTester tester, PatchWorldGame game) async {
  Widget emptyOverlay(BuildContext context, PatchWorldGame activeGame) =>
      const SizedBox.shrink();
  await tester.pumpWidget(
    MaterialApp(
      home: GameWidget<PatchWorldGame>(
        game: game,
        overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
          OverlayIds.title: emptyOverlay,
          OverlayIds.weaponSelection: emptyOverlay,
          OverlayIds.patchSelection: emptyOverlay,
          OverlayIds.buildSelection: emptyOverlay,
          OverlayIds.patchApplied: emptyOverlay,
          OverlayIds.ending: emptyOverlay,
          OverlayIds.defeat: emptyOverlay,
          OverlayIds.hud: emptyOverlay,
          OverlayIds.touchControls: emptyOverlay,
        },
      ),
    ),
  );
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  unawaited(game.selectStartingWeapon(PlayerWeapon.sword));
  for (var attempt = 0; attempt < 180; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
    if (!game.overlays.isActive(OverlayIds.title) &&
        game.world.isReady &&
        game.selectedRunWeapon == PlayerWeapon.sword) {
      return;
    }
  }
  throw StateError('Timed out starting the regional objective test run.');
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _pumpRealSeconds(WidgetTester tester, double seconds) async {
  final frameCount = (seconds / .05).ceil();
  for (var frame = 0; frame < frameCount; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}
