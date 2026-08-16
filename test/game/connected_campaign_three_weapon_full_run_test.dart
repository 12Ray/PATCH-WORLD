import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/builds/weapon_build_state.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
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
    'sword, gauntlet, and gun each finish the connected campaign',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      await _mountGame(tester, game);

      for (final weapon in PlayerWeapon.values) {
        await tester.runAsync(() => game.selectStartingWeapon(weapon));
        await tester.pump(const Duration(milliseconds: 16));

        final encountered = <PlatformerEnemyArchetype>{};
        await _completeCampaign(tester, game, weapon, encountered);

        final summary = game.completedRun.value;
        expect(summary, isNotNull);
        expect(summary!.endingId, 'preserve');
        expect(summary.selectedWeapon, weapon);
        expect(summary.selectedPatchIds, hasLength(3));
        expect(summary.weaponBuildTiers, hasLength(3));
        expect(encountered, unorderedEquals(PlatformerEnemyArchetype.values));
        expect(game.world.player.selectedWeapon, weapon);
        expect(game.campaignExploration.hasAllCoreSignatures, isTrue);
        expect(game.weaponBuild.totalChoices, 3);
        expect(game.damageLabProgress.claimedBuildRewardIds, <int>{0, 1, 2});

        game.returnToTitle();
        await _waitForTitleReset(tester, game);
        expect(game.selectedRunWeapon, isNull);
        expect(game.runState.selectedPatchIds, isEmpty);
        expect(game.campaignExploration.coreSignatures, isEmpty);
        expect(game.damageLabProgress.clearedEncounterIds, isEmpty);
        expect(game.temporalHallProgress.clearedEncounterIds, isEmpty);
        expect(game.collisionArchiveProgress.clearedEncounterIds, isEmpty);
        expect(game.weaponBuild.totalChoices, 0);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
    timeout: const Timeout(Duration(minutes: 4)),
  );
}

Future<void> _completeCampaign(
  WidgetTester tester,
  PatchWorldGame game,
  PlayerWeapon weapon,
  Set<PlatformerEnemyArchetype> encountered,
) async {
  expect(game.campaignExploration.currentNode, CampaignNodeId.bootSector);
  expect(game.world.player.selectedWeapon, weapon);

  await _useDoor(
    tester,
    game,
    'interaction.enterDamageLab',
    CampaignNodeId.damageWorkshop,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.nextRoom',
    CampaignNodeId.damageAssembly,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.nextRoom',
    CampaignNodeId.damageOverflow,
  );
  await _clearEncounter(tester, game, encountered);
  expect(
    game.campaignExploration.unlockedShortcutIds,
    contains(CampaignWorldGraph.damageMaintenanceShortcutId),
  );
  await _useDoor(
    tester,
    game,
    'interaction.useMaintenanceShortcut',
    CampaignNodeId.damageWorkshop,
  );
  await _useDoor(
    tester,
    game,
    'interaction.useMaintenanceShortcut',
    CampaignNodeId.damageOverflow,
  );
  await _useDoor(
    tester,
    game,
    'interaction.enterBossRoom',
    CampaignNodeId.overflowWarden,
  );
  encountered.add(PlatformerEnemyArchetype.overflowWarden);
  await _defeatDamageBoss(tester, game);
  await _claimBossRewardAndOpenPatch(tester, game);
  game.selectPatch(PatchCatalog.roomOneChoices.first.id);
  await _waitForPatchApplied(
    tester,
    game,
    CampaignNodeId.overflowWarden,
    () => game.damageLabProgress.patchApplied,
  );

  await _useDoor(
    tester,
    game,
    'interaction.enterTemporalHall',
    CampaignNodeId.temporalAscent,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.nextRoom',
    CampaignNodeId.temporalFracture,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.nextRoom',
    CampaignNodeId.temporalPendulum,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.enterBossRoom',
    CampaignNodeId.chronoJailer,
  );
  encountered.add(PlatformerEnemyArchetype.chronoJailer);
  await _defeatRegionalBoss(tester, game);
  await _claimBossRewardAndOpenPatch(tester, game);
  game.selectPatch(PatchCatalog.roomTwoChoices.first.id);
  await _waitForPatchApplied(
    tester,
    game,
    CampaignNodeId.chronoJailer,
    () => game.temporalHallProgress.patchApplied,
  );
  await _useDoor(
    tester,
    game,
    'interaction.returnHubLift',
    CampaignNodeId.bootSector,
  );

  await _useDoor(
    tester,
    game,
    'interaction.enterCollisionArchive',
    CampaignNodeId.collisionCompression,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.nextRoom',
    CampaignNodeId.collisionFracture,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.nextRoom',
    CampaignNodeId.collisionMerge,
  );
  await _clearEncounter(tester, game, encountered);
  await _useDoor(
    tester,
    game,
    'interaction.enterBossRoom',
    CampaignNodeId.kernelChimera,
  );
  encountered.add(PlatformerEnemyArchetype.kernelChimera);
  await _defeatRegionalBoss(tester, game);
  await _claimBossRewardAndOpenPatch(tester, game);
  game.selectPatch(PatchCatalog.roomThreeChoices.first.id);
  await _waitForPatchApplied(
    tester,
    game,
    CampaignNodeId.kernelChimera,
    () => game.collisionArchiveProgress.patchApplied,
  );
  await _useDoor(
    tester,
    game,
    'interaction.returnHubLift',
    CampaignNodeId.bootSector,
  );

  expect(game.campaignExploration.hasAllCoreSignatures, isTrue);
  await _useDoor(
    tester,
    game,
    'interaction.enterOptimizerCore',
    CampaignNodeId.optimizerCore,
  );
  expect(game.world.player.selectedWeapon, weapon);
  await _pumpFrames(tester, 90, const Duration(milliseconds: 100));

  final optimizerRoom = game.world.activeRoom! as BossRoomController;
  optimizerRoom.boss.receiveDamage(99);
  game.world.player.position.setValues(960, 980);
  expect(game.world.tryInteract(game.world.player), isTrue);
  optimizerRoom.boss.receiveHealing(150);
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 16));

  expect(game.overlays.isActive(OverlayIds.ending), isTrue);
  game.chooseEnding('preserve');
}

