import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/boss/overflow_warden_boss_component.dart';
import 'package:patch_world/game/components/enemies/platformer_enemy_component.dart';
import 'package:patch_world/game/components/environment/campaign_door_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rooms/maps/damage_lab_room_layout.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  test('Warden vent offsets cannot bypass the phase-entry warning', () {
    final vent = WardenPressureVentComponent(
      const DamageLabPressureVentSpec(
        id: 'test.east-vent',
        bounds: Rect.fromLTWH(0, 0, 128, 128),
        activeFromPhase: 2,
        phaseOffset: 1.44,
      ),
    );

    vent.setBossPhase(3);
    vent.update(WardenPressureVentComponent.phaseEntryGraceSeconds - .01);

    expect(vent.isBurstActive, isFalse);
    expect(vent.phaseGraceRemaining, closeTo(.01, .001));
  });

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
      expect(room.worldSize.x, greaterThanOrEqualTo(1440));
      expect(room.worldSize.y, greaterThanOrEqualTo(832));
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
      expect(
        room.bossArenaPresentation!.identity,
        BossArenaIdentity.overflowWarden,
      );
      expect(room.wardenPressureVents, hasLength(3));
      expect(room.wardenPhasePlatforms, hasLength(2));
      expect(room.wardenSafeZones, hasLength(3));
      expect(room.wardenSummonGates, hasLength(2));
      expect(room.wardenPressureVents.any((vent) => vent.isEnabled), isFalse);
      expect(
        room.wardenPhasePlatforms.any((platform) => platform.isSolid),
        isFalse,
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
      await _expectShieldChargeMoves(tester, game, boss);

      await _waitForWardenAttackGate(tester, game, boss);
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
      expect(
        room.wardenPressureVents.where((vent) => vent.isEnabled),
        hasLength(2),
      );
      expect(
        room.wardenPhasePlatforms.where((platform) => platform.isSolid),
        hasLength(1),
      );
      expect(room.wardenSummonGates.where((gate) => gate.isOpen), hasLength(1));
      await tester.pump(const Duration(milliseconds: 16));
      expect(room.activeWardenSummons, hasLength(1));
      expect(
        room.activeWardenSummons.single.archetype,
        PlatformerEnemyArchetype.repairLeech,
      );
      while (boss.isPhaseTransitioning) {
        game.world.player.restoreIntegrity(99);
        await tester.pump(const Duration(milliseconds: 100));
      }
      final summon = room.activeWardenSummons.single;
      final phaseTwoHealth = boss.health;
      final summonPosition = summon.position.clone();
      summon.position.setValues(160, summon.position.y);
      expect(summon.debugRepairNearestAlly(), isFalse);
      expect(boss.health, phaseTwoHealth);
      summon.position.setFrom(summonPosition);
      expect(summon.debugRepairNearestAlly(), isTrue);
      expect(boss.health, phaseTwoHealth + 1);
      await _waitForWardenAttackGate(tester, game, boss);
      boss.receiveHealing(99);
      expect(boss.phase, OverflowWardenPhase.critical);
      expect(boss.health, 21);
      expect(
        room.bossArenaPresentation!.state,
        BossArenaPresentationState.phaseThree,
      );
      expect(
        room.wardenPressureVents.where((vent) => vent.isEnabled),
        hasLength(3),
      );
      expect(
        room.wardenPhasePlatforms.where((platform) => platform.isSolid),
        hasLength(2),
      );
      expect(room.wardenSummonGates.where((gate) => gate.isOpen), hasLength(2));
      await tester.pump(const Duration(milliseconds: 16));
      expect(room.activeWardenSummons, hasLength(2));
      await _waitForWardenAttackGate(tester, game, boss);
      boss.receiveHealing(99);
      expect(boss.phase, OverflowWardenPhase.overflowing);
      expect(boss.health, boss.maximumOverflowHealth);
      for (var frame = 0; frame < 35; frame += 1) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(game.damageLabProgress.bossDefeated, isTrue);
      expect(room.bossSeals.every((seal) => seal.isUnlocked), isTrue);
      expect(room.bossArenaPresentation!.isCleared, isTrue);
      expect(room.wardenPressureVents.any((vent) => vent.isEnabled), isFalse);
      expect(
        room.wardenPhasePlatforms.every((platform) => platform.isSolid),
        isTrue,
      );
      expect(room.wardenSummonGates.any((gate) => gate.isOpen), isFalse);
      expect(room.activeWardenSummons, isEmpty);
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
      game.world.player.position.setFrom(
        room.layout.requireAnchor(DamageLabAnchorId.bossReward).toVector2(),
      );
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

Future<void> _expectShieldChargeMoves(
  WidgetTester tester,
  PatchWorldGame game,
  OverflowWardenBossComponent boss,
) async {
  for (var frame = 0; frame < 240; frame += 1) {
    game.world.player.restoreIntegrity(99);
    if (boss.isShieldCharging) {
      final before = boss.position.x;
      await tester.pump(const Duration(milliseconds: 50));
      expect((boss.position.x - before).abs(), greaterThan(1));
      return;
    }
    await tester.pump(const Duration(milliseconds: 50));
  }
  throw StateError('Warden never entered its physical shield charge.');
}

Future<void> _waitForWardenAttackGate(
  WidgetTester tester,
  PatchWorldGame game,
  OverflowWardenBossComponent boss,
) async {
  for (var frame = 0; frame < 240; frame += 1) {
    game.world.player.restoreIntegrity(99);
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
