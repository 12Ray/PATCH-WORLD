import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test('all later-region mandatory terrain is safe for every weapon', () {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    for (final nodeId in <CampaignNodeId>[
      ...CampaignWorldGraph.temporalMainPath,
      ...CampaignWorldGraph.collisionMainPath,
    ]) {
      final room = RegionalCampaignNodeController(
        nodeId: nodeId,
        entry: CampaignNodeEntry.west,
        progress:
            game.campaignWorld.nodes[nodeId]!.region ==
                CampaignRegion.temporalHall
            ? game.temporalHallProgress
            : game.collisionArchiveProgress,
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

  testWidgets('boss core, hub lift, and all-weapon regional traversal work', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    game.damageLabProgress
      ..clearedEncounterIds.addAll(<int>{0, 1, 2})
      ..bossDefeated = true
      ..bossRewardClaimed = true
      ..patchApplied = true;
    game.campaignExploration
      ..collectCoreSignature(CampaignRegion.damageLab)
      ..unlockShortcut(CampaignWorldGraph.temporalHubAccessId)
      ..unlockShortcut(CampaignWorldGraph.collisionHubAccessId);
    await _mountGame(tester, game, withPatchOverlays: true);

    await _verifyDamageBranchJunction(tester, game);

    await _useDoor(
      tester,
      game,
      'interaction.enterTemporalHall',
      CampaignNodeId.temporalAscent,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.tickRunner,
        PlatformerEnemyArchetype.echoBat,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.temporalFracture,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.delaySniper,
        PlatformerEnemyArchetype.tickRunner,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.temporalPendulum,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.rewindSkater,
        PlatformerEnemyArchetype.echoBat,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.enterBossRoom',
      CampaignNodeId.chronoJailer,
    );

    for (var frame = 0; frame < 90; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final room = game.world.activeRoom! as RegionalCampaignNodeController;
    expect(room.bossSeals, hasLength(2));
    final boss = room.boss!;
    expect(boss.phase, CampaignChapterBossPhase.phaseOne);
    expect(
      room.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseOne,
    );
    boss.receiveDamage(7);
    expect(boss.phase, CampaignChapterBossPhase.phaseTwo);
    expect(
      room.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseTwo,
    );
    boss.receiveDamage(13);
    for (var frame = 0; frame < 40; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(game.temporalHallProgress.bossDefeated, isTrue);
    expect(
      game.campaignExploration.coreSignatures,
      contains(CampaignRegion.temporalHall),
    );
    expect(
      game.campaignExploration.unlockedShortcutIds,
      contains(CampaignWorldGraph.temporalHubLiftId),
    );
    expect(room.bossSeals.every((seal) => seal.isUnlocked), isTrue);
    expect(room.bossArenaPresentation!.isCleared, isTrue);

    game.world.player.position.setValues(700, 478);
    expect(game.world.tryInteract(game.world.player), isTrue);
    game.world.player.position.setValues(850, 478);
    expect(game.world.tryInteract(game.world.player), isTrue);
    expect(game.overlays.isActive(OverlayIds.patchSelection), isTrue);
    game.selectPatch(PatchCatalog.roomTwoChoices.first.id);
    await _waitForNode(tester, game, CampaignNodeId.chronoJailer);
    expect(game.temporalHallProgress.patchApplied, isTrue);

    await _useDoor(
      tester,
      game,
      'interaction.returnHubLift',
      CampaignNodeId.bootSector,
    );
    expect(
      game.world.activeRoom!.children.whereType<CampaignDoorComponent>().map(
        (door) => door.labelLocalizationKey,
      ),
      contains('interaction.enterCollisionArchive'),
    );

    await _useDoor(
      tester,
      game,
      'interaction.enterCollisionArchive',
      CampaignNodeId.collisionCompression,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.vectorRam,
        PlatformerEnemyArchetype.polarityDrone,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.collisionFracture,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.phaseMimic,
        PlatformerEnemyArchetype.vectorRam,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.collisionMerge,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.shardLobber,
        PlatformerEnemyArchetype.polarityDrone,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.enterBossRoom',
      CampaignNodeId.kernelChimera,
    );
    for (var frame = 0; frame < 90; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final collisionRoom =
        game.world.activeRoom! as RegionalCampaignNodeController;
    final collisionBoss = collisionRoom.boss!;
    expect(collisionBoss.phase, CampaignChapterBossPhase.phaseOne);
    collisionBoss.receiveDamage(7);
    expect(collisionBoss.phase, CampaignChapterBossPhase.phaseTwo);
    expect(
      collisionRoom.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseTwo,
    );
    collisionBoss.receiveDamage(7);
    expect(collisionBoss.phase, CampaignChapterBossPhase.phaseThree);
    expect(
      collisionRoom.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseThree,
    );
    collisionBoss.receiveDamage(6);
    for (var frame = 0; frame < 40; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.collisionArchiveProgress.bossDefeated, isTrue);
    expect(
      game.campaignExploration.coreSignatures,
      contains(CampaignRegion.collisionArchive),
    );
    expect(collisionRoom.bossSeals.every((seal) => seal.isUnlocked), isTrue);
    expect(collisionRoom.bossArenaPresentation!.isCleared, isTrue);
    game.world.player.position.setValues(700, 478);
    expect(game.world.tryInteract(game.world.player), isTrue);
    game.world.player.position.setValues(850, 478);
    expect(game.world.tryInteract(game.world.player), isTrue);
    game.selectPatch(PatchCatalog.roomThreeChoices.first.id);
    await _waitForNode(tester, game, CampaignNodeId.kernelChimera);
    expect(game.collisionArchiveProgress.patchApplied, isTrue);
    await _useDoor(
      tester,
      game,
      'interaction.returnHubLift',
      CampaignNodeId.bootSector,
    );
    expect(game.campaignExploration.hasAllCoreSignatures, isTrue);

    for (final weapon in PlayerWeapon.values) {
      game.world.player.configureLoadout(
        weapon,
        assistMode: game.settings.value.assistMode,
      );
      final routes = weapon == PlayerWeapon.gauntlet
          ? <(String, List<CampaignNodeId>)>[
              (
                'interaction.enterCollisionArchive',
                CampaignWorldGraph.collisionMainPath,
              ),
              (
                'interaction.enterTemporalHall',
                CampaignWorldGraph.temporalMainPath,
              ),
            ]
          : <(String, List<CampaignNodeId>)>[
              (
                'interaction.enterTemporalHall',
                CampaignWorldGraph.temporalMainPath,
              ),
              (
                'interaction.enterCollisionArchive',
                CampaignWorldGraph.collisionMainPath,
              ),
            ];
      for (final route in routes) {
        await _traverseRegion(
          tester,
          game,
          entryLabel: route.$1,
          path: route.$2,
        );
      }
      expect(game.world.player.selectedWeapon, weapon);
    }
    expect(
      game.world.activeRoom!.children.whereType<CampaignDoorComponent>().map(
        (door) => door.labelLocalizationKey,
      ),
      contains('interaction.enterOptimizerCore'),
    );
    final optimizerWeapon = game.world.player.selectedWeapon;
    await tester.pump(const Duration(seconds: 7));
    await _useDoor(
      tester,
      game,
      'interaction.enterOptimizerCore',
      CampaignNodeId.optimizerCore,
    );
    expect(game.world.activeRoom, isA<BossRoomController>());
    expect(game.world.player.selectedWeapon, optimizerWeapon);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _verifyDamageBranchJunction(
  WidgetTester tester,
  PatchWorldGame game,
) async {
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
  final labels = game.world.activeRoom!.children
      .whereType<CampaignDoorComponent>()
      .map((door) => door.labelLocalizationKey);
  expect(
    labels,
    containsAll(<String>[
      'interaction.enterTemporalHall',
      'interaction.enterCollisionArchive',
    ]),
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
}

Future<void> _defeatActiveEncounter(
  WidgetTester tester,
  PatchWorldGame game, {
  required List<PlatformerEnemyArchetype> expected,
}) async {
  final enemies = game.world.activeRoom!.children
      .whereType<PlatformerEnemyComponent>()
      .toList(growable: false);
  expect(enemies, hasLength(2));
  expect(enemies.map((enemy) => enemy.archetype), unorderedEquals(expected));
  for (final enemy in enemies) {
    enemy.receiveDamage(99);
  }
  for (var frame = 0; frame < 4; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

Future<void> _traverseRegion(
  WidgetTester tester,
  PatchWorldGame game, {
  required String entryLabel,
  required List<CampaignNodeId> path,
}) async {
  await _useDoor(tester, game, entryLabel, path[0]);
  await _useDoor(tester, game, 'interaction.nextRoom', path[1]);
  await _useDoor(tester, game, 'interaction.previousRoom', path[0]);
  await _useDoor(tester, game, 'interaction.nextRoom', path[1]);
  await _useDoor(tester, game, 'interaction.nextRoom', path[2]);
  await _useDoor(tester, game, 'interaction.enterBossRoom', path[3]);
  await _useDoor(tester, game, 'interaction.previousRoom', path[2]);
  await _useDoor(tester, game, 'interaction.previousRoom', path[1]);
  await _useDoor(tester, game, 'interaction.previousRoom', path[0]);
  await _useDoor(
    tester,
    game,
    'interaction.returnBootSector',
    CampaignNodeId.bootSector,
  );
}

Future<void> _mountGame(
  WidgetTester tester,
  PatchWorldGame game, {
  bool withPatchOverlays = false,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: GameWidget(
        game: game,
        overlayBuilderMap: withPatchOverlays
            ? <String, OverlayWidgetBuilder<PatchWorldGame>>{
                OverlayIds.patchSelection: (_, _) => const SizedBox.shrink(),
                OverlayIds.patchApplied: (_, _) => const SizedBox.shrink(),
              }
            : const <String, OverlayWidgetBuilder<PatchWorldGame>>{},
      ),
    ),
  );
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
  throw StateError(
    'Timed out waiting for ${target.name}; '
    'current=${game.campaignExploration.currentNode?.name}, '
    'active=${game.world.activeRoom.runtimeType}',
  );
}
