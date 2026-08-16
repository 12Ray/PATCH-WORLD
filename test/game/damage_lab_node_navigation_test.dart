import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/damage_lab_floor_state.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/campaign_checkpoint_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_service_components.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/terrain_pulse_node_component.dart';
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
      if (nodeId != CampaignNodeId.overflowWarden) {
        expect(room.usesBackdropAlignedGeometry, isTrue);
        expect(room.worldSize, Vector2(1920, 1080));
        expect(room.killPlaneY, greaterThan(room.worldSize.y));
        expect(
          room.backdropAlignedPlatformBounds.every(
            (bounds) =>
                bounds.left >= 0 &&
                bounds.right <= room.worldSize.x &&
                bounds.bottom <= room.worldSize.y,
          ),
          isTrue,
        );
        expect(
          room.backdropAlignedPlatformBounds.any((bounds) => bounds.top < 300),
          isTrue,
          reason: '${nodeId.name} must include an upper exploration band.',
        );
        expect(
          room.backdropAlignedPlatformBounds.any((bounds) => bounds.top > 850),
          isTrue,
          reason: '${nodeId.name} must include a lower exploration band.',
        );
      }
      if (nodeId == CampaignNodeId.damageAssembly ||
          nodeId == CampaignNodeId.damageOverflow) {
        expect(room.combatEncounterSpecs, hasLength(4));
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
      if (weapon == PlayerWeapon.sword) {
        final room = game.world.activeRoom! as DamageLabNodeController;
        expect(room.usesBackdropAlignedGeometry, isTrue);
        expect(room.worldSize, Vector2(1920, 1080));
        expect(room.playerSpawn, Vector2(310, 474));
        expect(room.killPlaneY, greaterThan(room.worldSize.y));
        expect(room.cameraTargetFor(Vector2(960, 700)), Vector2(960, 632));
        expect(room.cameraZoomFor(Vector2(960, 700)), .92);
        expect(room.horizontalCameraLead, 96);
        expect(room.horizontalCameraDeadZone, 112);
        expect(room.verticalCameraDeadZone, 58);
        expect(
          room.backdropAlignedPlatformBounds.every(
            (bounds) =>
                bounds.left >= 0 &&
                bounds.right <= room.worldSize.x &&
                bounds.bottom <= room.worldSize.y,
          ),
          isTrue,
        );
        expect(
          room.backdropAlignedPlatformBounds.any((bounds) => bounds.top == 484),
          isFalse,
          reason:
              'The old synthetic floor must not cover the backdrop terrain.',
        );
        expect(
          room.backdropAlignedPlatformBounds.any((bounds) => bounds.top < 200),
          isTrue,
          reason: 'ROOM 1-1 must include a reachable upper exploration band.',
        );
        expect(
          room.backdropAlignedPlatformBounds.any((bounds) => bounds.top > 900),
          isTrue,
          reason: 'ROOM 1-1 must include a lower maintenance band.',
        );
        final backdrop = room.children
            .whereType<RoomBackdropComponent>()
            .single;
        expect(backdrop.size, Vector2(1920, 1080));
        expect(
          backdrop.environmentAsset,
          'assets/images/rooms/damage-lab-environment-v3.webp',
        );
        expect(
          room.children.whereType<CampaignRepairStationComponent>(),
          hasLength(1),
        );
        final visibleSurfaces = room.children
            .whereType<PlatformSurfaceComponent>()
            .where((surface) => !surface.isBoundary);
        expect(visibleSurfaces, isNotEmpty);
        expect(
          visibleSurfaces.every((surface) => !surface.renderArtwork),
          isTrue,
          reason: 'Backdrop terrain must not draw a duplicate skin.',
        );
        for (var frame = 0; frame < 60; frame += 1) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(game.camera.viewfinder.zoom, closeTo(.92, .01));
        final centralBandCameraY = game.camera.viewfinder.position.y;
        expect(
          centralBandCameraY,
          greaterThan(300),
          reason:
              'player=${game.world.player.position}, '
              'target=${room.cameraTargetFor(game.world.player.position)}, '
              'zoom=${game.camera.viewfinder.zoom}',
        );
        game.world.player
          ..resetMotionForRoomTransition()
          ..position.setValues(700, 124);
        for (var frame = 0; frame < 60; frame += 1) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(
          game.camera.viewfinder.position.y,
          lessThan(centralBandCameraY - 25),
          reason: 'The camera must follow the upper exploration band.',
        );
        final doors = room.children.whereType<CampaignDoorComponent>();
        expect(
          doors
              .singleWhere(
                (door) =>
                    door.labelLocalizationKey == 'interaction.returnBootSector',
              )
              .position,
          Vector2(105, 510),
        );
        expect(
          doors
              .singleWhere(
                (door) => door.labelLocalizationKey == 'interaction.nextRoom',
              )
              .position,
          Vector2(1820, 510),
        );
      }

      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );
      if (weapon == PlayerWeapon.sword) {
        final room = game.world.activeRoom! as DamageLabNodeController;
        _expectExpandedBackdropRoom(
          room,
          environmentAsset:
              'assets/images/rooms/damage-lab-maintenance-v1.webp',
          expectedSpawn: Vector2(140, 529),
          backDoorPosition: Vector2(105, 565),
          forwardDoorPosition: Vector2(1815, 565),
        );
        final checkpoint = room.children
            .whereType<CampaignCheckpointComponent>()
            .single;
        game.world.player.position.setValues(
          checkpoint.position.x,
          checkpoint.position.y - 36,
        );
        expect(room.tryInteract(game.world.player), isTrue);
        expect(
          room.respawnPointFor(Vector2(900, room.killPlaneY)),
          Vector2(1510, 529),
        );
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
        'interaction.nextRoom',
        CampaignNodeId.damageAssembly,
      );
      await _useDoor(
        tester,
        game,
        'interaction.nextRoom',
        CampaignNodeId.damageOverflow,
      );
      if (weapon == PlayerWeapon.sword) {
        final room = game.world.activeRoom! as DamageLabNodeController;
        _expectExpandedBackdropRoom(
          room,
          environmentAsset: 'assets/images/rooms/damage-lab-hazard-v1.webp',
          expectedSpawn: Vector2(140, 614),
          backDoorPosition: Vector2(105, 650),
          forwardDoorPosition: Vector2(1815, 650),
        );
        expect(room.children.whereType<PulsingLaserComponent>(), hasLength(3));
        expect(room.children.whereType<RoomHazardComponent>(), hasLength(3));
        expect(
          room.children.whereType<LoadoutEventTerminalComponent>(),
          hasLength(1),
        );
      }
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

