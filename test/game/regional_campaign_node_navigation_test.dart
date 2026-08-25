import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/campaign/campaign_encounter_director.dart';
import 'package:patch_world/game/campaign/campaign_floor_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/campaign/platformer_traversal_contract.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/campaign_chapter_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/environment/campaign_service_components.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/items/campaign_loadout_reward_catalog.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
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
        layout: layouts.room(nodeId),
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

  test('regional boss entrances spawn the player inside both arena seals', () {
    for (final nodeId in const <CampaignNodeId>[
      CampaignNodeId.chronoJailer,
      CampaignNodeId.kernelChimera,
    ]) {
      for (final entry in CampaignNodeEntry.values) {
        final room = RegionalCampaignNodeController(
          nodeId: nodeId,
          entry: entry,
          progress: CampaignFloorState(),
          layout: layouts.room(nodeId),
        );
        final arena = room.bossArenaBounds!;
        expect(
          room.playerSpawn.x,
          inInclusiveRange(arena.left, arena.right),
          reason:
              '${nodeId.name}/${entry.name} must start between the locked seals.',
        );
      }
    }
  });

  test(
    'Temporal Hall exploration rooms use authored large-world contracts',
    () {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      const expectations = <(CampaignNodeId, List<PlatformerEnemyArchetype>)>[
        (
          CampaignNodeId.temporalAscent,
          <PlatformerEnemyArchetype>[
            PlatformerEnemyArchetype.tickRunner,
            PlatformerEnemyArchetype.echoBat,
            PlatformerEnemyArchetype.delaySniper,
            PlatformerEnemyArchetype.rewindSkater,
          ],
        ),
        (
          CampaignNodeId.temporalFracture,
          <PlatformerEnemyArchetype>[
            PlatformerEnemyArchetype.delaySniper,
            PlatformerEnemyArchetype.tickRunner,
            PlatformerEnemyArchetype.echoBat,
            PlatformerEnemyArchetype.rewindSkater,
          ],
        ),
        (
          CampaignNodeId.temporalPendulum,
          <PlatformerEnemyArchetype>[
            PlatformerEnemyArchetype.rewindSkater,
            PlatformerEnemyArchetype.echoBat,
            PlatformerEnemyArchetype.tickRunner,
            PlatformerEnemyArchetype.delaySniper,
          ],
        ),
      ];
      for (final expectation in expectations) {
        final room = RegionalCampaignNodeController(
          nodeId: expectation.$1,
          entry: CampaignNodeEntry.west,
          progress: game.temporalHallProgress,
          layout: layouts.room(expectation.$1),
        );
        expect(room.usesExpandedTemporalGeometry, isTrue);
        expect(room.worldSize.x, 1920);
        expect(room.worldSize.y, 1080);
        expect(room.killPlaneY, 1160);
        expect(room.environmentAsset, isNull);
        expect(room.horizontalCameraLead, 96);
        expect(room.horizontalCameraDeadZone, 112);
        expect(room.verticalCameraDeadZone, 58);
        expect(room.cameraFollowResponsiveness, 5.2);
        expect(room.cameraZoomFor(room.playerSpawn), .92);
        expect(room.authoredPlatformBounds, isNotEmpty);
        expect(
          room.authoredPlatformBounds.any((bounds) => bounds.top < 300),
          isTrue,
          reason: '${expectation.$1.name} needs an upper exploration band',
        );
        expect(
          room.authoredPlatformBounds.any(
            (bounds) => bounds.top >= 300 && bounds.top <= 750,
          ),
          isTrue,
          reason: '${expectation.$1.name} needs a middle combat band',
        );
        expect(
          room.authoredPlatformBounds.any((bounds) => bounds.top >= 900),
          isTrue,
          reason: '${expectation.$1.name} needs a lower optional loop',
        );
        expect(
          room.combatEncounterSpecs.map((spec) => spec.$1),
          orderedEquals(expectation.$2),
        );
        final eastEntryRoom = RegionalCampaignNodeController(
          nodeId: expectation.$1,
          entry: CampaignNodeEntry.east,
          progress: game.temporalHallProgress,
          layout: layouts.room(expectation.$1),
        );
        expect(
          _hasStaticUniversalRoute(room, eastEntryRoom.playerSpawn),
          isTrue,
          reason:
              '${expectation.$1.name} collision geometry must connect doors',
        );
      }
    },
  );

  test(
    'Collision Archive exploration rooms use authored large-world contracts',
    () {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      const expectations = <(CampaignNodeId, List<PlatformerEnemyArchetype>)>[
        (
          CampaignNodeId.collisionCompression,
          <PlatformerEnemyArchetype>[
            PlatformerEnemyArchetype.vectorRam,
            PlatformerEnemyArchetype.polarityDrone,
            PlatformerEnemyArchetype.phaseMimic,
            PlatformerEnemyArchetype.shardLobber,
          ],
        ),
        (
          CampaignNodeId.collisionFracture,
          <PlatformerEnemyArchetype>[
            PlatformerEnemyArchetype.phaseMimic,
            PlatformerEnemyArchetype.vectorRam,
            PlatformerEnemyArchetype.shardLobber,
            PlatformerEnemyArchetype.polarityDrone,
          ],
        ),
        (
          CampaignNodeId.collisionMerge,
          <PlatformerEnemyArchetype>[
            PlatformerEnemyArchetype.shardLobber,
            PlatformerEnemyArchetype.polarityDrone,
            PlatformerEnemyArchetype.vectorRam,
            PlatformerEnemyArchetype.phaseMimic,
          ],
        ),
      ];
      for (final expectation in expectations) {
        final room = RegionalCampaignNodeController(
          nodeId: expectation.$1,
          entry: CampaignNodeEntry.west,
          progress: game.collisionArchiveProgress,
          layout: layouts.room(expectation.$1),
        );
        expect(room.usesExpandedCollisionGeometry, isTrue);
        expect(room.usesExpandedRegionalGeometry, isTrue);
        expect(room.worldSize.x, 1920);
        expect(room.worldSize.y, 1080);
        expect(room.killPlaneY, 1160);
        expect(room.environmentAsset, isNull);
        expect(room.cameraZoomFor(room.playerSpawn), .92);
        expect(room.authoredPlatformBounds, isNotEmpty);
        expect(
          room.authoredPlatformBounds.any((bounds) => bounds.top < 300),
          isTrue,
        );
        expect(
          room.authoredPlatformBounds.any(
            (bounds) => bounds.top >= 300 && bounds.top <= 755,
          ),
          isTrue,
        );
        expect(
          room.authoredPlatformBounds.any((bounds) => bounds.top >= 900),
          isTrue,
        );
        expect(
          room.combatEncounterSpecs.map((spec) => spec.$1),
          orderedEquals(expectation.$2),
        );
        final eastEntryRoom = RegionalCampaignNodeController(
          nodeId: expectation.$1,
          entry: CampaignNodeEntry.east,
          progress: game.collisionArchiveProgress,
          layout: layouts.room(expectation.$1),
        );
        expect(
          _hasStaticUniversalRoute(room, eastEntryRoom.playerSpawn),
          isTrue,
          reason:
              '${expectation.$1.name} collision geometry must connect doors',
        );
      }
    },
  );

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
    _expectMountedExpandedTemporalRoom(
      game,
      nodeId: CampaignNodeId.temporalAscent,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.tickRunner,
        PlatformerEnemyArchetype.echoBat,
        PlatformerEnemyArchetype.delaySniper,
        PlatformerEnemyArchetype.rewindSkater,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.temporalFracture,
    );
    _expectMountedExpandedTemporalRoom(
      game,
      nodeId: CampaignNodeId.temporalFracture,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.delaySniper,
        PlatformerEnemyArchetype.tickRunner,
        PlatformerEnemyArchetype.echoBat,
        PlatformerEnemyArchetype.rewindSkater,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.temporalPendulum,
    );
    _expectMountedExpandedTemporalRoom(
      game,
      nodeId: CampaignNodeId.temporalPendulum,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.rewindSkater,
        PlatformerEnemyArchetype.echoBat,
        PlatformerEnemyArchetype.tickRunner,
        PlatformerEnemyArchetype.delaySniper,
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
    _expectRegionalStoryLayers(room, expectedMotif: StoryRoomVisualMotif.boss);
    expect(room.bossSeals, hasLength(2));
    final boss = room.boss!;
    expect(boss.phase, CampaignChapterBossPhase.phaseOne);
    expect(
      room.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseOne,
    );
    expect(
      room.bossArenaPresentation!.identity,
      BossArenaIdentity.chronoJailer,
    );
    await _waitForBossMechanicPhase(tester, room, 1);
    await _waitForRegionalBossAttackGate(tester, game, boss);
    boss.receiveDamage(999);
    expect(boss.phase, CampaignChapterBossPhase.phaseTwo);
    expect(
      room.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseTwo,
    );
    await _waitForBossMechanicPhase(tester, room, 2);
    _expectBossLasersStartWithWarning(room);
    await _waitForRegionalBossAttackGate(tester, game, boss);
    boss.receiveDamage(999);
    expect(boss.phase, CampaignChapterBossPhase.phaseThree);
    expect(
      room.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseThree,
    );
    await _waitForBossMechanicPhase(tester, room, 3);
    _expectBossLasersStartWithWarning(room);
    await _waitForRegionalBossAttackGate(tester, game, boss);
    boss.receiveDamage(999);
    expect(boss.phase, CampaignChapterBossPhase.defeated);
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
    expect(room.activeBossMechanicIds, isEmpty);

    final temporalReward = room.layout.requireAnchor(
      RegionalCampaignAnchorId.bossReward,
    );
    game.world.player.position.setValues(temporalReward.x, temporalReward.y);
    expect(game.world.tryInteract(game.world.player), isTrue);
    expect(room.isBossRewardDiscoveryActive, isTrue);
    expect(room.hasExitTerminal, isFalse);
    await _pumpRealSeconds(tester, 2.7);
    expect(room.isBossRewardDiscoveryActive, isFalse);
    expect(room.hasExitTerminal, isTrue);
    final temporalExit = room.layout.requireAnchor(
      RegionalCampaignAnchorId.exitTerminal,
    );
    game.world.player.position.setValues(temporalExit.x, temporalExit.y);
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
    _expectMountedExpandedCollisionRoom(
      game,
      nodeId: CampaignNodeId.collisionCompression,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.vectorRam,
        PlatformerEnemyArchetype.polarityDrone,
        PlatformerEnemyArchetype.phaseMimic,
        PlatformerEnemyArchetype.shardLobber,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.collisionFracture,
    );
    _expectMountedExpandedCollisionRoom(
      game,
      nodeId: CampaignNodeId.collisionFracture,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.phaseMimic,
        PlatformerEnemyArchetype.vectorRam,
        PlatformerEnemyArchetype.shardLobber,
        PlatformerEnemyArchetype.polarityDrone,
      ],
    );
    await _useDoor(
      tester,
      game,
      'interaction.nextRoom',
      CampaignNodeId.collisionMerge,
    );
    _expectMountedExpandedCollisionRoom(
      game,
      nodeId: CampaignNodeId.collisionMerge,
    );
    await _defeatActiveEncounter(
      tester,
      game,
      expected: const <PlatformerEnemyArchetype>[
        PlatformerEnemyArchetype.shardLobber,
        PlatformerEnemyArchetype.polarityDrone,
        PlatformerEnemyArchetype.vectorRam,
        PlatformerEnemyArchetype.phaseMimic,
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
    _expectRegionalStoryLayers(
      collisionRoom,
      expectedMotif: StoryRoomVisualMotif.boss,
    );
    final collisionBoss = collisionRoom.boss!;
    expect(collisionBoss.phase, CampaignChapterBossPhase.phaseOne);
    expect(
      collisionRoom.bossArenaPresentation!.identity,
      BossArenaIdentity.kernelChimera,
    );
    await _waitForBossMechanicPhase(tester, collisionRoom, 1);
    await _waitForRegionalBossAttackGate(tester, game, collisionBoss);
    collisionBoss.receiveDamage(999);
    expect(collisionBoss.phase, CampaignChapterBossPhase.phaseTwo);
    expect(
      collisionRoom.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseTwo,
    );
    await _waitForBossMechanicPhase(tester, collisionRoom, 2);
    _expectBossLasersStartWithWarning(collisionRoom);
    await _waitForRegionalBossAttackGate(tester, game, collisionBoss);
    collisionBoss.receiveDamage(999);
    expect(collisionBoss.phase, CampaignChapterBossPhase.phaseThree);
    expect(
      collisionRoom.bossArenaPresentation!.state,
      BossArenaPresentationState.phaseThree,
    );
    await _waitForBossMechanicPhase(tester, collisionRoom, 3);
    _expectBossLasersStartWithWarning(collisionRoom);
    await _waitForRegionalBossAttackGate(tester, game, collisionBoss);
    collisionBoss.receiveDamage(999);
    expect(collisionBoss.phase, CampaignChapterBossPhase.defeated);
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
    expect(collisionRoom.activeBossMechanicIds, isEmpty);
    final collisionReward = collisionRoom.layout.requireAnchor(
      RegionalCampaignAnchorId.bossReward,
    );
    game.world.player.position.setValues(collisionReward.x, collisionReward.y);
    expect(game.world.tryInteract(game.world.player), isTrue);
    expect(collisionRoom.isBossRewardDiscoveryActive, isTrue);
    expect(collisionRoom.hasExitTerminal, isFalse);
    await _pumpRealSeconds(tester, 2.7);
    expect(collisionRoom.isBossRewardDiscoveryActive, isFalse);
    expect(collisionRoom.hasExitTerminal, isTrue);
    final collisionExit = collisionRoom.layout.requireAnchor(
      RegionalCampaignAnchorId.exitTerminal,
    );
    game.world.player.position.setValues(collisionExit.x, collisionExit.y);
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

bool _hasStaticUniversalRoute(
  RegionalCampaignNodeController westEntryRoom,
  Vector2 eastSpawn,
) {
  final platforms = westEntryRoom.authoredPlatformBounds
      .where(
        (bounds) =>
            bounds.width >=
                PlatformerTraversalContract.minimumRequiredLandingWidth &&
            bounds.width > bounds.height * 2,
      )
      .toList(growable: false);
  Rect? platformAt(Vector2 spawn) {
    final feetY = spawn.y + 36;
    for (final bounds in platforms) {
      if (spawn.x >= bounds.left &&
          spawn.x <= bounds.right &&
          (bounds.top - feetY).abs() <= 1) {
        return bounds;
      }
    }
    return null;
  }

  final start = platformAt(westEntryRoom.playerSpawn);
  final goal = platformAt(eastSpawn);
  if (start == null || goal == null) return false;
  final visited = <Rect>{start};
  final frontier = <Rect>[start];
  while (frontier.isNotEmpty) {
    final current = frontier.removeAt(0);
    if (current == goal) return true;
    for (final candidate in platforms) {
      if (visited.contains(candidate)) continue;
      final rise = current.top - candidate.top;
      if (rise > PlatformerTraversalContract.maximumRequiredRise) continue;
      if (candidate.top - current.top > 90) continue;
      final gap = current.right < candidate.left
          ? candidate.left - current.right
          : candidate.right < current.left
          ? current.left - candidate.right
          : 0.0;
      if (gap > PlatformerTraversalContract.maximumRequiredGap) continue;
      visited.add(candidate);
      frontier.add(candidate);
    }
  }
  return false;
}

void _expectMountedExpandedTemporalRoom(
  PatchWorldGame game, {
  required CampaignNodeId nodeId,
}) {
  final room = game.world.activeRoom! as RegionalCampaignNodeController;
  expect(room.nodeId, nodeId);
  expect(room.worldSize.x, 1920);
  expect(room.worldSize.y, 1080);
  final layers = room.children.whereType<StoryRoomLayersComponent>().single;
  expect(layers.theme, room.mapArtSpec.theme);
  expect(layers.motif, room.mapArtSpec.motif);
  final visibleAuthoredSurfaces = room.children
      .whereType<PlatformSurfaceComponent>()
      .where((surface) => !surface.isBoundary)
      .toList(growable: false);
  expect(
    visibleAuthoredSurfaces.every((surface) => surface.renderArtwork),
    isTrue,
  );
  final rewindPlatforms = room.children
      .whereType<RewindPlatformComponent>()
      .toList(growable: false);
  expect(rewindPlatforms, isNotEmpty);
  final rewindBounds = rewindPlatforms.first.bounds;
  expect(
    room.solidBounds.any(
      (bounds) =>
          bounds.left == rewindBounds.left &&
          bounds.top == rewindBounds.top &&
          bounds.width == rewindBounds.width,
    ),
    isTrue,
    reason: 'The visible rewind platform must participate in collision.',
  );
  switch (nodeId) {
    case CampaignNodeId.temporalAscent:
      expect(room.children.whereType<MovingPlatformComponent>(), isNotEmpty);
      expect(
        room.children.whereType<CampaignRepairStationComponent>(),
        hasLength(1),
      );
    case CampaignNodeId.temporalFracture:
      expect(room.children.whereType<BreakablePlatformComponent>(), isNotEmpty);
    case CampaignNodeId.temporalPendulum:
      expect(rewindPlatforms, hasLength(1));
      expect(
        room.children.whereType<LoadoutEventTerminalComponent>().single.eventId,
        CampaignLoadoutEventId.temporalHall,
      );
    default:
      fail('Unexpected expanded Temporal Hall node: $nodeId');
  }
}

void _expectRegionalStoryLayers(
  RegionalCampaignNodeController room, {
  required StoryRoomVisualMotif expectedMotif,
}) {
  final layers = room.children.whereType<StoryRoomLayersComponent>().single;
  expect(layers.theme, room.mapArtSpec.theme);
  expect(layers.motif, expectedMotif);
  expect(
    room.children
        .whereType<PlatformSurfaceComponent>()
        .where((surface) => !surface.isBoundary)
        .every((surface) => surface.renderArtwork),
    isTrue,
  );
}

void _expectMountedExpandedCollisionRoom(
  PatchWorldGame game, {
  required CampaignNodeId nodeId,
}) {
  final room = game.world.activeRoom! as RegionalCampaignNodeController;
  expect(room.nodeId, nodeId);
  expect(room.usesExpandedCollisionGeometry, isTrue);
  expect(room.worldSize.x, 1920);
  expect(room.worldSize.y, 1080);
  final layers = room.children.whereType<StoryRoomLayersComponent>().single;
  expect(layers.theme, room.mapArtSpec.theme);
  expect(layers.motif, room.mapArtSpec.motif);
  final visibleAuthoredSurfaces = room.children
      .whereType<PlatformSurfaceComponent>()
      .where((surface) => !surface.isBoundary)
      .toList(growable: false);
  expect(
    visibleAuthoredSurfaces.every((surface) => surface.renderArtwork),
    isTrue,
  );
  late final PlatformSurfaceComponent stateSurface;
  switch (nodeId) {
    case CampaignNodeId.collisionCompression:
      expect(room.children.whereType<ConveyorPlatformComponent>(), isNotEmpty);
      expect(
        room.children.whereType<CampaignRepairStationComponent>(),
        hasLength(1),
      );
      stateSurface = room.children.whereType<MovingPlatformComponent>().first;
    case CampaignNodeId.collisionFracture:
      stateSurface = room.children
          .whereType<BreakablePlatformComponent>()
          .single;
    case CampaignNodeId.collisionMerge:
      final merging = room.children
          .whereType<MergingPlatformComponent>()
          .single;
      merging.update(merging.periodSeconds * .3);
      expect(merging.isMerged, isTrue);
      expect(
        room.children.whereType<LoadoutEventTerminalComponent>().single.eventId,
        CampaignLoadoutEventId.collisionArchive,
      );
      stateSurface = merging;
    default:
      fail('Unexpected expanded Collision Archive node: $nodeId');
  }
  final stateBounds = stateSurface.bounds;
  expect(
    room.solidBounds.any(
      (bounds) =>
          bounds.left == stateBounds.left &&
          bounds.top == stateBounds.top &&
          bounds.width == stateBounds.width,
    ),
    isTrue,
    reason: 'The visible collision-state platform must own live collision.',
  );
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
  expect(labels, contains('interaction.enterTemporalHall'));
  expect(
    labels,
    isNot(contains('interaction.enterCollisionArchive')),
    reason: 'ROOM3 must stay locked until the ROOM2 boss patch is applied.',
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
  final room = game.world.activeRoom! as RegionalCampaignNodeController;
  final encounter = room.layout.encounter!;
  final enemies = room.children.whereType<PlatformerEnemyComponent>().toList(
    growable: false,
  );
  expect(enemies, hasLength(expected.length));
  expect(enemies.map((enemy) => enemy.archetype), unorderedEquals(expected));
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
        .where((spec) => expectedIds.contains(spec.id))
        .map((spec) => spec.archetype);
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

  expect(room.encounterPhase, CampaignEncounterPhase.objectiveHold);
  await _completeActiveRoomObjective(tester, game, room);
  expect(room.encounterPhase, CampaignEncounterPhase.clearBeat);
  expect(room.roomExitUnlocked, isFalse);
  await _pumpRealSeconds(tester, encounter.clearBeatSeconds + .1);
  expect(room.encounterPhase, CampaignEncounterPhase.cleared);
  expect(room.roomExitUnlocked, isTrue);
}

Future<void> _completeActiveRoomObjective(
  WidgetTester tester,
  PatchWorldGame game,
  RegionalCampaignNodeController room,
) async {
  for (final nodeIndex in room.roomObjectiveSpec.activationOrder) {
    final node = room.objectiveNodes.singleWhere(
      (candidate) => candidate.nodeIndex == nodeIndex,
    );
    for (var attempt = 0; attempt < 160; attempt += 1) {
      game.world.player.position.setFrom(node.position);
      expect(game.world.tryInteract(game.world.player), isTrue);
      await tester.pump(const Duration(milliseconds: 50));
      if (node.activated || room.roomObjectiveComplete) break;
    }
    expect(node.activated || room.roomObjectiveComplete, isTrue);
  }
  expect(room.roomObjectiveComplete, isTrue);
}

Future<void> _pumpRealSeconds(WidgetTester tester, double seconds) async {
  final frameCount = (seconds / .05).ceil();
  for (var frame = 0; frame < frameCount; frame += 1) {
    await tester.pump(const Duration(milliseconds: 50));
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

Future<void> _waitForRegionalBossAttackGate(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignChapterBossComponent boss,
) async {
  game.resumeEngine();
  game.input.setVirtualMovement(.01, 0);
  try {
    for (var frame = 0; frame < 80; frame += 1) {
      if (!boss.isPhaseTransitioning &&
          boss.hasCompletedRepresentativePatternsInCurrentPhase) {
        return;
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
  } finally {
    game.input.clearVirtualMovement();
  }
  throw StateError(
    'Timed out waiting for ${boss.phase.name} to complete an attack.',
  );
}

Future<void> _waitForBossMechanicPhase(
  WidgetTester tester,
  RegionalCampaignNodeController room,
  int phase,
) async {
  final expectedIds = room.layout.bossMechanics
      .where((mechanic) => mechanic.isActiveInPhase(phase))
      .map((mechanic) => mechanic.id)
      .toSet();
  for (var frame = 0; frame < 60; frame += 1) {
    final actualIds = room.activeBossMechanicIds;
    if (room.activeBossMechanicPhase == phase &&
        actualIds.length == expectedIds.length &&
        actualIds.containsAll(expectedIds)) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 16));
  }
  throw StateError(
    'Timed out mounting phase $phase mechanics for ${room.nodeId.name}; '
    'active=${room.activeBossMechanicIds}.',
  );
}

void _expectBossLasersStartWithWarning(RegionalCampaignNodeController room) {
  final lasers = room.children
      .whereType<PulsingLaserComponent>()
      .where(
        (laser) =>
            laser.sourceId.contains('jailer') ||
            laser.sourceId.contains('chimera'),
      )
      .toList(growable: false);
  expect(lasers, isNotEmpty);
  expect(
    lasers.every((laser) => laser.isInStartupGrace && !laser.isActive),
    isTrue,
    reason: 'A newly mounted boss seam must telegraph before it can damage.',
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
