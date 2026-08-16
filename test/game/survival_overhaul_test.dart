import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/effects/weapon_impact_burst_component.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/components/enemies/survival_anomaly_component.dart';
import 'package:patch_world/game/components/enemies/survival_nexus_boss_component.dart';
import 'package:patch_world/game/components/environment/room_backdrop_component.dart';
import 'package:patch_world/game/components/environment/survival_region_objective_component.dart';
import 'package:patch_world/game/components/environment/survival_terrain_component.dart';
import 'package:patch_world/game/components/projectiles/player_projectile_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/survival_arena_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/survival/survival_weapon_build.dart';
import 'package:patch_world/game/survival/survival_phase_eleven.dart';
import 'package:patch_world/game/survival/survival_items.dart';
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

  test('every survival weapon owns three tiered build branches', () {
    final state = SurvivalWeaponBuildState();
    for (final weapon in PlayerWeapon.values) {
      final choices = state.choicesFor(weapon);
      expect(choices, hasLength(3));
      expect(choices.every((id) => id.weapon == weapon), isTrue);
    }

    expect(state.upgrade(SurvivalWeaponUpgradeId.swordBlinkCircuit), 1);
    expect(state.swordSpecialDistance, greaterThan(108));
    expect(state.upgrade(SurvivalWeaponUpgradeId.gauntletQuakeCore), 1);
    expect(state.gauntletQuakeRadius, greaterThan(92));
    expect(state.upgrade(SurvivalWeaponUpgradeId.gunRailDriver), 1);
    expect(state.gunMaxHits, 2);
  });

  test('new anomaly roster has three distinct health profiles', () {
    final enemies = <SurvivalAnomalyComponent>[
      SurvivalAnomalyComponent(
        entityId: 'rift',
        kind: SurvivalAnomalyKind.riftStalker,
        position: Vector2.zero(),
        onDefeated: () {},
      ),
      SurvivalAnomalyComponent(
        entityId: 'arc',
        kind: SurvivalAnomalyKind.arcWarden,
        position: Vector2.zero(),
        onDefeated: () {},
      ),
      SurvivalAnomalyComponent(
        entityId: 'mine',
        kind: SurvivalAnomalyKind.mineLayer,
        position: Vector2.zero(),
        onDefeated: () {},
      ),
    ];
    expect(enemies.map((enemy) => enemy.health.max).toSet(), {3, 4, 5});
    expect(
      SurvivalAnomalyKind.values.every(
        (kind) => kind.attackTelegraphSeconds >= .45,
      ),
      isTrue,
    );
  });

  testWidgets(
    'survival uses the open nine-times arena and selected gun combat',
    (tester) async {
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
              OverlayIds.survivalWeaponUpgrade: (_, _) =>
                  const SizedBox.shrink(),
              OverlayIds.survivalItemReward: (_, _) => const SizedBox.shrink(),
              OverlayIds.survivalResult: (_, _) => const SizedBox.shrink(),
            },
          ),
        ),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      game.startSurvivalRun(PlayerWeapon.gun);
      await _waitForSurvival(tester, game);

      final arena = game.world.activeRoom! as SurvivalArenaController;
      expect(arena.worldSize, Vector2(2880, 1620));
      expect(
        arena.worldSize.x * arena.worldSize.y,
        PatchWorldGame.logicalWidth * PatchWorldGame.logicalHeight * 9,
      );
      expect(game.world.player.selectedWeapon, PlayerWeapon.gun);
      expect(game.world.player.maxIntegrity, PlayerWeapon.gun.baseIntegrity);
      expect(
        arena.children
            .whereType<RoomBackdropComponent>()
            .single
            .environmentAsset,
        isNull,
      );
      expect(arena.solidBounds, hasLength(4));
      expect(arena.children.whereType<SurvivalHazardZoneComponent>(), isEmpty);
      expect(
        arena.children.whereType<SurvivalRelayPadComponent>(),
        hasLength(4),
      );
      expect(
        arena.children.whereType<SurvivalAnomalyComponent>().any(
          (enemy) => enemy.kind == SurvivalAnomalyKind.riftStalker,
        ),
        isTrue,
      );
      expect(arena.children.whereType<CrawlerComponent>().length, 6);

      game.queueSurvivalItemReward(SurvivalItemRewardSource.regionEvent);
      await tester.pump();
      final itemChoice = game.pendingSurvivalItemReward!.choices.first;
      expect(game.pendingSurvivalItemReward!.choices, hasLength(3));
      expect(game.overlays.isActive(OverlayIds.survivalItemReward), isTrue);
      expect(game.selectSurvivalItem(itemChoice), isTrue);
      await tester.pump();
      expect(game.survivalItems.contains(itemChoice), isTrue);
      expect(game.survivalRun.survivalItemsAcquired, 1);
      expect(game.overlays.isActive(OverlayIds.survivalItemReward), isFalse);
      game.survivalItems
        ..acquire(SurvivalItemId.blastChamber)
        ..acquire(SurvivalItemId.splitProtocol)
        ..acquire(SurvivalItemId.volatileKernel);

      game.world.player.setMovementInput(Vector2(1, 1));
      game.world.player.tryAttack();
      await _pumpUntil(
        tester,
        () => game.world.children
            .whereType<PlayerProjectileComponent>()
            .isNotEmpty,
      );
      final itemProjectile = game.world.children
          .whereType<PlayerProjectileComponent>()
          .first;
      expect(itemProjectile.blastRadius, greaterThan(0));
      expect(itemProjectile.blastDamage, greaterThanOrEqualTo(2));
      expect(game.world.children.whereType<PatchPulseComponent>(), isEmpty);

      for (var frame = 0; frame < 40; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.world.player.trySpecialAbility(1), isTrue);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        game.world.children.whereType<PlayerProjectileComponent>().length,
        greaterThanOrEqualTo(5),
      );
      expect(
        game.world.player.survivalSpecialCooldownRemaining,
        greaterThan(0),
      );

      game.triggerPlayerWeaponImpactFeedback(
        sourceId: 'player.gun.combo.1',
        position: game.world.player.position,
        direction: Vector2(1, 0),
        damage: 1,
      );
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        game.world.children.whereType<WeaponImpactBurstComponent>(),
        isNotEmpty,
      );
      game.world.player.integrity = 999;
      game.survivalRun.elapsedSeconds = 59.9;
      await _pumpUntil(
        tester,
        () =>
            arena.activeRegionEventKind ==
                SurvivalRegionEventKind.relayRepair &&
            arena.children
                .whereType<SurvivalRegionObjectiveComponent>()
                .isNotEmpty,
      );
      expect(arena.activeRegionEventRegion, SurvivalNexusRegion.dataFoundry);
      expect(
        arena.children.whereType<SurvivalRegionObjectiveComponent>(),
        hasLength(1),
      );
      game.world.player.position.setFrom(
        SurvivalNexusRegion.dataFoundry.objectivePosition,
      );
      await _pumpUntil(tester, () => arena.regionEventProgress > .08);

      game.survivalRun.elapsedSeconds = 299.9;
      await _pumpUntil(
        tester,
        () =>
            arena.activeNexusBossKind ==
                SurvivalNexusBossKind.foundryOverseer &&
            arena.children.whereType<SurvivalNexusBossComponent>().isNotEmpty,
      );
      expect(arena.activeRegionEventKind, isNull);
      expect(arena.bossArenaBarrierCount, 4);
      expect(arena.activeBossPatternIds, hasLength(3));
      expect(
        arena.children.whereType<SurvivalNexusBossComponent>(),
        hasLength(1),
      );
    },
  );
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var frame = 0; frame < 100; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    if (condition()) return;
  }
  throw StateError('Timed out waiting for survival overhaul state');
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