void _expectExpandedBackdropRoom(
  DamageLabNodeController room, {
  required String environmentAsset,
  required Vector2 expectedSpawn,
  required Vector2 backDoorPosition,
  required Vector2 forwardDoorPosition,
}) {
  expect(room.usesBackdropAlignedGeometry, isTrue);
  expect(room.worldSize, Vector2(1920, 1080));
  expect(room.playerSpawn, expectedSpawn);
  expect(room.killPlaneY, greaterThan(room.worldSize.y));
  expect(room.cameraZoomFor(room.playerSpawn), .92);
  expect(room.horizontalCameraDeadZone, 112);
  expect(room.verticalCameraDeadZone, 58);
  final backdrop = room.children.whereType<RoomBackdropComponent>().single;
  expect(backdrop.size, Vector2(1920, 1080));
  expect(backdrop.environmentAsset, environmentAsset);
  final visibleSurfaces = room.children
      .whereType<PlatformSurfaceComponent>()
      .where(
        (surface) =>
            !surface.isBoundary && surface is! TerrainPulseBridgeComponent,
      );
  expect(visibleSurfaces, isNotEmpty);
  expect(visibleSurfaces.every((surface) => !surface.renderArtwork), isTrue);
  final doors = room.children.whereType<CampaignDoorComponent>();
  expect(
    doors
        .singleWhere(
          (door) => door.labelLocalizationKey == 'interaction.previousRoom',
        )
        .position,
    backDoorPosition,
  );
  expect(
    doors
        .singleWhere(
          (door) =>
              door.labelLocalizationKey == 'interaction.nextRoom' ||
              door.labelLocalizationKey == 'interaction.enterBossRoom',
        )
        .position,
    forwardDoorPosition,
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
    'current=${game.campaignExploration.currentNode?.name}, '
    'active=${game.world.activeRoom.runtimeType}',
  );
}
