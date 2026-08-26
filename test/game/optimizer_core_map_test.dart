import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlay_ids.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/environment/optimizer_arena_stage_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/story_room_layers_component.dart';
import 'package:patch_world/game/components/projectiles/player_projectile_component.dart';
import 'package:patch_world/game/components/projectiles/enemy_projectile_component.dart';
import 'package:patch_world/game/components/presentation/boss_arena_presentation_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

void main() {
  testWidgets('Optimizer Core is a side-view weapon arena', (tester) async {
    final game = PatchWorldGame(initialRoom: RoomId.optimizerCore);
    await tester.pumpWidget(
      MaterialApp(
        home: GameWidget<PatchWorldGame>(
          game: game,
          overlayBuilderMap: <String, OverlayWidgetBuilder<PatchWorldGame>>{
            OverlayIds.ending: (_, _) => const SizedBox.shrink(),
          },
        ),
      ),
    );
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    await tester.pump();

    final room = game.world.activeRoom! as BossRoomController;
    final geometry = room as PlatformerRoomGeometry;
    expect(game.world.player.position, Vector2(180, 988));
    expect(geometry.worldSize, Vector2(1920, 1080));
    expect(geometry.killPlaneY, greaterThan(geometry.worldSize.y));
    expect(
      room.children.whereType<PlatformSurfaceComponent>(),
      hasLength(greaterThanOrEqualTo(18)),
    );
    final layers = room.children.whereType<StoryRoomLayersComponent>().single;
    expect(layers.theme, StoryRegionVisualTheme.optimizer);
    expect(layers.motif, StoryRoomVisualMotif.finalCore);
    expect(
      room.children
          .whereType<PlatformSurfaceComponent>()
          .where((surface) => !surface.isBoundary)
          .every((surface) => surface.renderArtwork),
      isTrue,
    );
    expect(room.children.whereType<RoomHazardComponent>(), hasLength(2));
    expect(room.children.whereType<JumpPadComponent>(), hasLength(2));
    expect(
      room.children.whereType<OptimizerArenaStageComponent>(),
      hasLength(1),
    );
    expect(room.phasePlatforms, hasLength(2));
    expect(room.breakablePlatforms, hasLength(2));
    expect(room.phaseLasers, hasLength(2));
    for (final x in <double>[560, 1318]) {
      final pillar = room.children
          .whereType<PlatformSurfaceComponent>()
          .singleWhere((surface) => surface.position.x == x);
      expect(pillar.isBoundary, isFalse);
      expect(pillar.renderArtwork, isTrue);
      expect(pillar.isSolid, isTrue);
    }
    expect(room.boss.position, Vector2(960, 330));
    expect(room.terminal.position, Vector2(960, 500));
    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(room.isBossIntroActive, isTrue);
    expect(room.boss.isEncounterActive, isFalse);
    expect(room.cameraZoomFor(game.world.player.position), .9);
    expect(room.keepsPlayerInsideHorizontalSafeArea, isTrue);
    final introTarget = room.cameraTargetFor(game.world.player.position);
    expect(introTarget.x, closeTo(400, .5));
    expect(introTarget.y, closeTo(818, .5));
    expect(room.children.whereType<BossNameCardComponent>(), isNotEmpty);

    game.world.player.configureLoadout(PlayerWeapon.gun, assistMode: false);
    game.world.player.tryAttack();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    expect(
      game.world.children.whereType<PlayerProjectileComponent>(),
      isNotEmpty,
    );
    expect(game.world.children.whereType<PatchPulseComponent>(), isEmpty);

    for (var frame = 0; frame < 60; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(room.boss.isEncounterActive, isTrue);
    final combatTarget = room.cameraTargetFor(game.world.player.position);
    final expectedMidpoint =
        (game.world.player.position + room.boss.position) / 2;
    expect(combatTarget.x, closeTo(expectedMidpoint.x, .01));
    expect(combatTarget.y, closeTo(expectedMidpoint.y, .01));
    expect(
      room.cameraZoomFor(game.world.player.position),
      inInclusiveRange(.9, 1.06),
    );

    game.world.player.configureLoadout(PlayerWeapon.gauntlet, assistMode: true);
    room.boss.receiveDamage(99);
    expect(room.boss.health, 13);
    expect(room.boss.phase, OptimizerPhase.analyze);
    for (
      var frame = 0;
      frame < 160 && room.boss.phase == OptimizerPhase.analyze;
      frame += 1
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(room.boss.phase, OptimizerPhase.predict);
    expect(
      room.boss.resolvedPatternCount(OptimizerPhase.analyze),
      greaterThanOrEqualTo(2),
    );
    final optimizerProjectiles = room.children
        .whereType<EnemyProjectileComponent>()
        .toList(growable: false);
    expect(optimizerProjectiles, isNotEmpty);
    expect(
      optimizerProjectiles.every(
        (projectile) =>
            projectile.sourceId ==
                OptimizerAttackPattern.analysisRing.sourceId &&
            projectile.assetSlug == null,
      ),
      isTrue,
    );
    expect(room.arenaStage.phase, OptimizerPhase.predict);
    expect(
      room.phasePlatforms.every(
        (platform) => platform.phase == OptimizerPhase.predict,
      ),
      isTrue,
    );
    room.boss.receiveDamage(99);
    expect(room.boss.health, 6);
    expect(room.boss.phase, OptimizerPhase.predict);
    for (
      var frame = 0;
      frame < 160 && room.boss.phase == OptimizerPhase.predict;
      frame += 1
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(room.boss.phase, OptimizerPhase.perfect);
    expect(
      room.boss.resolvedPatternCount(OptimizerPhase.predict),
      greaterThanOrEqualTo(2),
    );
    expect(room.terminal.isEnabled, isTrue);
    final terminalFocus = room.cameraTargetFor(game.world.player.position);
    expect(terminalFocus.y, greaterThan(500));
    expect(room.cameraZoomFor(game.world.player.position), .92);
    expect(room.arenaStage.phase, OptimizerPhase.perfect);
    expect(
      room.phaseLasers.every((laser) => laser.phase == OptimizerPhase.perfect),
      isTrue,
    );

    final attacksBeforePerfect = room.boss.recentPatterns.length;
    for (var frame = 0; frame < 60; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(room.boss.phase, OptimizerPhase.perfect);
    expect(room.boss.recentPatterns.length, greaterThan(attacksBeforePerfect));
    expect(room.boss.recentPatterns.last.phase, OptimizerPhase.perfect);

    room.boss.receiveHealing(4);
    expect(room.boss.phase, OptimizerPhase.overflow);
    expect(room.phaseLasers.every((laser) => !laser.isActive), isTrue);
    for (var frame = 0; frame < 30; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(room.boss.isCoreExposed, isTrue);
    expect(room.arenaStage.isCoreExposed, isTrue);
    for (var frame = 0; frame < 40; frame += 1) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(room.boss.phase, OptimizerPhase.defeated);
    expect(room.arenaStage.isCoreExposed, isTrue);
  });
}