Future<void> _clearEncounter(
  WidgetTester tester,
  PatchWorldGame game,
  Set<PlatformerEnemyArchetype> encountered,
) async {
  final activeRoom = game.world.activeRoom!;
  final enemies = activeRoom.children
      .whereType<PlatformerEnemyComponent>()
      .toList(growable: false);
  final expectedEnemyCount =
      activeRoom is DamageLabNodeController &&
          (activeRoom.nodeId == CampaignNodeId.damageAssembly ||
              activeRoom.nodeId == CampaignNodeId.damageOverflow)
      ? 4
      : activeRoom is RegionalCampaignNodeController &&
            activeRoom.usesExpandedRegionalGeometry
      ? 4
      : 2;
  expect(enemies, hasLength(expectedEnemyCount));
  encountered.addAll(enemies.map((enemy) => enemy.archetype));
  for (final enemy in enemies) {
    enemy.receiveDamage(99);
  }
  await _pumpFrames(tester, 2, const Duration(milliseconds: 16));
  if (activeRoom is DamageLabNodeController) {
    final request = game.pendingWeaponBuildSelection;
    expect(request, isNotNull);
    expect(request!.encounterId, activeRoom.encounterId);
    final choices = WeaponBuildCatalog.choicesFor(request.weapon);
    expect(
      game.selectRoomOneBuildUpgrade(choices[activeRoom.encounterId]),
      isTrue,
    );
  }
  await _pumpFrames(tester, 3, const Duration(milliseconds: 16));
}

Future<void> _defeatDamageBoss(WidgetTester tester, PatchWorldGame game) async {
  await _pumpFrames(tester, 90, const Duration(milliseconds: 100));
  final room = game.world.activeRoom! as DamageLabNodeController;
  expect(room.boss, isNotNull);
  room.boss!.receiveHealing(99);
  await _pumpFrames(tester, 30, const Duration(milliseconds: 100));
  expect(game.damageLabProgress.bossDefeated, isTrue);
}

Future<void> _defeatRegionalBoss(
  WidgetTester tester,
  PatchWorldGame game,
) async {
  await _pumpFrames(tester, 90, const Duration(milliseconds: 100));
  final room = game.world.activeRoom! as RegionalCampaignNodeController;
  expect(room.boss, isNotNull);
  room.boss!.receiveDamage(99);
  await _pumpFrames(tester, 20, const Duration(milliseconds: 100));
  expect(room.isCompleted, isTrue);
}

Future<void> _claimBossRewardAndOpenPatch(
  WidgetTester tester,
  PatchWorldGame game,
) async {
  await tester.pump(const Duration(milliseconds: 16));
  game.world.player.position.setValues(700, 478);
  expect(game.world.tryInteract(game.world.player), isTrue);
  game.world.player.position.setValues(850, 478);
  expect(game.world.tryInteract(game.world.player), isTrue);
  await tester.pump();
  expect(game.pendingPatchSelection, isNotNull);
  expect(game.overlays.isActive(OverlayIds.patchSelection), isTrue);
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
  expect(game.world.player.selectedWeapon, game.selectedRunWeapon);
}

Future<void> _waitForNode(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId target,
) async {
  await _waitUntil(
    tester,
    () =>
        game.world.isReady &&
        !game.isRoomTransitionInProgress &&
        game.campaignExploration.currentNode == target,
    description: 'node ${target.name}',
  );
}

Future<void> _waitForPatchApplied(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId target,
  bool Function() isApplied,
) async {
  await _waitUntil(
    tester,
    () =>
        isApplied() &&
        game.pendingPatchSelection == null &&
        game.world.isReady &&
        !game.isRoomTransitionInProgress &&
        game.campaignExploration.currentNode == target,
    description: 'patch application in ${target.name}',
  );
}

Future<void> _waitForTitleReset(
  WidgetTester tester,
  PatchWorldGame game,
) async {
  await _waitUntil(
    tester,
    () =>
        game.overlays.isActive(OverlayIds.title) &&
        game.world.isReady &&
        game.campaignExploration.currentNode == CampaignNodeId.bootSector,
    description: 'title reset',
  );
}

Future<void> _waitUntil(
  WidgetTester tester,
  bool Function() predicate, {
  required String description,
}) async {
  for (var attempt = 0; attempt < 180; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 4)),
    );
    if (predicate()) return;
  }
  throw StateError('Timed out waiting for $description.');
}

Future<void> _pumpFrames(
  WidgetTester tester,
  int count,
  Duration duration,
) async {
  for (var frame = 0; frame < count; frame += 1) {
    await tester.pump(duration);
  }
}
