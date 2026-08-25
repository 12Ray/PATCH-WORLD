import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/boss/optimizer_boss_component.dart';
import 'package:patch_world/game/components/environment/optimizer_arena_stage_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

void main() {
  test(
    'Optimizer breakable platform warns, breaks, and restores collision',
    () {
      final platform = OptimizerPhaseBreakablePlatformComponent(
        position: Vector2(280, 650),
        size: Vector2(150, 22),
      );
      platform.setPhase(OptimizerPhase.predict);

      platform.update(2.2);
      expect(platform.warningProgress, greaterThan(0));
      expect(platform.isSolid, isTrue);
      platform.update(.4);
      expect(platform.isBroken, isTrue);
      expect(platform.isSolid, isFalse);
      platform.update(.7);
      expect(platform.isBroken, isFalse);
      expect(platform.isSolid, isTrue);

      platform.setPhase(OptimizerPhase.overflow);
      platform.update(10);
      expect(platform.isBroken, isFalse);
      expect(platform.isSolid, isTrue);
    },
  );

  test('Perfect laser preserves a readable safe and warning window', () {
    final laser = OptimizerPhaseLaserComponent(
      position: Vector2.zero(),
      size: Vector2(14, 220),
      sourceId: 'boss.optimizer.arenaLaser.test',
    );
    laser.setPhase(OptimizerPhase.perfect);

    expect(laser.isActive, isFalse);
    laser.update(1);
    expect(laser.isActive, isFalse);
    expect(laser.warningProgress, greaterThan(0));
    laser.update(.3);
    expect(laser.isActive, isTrue);

    laser.setPhase(OptimizerPhase.overflow);
    laser.update(10);
    expect(laser.isActive, isFalse);
    expect(laser.warningProgress, 0);
  });

  testWidgets(
    'Optimizer laser uses the inset hitbox and damages once per pulse',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.optimizerCore);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      game.resumeEngine();

      final room = game.world.activeRoom! as BossRoomController;
      final player = game.world.player;
      final initialIntegrity = player.integrity;
      final laser = OptimizerPhaseLaserComponent(
        position: Vector2(
          player.damageHitboxBounds.right + .5,
          player.position.y - 32,
        ),
        size: Vector2(2, 64),
        sourceId: 'test.optimizer-hitbox-and-pulse',
      )..setPhase(OptimizerPhase.predict);
      await room.add(laser);
      await tester.pump(const Duration(milliseconds: 16));
      final laserBounds = Rect.fromLTWH(
        laser.position.x,
        laser.position.y,
        laser.size.x,
        laser.size.y,
      );
      expect(
        laserBounds.overlaps(
          Rect.fromCenter(
            center: Offset(player.position.x, player.position.y),
            width: player.size.x,
            height: player.size.y,
          ),
        ),
        isTrue,
      );
      expect(laserBounds.overlaps(player.damageHitboxBounds), isFalse);

      for (var frame = 0; frame < 18; frame += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(laser.isActive, isTrue);
      expect(player.integrity, initialIntegrity);

      laser.position.setValues(player.position.x - 1, player.position.y - 32);
      laser.onCollisionStart(<Vector2>{}, player);
      expect(player.integrity, initialIntegrity - 1);
      for (var frame = 0; frame < 15; frame += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(laser.isActive, isTrue);
      laser.onCollisionStart(<Vector2>{}, player);
      expect(
        player.integrity,
        initialIntegrity - 1,
        reason: 'Re-entry during one active pulse must not deal a second hit.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test('phase platform moves its visual and collision bounds together', () {
    final platform = OptimizerPhasePlatformComponent(
      start: Vector2(620, 900),
      end: Vector2(620, 660),
      size: Vector2(120, 22),
      periodSeconds: 3.4,
    );
    platform.setPhase(OptimizerPhase.predict);
    platform.update(1.7);

    expect(platform.position.y, isNot(900));
    expect(platform.bounds.left, platform.position.x);
    expect(platform.bounds.top, platform.position.y);
    expect(platform.bounds.size, const Size(120, 22));
  });

  test(
    'arena stage exposes its core only during the collapse presentation',
    () {
      final stage = OptimizerArenaStageComponent(
        worldSize: Vector2(1920, 1080),
      );
      stage.setPhase(OptimizerPhase.perfect);
      expect(stage.isCoreExposed, isFalse);

      stage.setPhase(OptimizerPhase.overflow);
      stage.revealCore();
      expect(stage.isCoreExposed, isTrue);

      stage.setPhase(OptimizerPhase.defeated);
      expect(stage.isCoreExposed, isTrue);
      stage.setPhase(OptimizerPhase.analyze);
      expect(stage.isCoreExposed, isFalse);
    },
  );
}
