import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/ordinary_jump_reachability.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boot_sector_controller.dart';
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

  testWidgets('Boot Sector and Damage Lab form a two-way safe transition', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    expect(game.world.activeRoom, isA<BootSectorController>());
    expect(game.campaignExploration.currentNode, CampaignNodeId.bootSector);
    final bootRoom = game.world.activeRoom!;
    final bootLayers = bootRoom.children
        .whereType<StoryRoomLayersComponent>()
        .single;
    expect(bootLayers.theme, StoryRegionVisualTheme.boot);
    expect(bootLayers.motif, StoryRoomVisualMotif.hub);
    final bootSurfaces = bootRoom.children
        .whereType<PlatformSurfaceComponent>()
        .toList(growable: false);
    expect(bootSurfaces.where((surface) => surface.isBoundary), hasLength(2));
    expect(
      bootSurfaces.where((surface) => !surface.isBoundary),
      everyElement(
        isA<PlatformSurfaceComponent>().having(
          (surface) => surface.renderArtwork,
          'renderArtwork',
          isTrue,
        ),
      ),
    );
    final bootDoor = game.world.activeRoom!.children
        .whereType<CampaignDoorComponent>()
        .single;
    bootDoor.update(.016);
    expect(bootDoor.children.whereType<TextComponent>().single.text, isEmpty);
    game.world.player.position.setValues(
      bootDoor.position.x,
      bootDoor.position.y - 36,
    );
    bootDoor.update(.016);
    expect(
      bootDoor.children.whereType<TextComponent>().single.text,
      contains('[L]'),
    );
    expect(game.world.tryInteract(game.world.player), isTrue);
    await _waitForRoom(tester, game, RoomId.damageLab);

    expect(game.world.activeRoom, isA<DamageLabNodeController>());
    expect(game.campaignExploration.currentNode, CampaignNodeId.damageWorkshop);
    final damageDoors = game.world.activeRoom!.children
        .whereType<CampaignDoorComponent>()
        .toList(growable: false);
    final returnDoor = damageDoors.singleWhere(
      (door) => door.labelLocalizationKey == 'interaction.returnBootSector',
    );
    final forwardDoor = damageDoors.singleWhere(
      (door) => door.labelLocalizationKey == 'interaction.nextRoom',
    );
    expect(returnDoor.isUnlocked, isTrue);
    expect(forwardDoor.isUnlocked, isFalse);
    game.damageLabProgress.bossDefeated = true;
    game.world.player.position.setValues(
      returnDoor.position.x,
      returnDoor.position.y - 36,
    );
    expect(game.world.tryInteract(game.world.player), isTrue);
    await _waitForRoom(tester, game, RoomId.bootSector);

    expect(game.world.activeRoom, isA<BootSectorController>());
    final clearedDamageDoor = game.world.activeRoom!.children
        .whereType<CampaignDoorComponent>()
        .single;
    expect(clearedDamageDoor.isCompleted, isTrue);
    game.world.player.position.setValues(
      clearedDamageDoor.position.x,
      clearedDamageDoor.position.y - 36,
    );
    clearedDamageDoor.update(.016);
    expect(
      clearedDamageDoor.children.whereType<TextComponent>().single.text,
      allOf(
        contains('✓'),
        contains(game.localization.text('interaction.regionComplete')),
      ),
    );
    expect(
      game.campaignExploration.visitedNodeIds,
      containsAll(<CampaignNodeId>[
        CampaignNodeId.bootSector,
        CampaignNodeId.damageWorkshop,
      ]),
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('every story door in the Boot hub needs only ordinary movement', () {
    final anchors = <OrdinaryJumpAnchor>[
      for (final entry in BootSectorController.mandatoryDoorFeet.entries)
        OrdinaryJumpAnchor(id: entry.key, feet: entry.value),
    ];
    final result = OrdinaryJumpReachability.analyze(
      surfaces: <OrdinaryJumpSurface>[
        for (final (index, bounds)
            in BootSectorController.ordinaryStaticSurfaces.indexed)
          OrdinaryJumpSurface(id: 'boot.surface.$index', bounds: bounds),
      ],
      start: OrdinaryJumpAnchor(
        id: 'boot.westSpawn',
        feet: Offset(
          BootSectorController.westSpawnCenter.dx,
          BootSectorController.westSpawnCenter.dy + 16,
        ),
        settleDistance: 64,
      ),
      requiredAnchors: anchors,
    );
    expect(anchors, hasLength(4));
    for (final anchor in anchors) {
      expect(
        result.isAnchorReachable(anchor.id),
        isTrue,
        reason: '${anchor.id} must stay on the ordinary Boot hub route.',
      );
    }
  });
}

Future<void> _waitForRoom(
  WidgetTester tester,
  PatchWorldGame game,
  RoomId target,
) async {
  for (var attempt = 0; attempt < 100; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == target &&
        game.world.isReady &&
        !game.isRoomTransitionInProgress &&
        !game.paused) {
      return;
    }
  }
  throw StateError(
    'Timed out waiting for $target; current=${game.currentRoom}, '
    'ready=${game.world.isReady}, '
    'transition=${game.isRoomTransitionInProgress}, paused=${game.paused}, '
    'active=${game.world.activeRoom.runtimeType}, '
    'mounted=${game.world.activeRoom?.isMounted}, '
    'removing=${game.world.activeRoom?.isRemoving}',
  );
}
