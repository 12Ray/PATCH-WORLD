import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
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
    'Warden arena seals, zooms, reacts to phases, and presents its reward',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      game.damageLabProgress.clearedEncounterIds.addAll(<int>{0, 1, 2});
      await _mountGame(tester, game);

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

      final room = game.world.activeRoom! as DamageLabNodeController;
      await tester.pump(const Duration(milliseconds: 16));
      expect(room.bossSeals, hasLength(2));
      expect(room.bossSeals.every((seal) => !seal.isUnlocked), isTrue);
      expect(room.isBossIntroActive, isTrue);
      expect(
        room.cameraZoomFor(game.world.player.position),
        closeTo(.94, .001),
      );
      expect(room.children.whereType<BossNameCardComponent>(), isNotEmpty);
      expect(
        room.bossArenaPresentation!.state,
        BossArenaPresentationState.intro,
      );

      for (var frame = 0; frame < 70; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      final boss = room.boss!;
      expect(boss.phase, OverflowWardenPhase.shielded);
      expect(
        room.bossArenaPresentation!.state,
        BossArenaPresentationState.phaseOne,
      );

      await _waitForWardenAttackGate(tester, boss);
      boss.receiveHealing(99);
      expect(boss.phase, OverflowWardenPhase.breached);
      expect(boss.health, 18);
      expect(boss.isPhaseTransitioning, isTrue);
      boss.receiveHealing(99);
      expect(boss.health, 18);
      expect(
        room.bossArenaPresentation!.state,
        BossArenaPresentationState.phaseTwo,
      );
      await _waitForWardenAttackGate(tester, boss);
      boss.receiveHealing(99);
      expect(boss.phase, OverflowWardenPhase.critical);
      expect(boss.health, 21);
      expect(
        room.bossArenaPresentation!.state,
        BossArenaPresentationState.phaseThree,
      );
      await _waitForWardenAttackGate(tester, boss);
      boss.receiveHealing(99);
      expect(boss.phase, OverflowWardenPhase.overflowing);
      expect(boss.health, boss.maximumOverflowHealth);
      for (var frame = 0; frame < 35; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(game.damageLabProgress.bossDefeated, isTrue);
      expect(room.bossSeals.every((seal) => seal.isUnlocked), isTrue);
      expect(room.bossArenaPresentation!.isCleared, isTrue);
      expect(
        game.campaignExploration.coreSignatures,
        contains(CampaignRegion.damageLab),
      );
      expect(
        room.children.whereType<BossNameCardComponent>().any(
          (card) => card.style == BossNameCardStyle.victory,
        ),
        isTrue,
      );
      expect(room.hasExitTerminal, isFalse);

      await tester.pump(const Duration(milliseconds: 16));
      game.world.player.position.setValues(700, 478);
      expect(game.world.tryInteract(game.world.player), isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      expect(room.isBossRewardDiscoveryActive, isTrue);
      expect(room.hasExitTerminal, isFalse);
      final discovery = room.children
          .whereType<ItemDiscoveryPresentationComponent>()
          .single;
      expect(discovery.rewardTier, ItemRewardTier.boss);
      for (var frame = 0; frame < 42; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(room.isBossRewardDiscoveryActive, isFalse);
      expect(room.hasExitTerminal, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _waitForWardenAttackGate(
  WidgetTester tester,
  OverflowWardenBossComponent boss,
) async {
  for (var frame = 0; frame < 240; frame += 1) {
    if (!boss.isPhaseTransitioning && boss.hasCompletedAttackInCurrentPhase) {
      return;
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  throw StateError('Warden did not complete its required phase attack.');
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
