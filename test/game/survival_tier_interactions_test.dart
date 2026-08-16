import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:patch_world/game/systems/duplicate_fault_system.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('tier interactions alter combat and chain duplicate bursts', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget<PatchWorldGame>(
          game: game,
          overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
            OverlayIds.title: (_, _) => const SizedBox.shrink(),
            OverlayIds.hud: (_, _) => const SizedBox.shrink(),
            OverlayIds.touchControls: (_, _) => const SizedBox.shrink(),
            OverlayIds.survivalUpgrade: (_, _) => const SizedBox.shrink(),
            OverlayIds.survivalWeaponUpgrade: (_, _) => const SizedBox.shrink(),
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(
      game.world
          .survivalCrowdSteering(
            entityId: 'campaign-probe',
            position: Vector2.zero(),
            separationRadius: CrawlerComponent.survivalSeparationRadius,
          )
          .length2,
      0,
    );
    game.startSurvivalRun();
    await _waitForSurvival(tester, game);
    game.world.player.integrity = 999;

    final arena = game.world.activeRoom! as SurvivalArenaController;
    final overlapOrigin = game.world.player.position + Vector2(120, 0);
    final crowdA = CrawlerComponent(
      entityId: 'crowd-a',
      position: overlapOrigin.clone(),
      initialHealth: 99,
      healthMaximum: 99,
    );
    final crowdB = CrawlerComponent(
      entityId: 'crowd-b',
      position: overlapOrigin.clone(),
      initialHealth: 99,
      healthMaximum: 99,
    );
    await arena.addAll(<CrawlerComponent>[crowdA, crowdB]);
    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(crowdA.position.distanceTo(crowdB.position), greaterThan(8));
    crowdA.removeFromParent();
    crowdB.removeFromParent();

    game.runState.selectPatch(RuleIds.motionTax);
    game.survivalRun
      ..upgradePatch(RuleIds.motionTax, riskTier: 1)
      ..upgradePatch(RuleIds.motionTax, riskTier: 1);
    for (var frame = 0; frame < 14; frame += 1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(game.patchEffects.motionVentCharged, isTrue);
    final ventTarget = CrawlerComponent(
      entityId: 'weapon-vent-target',
      position: game.world.player.position + Vector2(32, 0),
      initialHealth: 99,
      healthMaximum: 99,
    );
    await arena.add(ventTarget);
    game.world.player.tryAttack();
    await _pumpUntil(tester, () => ventTarget.health < 99);
    expect(99 - ventTarget.health, 5);
    for (var frame = 0; frame < 4; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    game.runState.selectPatch(RuleIds.hostileTurbo);
    for (var tier = 0; tier < 3; tier += 1) {
      game.survivalRun.upgradePatch(RuleIds.hostileTurbo, riskTier: 2);
    }
    game.recordSurvivalKill();
    expect(game.survivalRun.turboOverclockActive, isTrue);

    game.runState.selectPatch(RuleIds.duplicateFault);
    game.survivalRun
      ..upgradePatch(RuleIds.duplicateFault, riskTier: 3)
      ..upgradePatch(RuleIds.duplicateFault, riskTier: 3);
    final target = CrawlerComponent(
      entityId: 'burst-target',
      position: game.world.player.position + Vector2(60, 0),
      initialHealth: 3,
      healthMaximum: 3,
    );
    await arena.add(target);
    await game.world.spawnDuplicate(
      archetype: DuplicateArchetype.crawler,
      position: game.world.player.position,
      sourceEntityId: 'tier-burst-source',
    );
    await tester.pump(const Duration(milliseconds: 16));
    final duplicate = arena.children.whereType<CrawlerComponent>().singleWhere(
      (crawler) => crawler.entityId == 'tier-burst-source.echo',
    );
    target.position.setFrom(duplicate.position);
    duplicate.receiveDamage(1);
    for (var frame = 0; frame < 5; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(target.health, 2);
  });
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 60; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (condition()) return;
  }
  throw StateError('Timed out waiting for weapon impact');
}

Future<void> _waitForSurvival(WidgetTester tester, PatchWorldGame game) async {
  for (var attempt = 0; attempt < 120; attempt += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    if (game.currentRoom == RoomId.survivalArena &&
        game.world.isReady &&
        !game.paused) {
      return;
    }
  }
  throw StateError('Timed out waiting for survival arena');
}
