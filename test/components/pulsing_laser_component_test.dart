import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
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
    'Temporal freeze pauses warning and inactive overlap takes one active-edge hit',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.temporalHall);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      game.resumeEngine();

      final player = game.world.player;
      player.restoreIntegrity(99);
      final laser = PulsingLaserComponent(
        position: player.position - Vector2(8, 32),
        size: Vector2(16, 64),
        sourceId: 'test.temporal-warned-laser',
        activeSeconds: .4,
        inactiveSeconds: .4,
        startupGraceSeconds: .25,
      );
      final movingPlatform = MovingPlatformComponent(
        start: Vector2(500, 500),
        end: Vector2(700, 500),
        size: Vector2(120, 22),
        periodSeconds: 2,
        style: PlatformSurfaceStyle.temporal,
      );
      final rewindPlatform = RewindPlatformComponent(
        timeline: <Vector2>[
          Vector2(500, 600),
          Vector2(700, 540),
          Vector2(900, 600),
        ],
        size: Vector2(120, 22),
        periodSeconds: 2,
        style: PlatformSurfaceStyle.temporal,
      );
      final crusher = CrusherHazardComponent(
        start: Vector2(1100, 400),
        end: Vector2(1100, 600),
        size: Vector2(86, 64),
        sourceId: 'test.temporal-crusher',
        periodSeconds: 2,
        style: PlatformSurfaceStyle.temporal,
      );
      await game.world.activeRoom!.add(laser);
      await game.world.activeRoom!.addAll(<Component>[
        movingPlatform,
        rewindPlatform,
        crusher,
      ]);
      await tester.pump(const Duration(milliseconds: 16));
      final initialIntegrity = player.integrity;
      final initialGrace = laser.startupGraceRemaining;
      final initialMovingPosition = movingPlatform.position.clone();
      final initialRewindPosition = rewindPlatform.position.clone();
      final initialCrusherPosition = crusher.position.clone();

      await tester.pump(const Duration(milliseconds: 500));
      expect(game.clock.isSimulationFrozen, isTrue);
      expect(laser.startupGraceRemaining, initialGrace);
      expect(laser.isActive, isFalse);
      expect(player.integrity, initialIntegrity);
      expect(movingPlatform.position, initialMovingPosition);
      expect(rewindPlatform.position, initialRewindPosition);
      expect(crusher.position, initialCrusherPosition);

      game.input.setVirtualMovement(.01, 0);
      for (var frame = 0; frame < 6; frame += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      game.input.clearVirtualMovement();
      expect(laser.isInStartupGrace, isFalse);
      expect(laser.isActive, isTrue);
      expect(player.integrity, initialIntegrity - 1);
      expect(player.lastDamageCauseId, laser.sourceId);
      expect(movingPlatform.position, isNot(initialMovingPosition));
      expect(rewindPlatform.position, isNot(initialRewindPosition));
      expect(crusher.position, isNot(initialCrusherPosition));

      await tester.pump(const Duration(milliseconds: 100));
      expect(
        player.integrity,
        initialIntegrity - 1,
        reason: 'One laser pulse must not deal frame-by-frame damage.',
      );
      laser.removeFromParent();
      for (var frame = 0; frame < 15; frame += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      final edgeIntegrity = player.integrity;
      final edgeLaser = PulsingLaserComponent(
        position: Vector2(
          player.damageHitboxBounds.right + .5,
          player.position.y - 32,
        ),
        size: Vector2(2, 64),
        sourceId: 'test.temporal-hitbox-edge',
        activeSeconds: .3,
        inactiveSeconds: .3,
        startupGraceSeconds: .1,
      );
      await game.world.activeRoom!.add(edgeLaser);
      await tester.pump(const Duration(milliseconds: 16));
      final laserBounds = Rect.fromLTWH(
        edgeLaser.position.x,
        edgeLaser.position.y,
        edgeLaser.size.x,
        edgeLaser.size.y,
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
        reason: 'The probe must overlap the old full-body polling bounds.',
      );
      expect(laserBounds.overlaps(player.damageHitboxBounds), isFalse);

      game.input.setVirtualMovement(.01, 0);
      for (var frame = 0; frame < 4; frame += 1) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      game.input.clearVirtualMovement();

      expect(edgeLaser.isActive, isTrue);
      expect(
        player.integrity,
        edgeIntegrity,
        reason: 'Active-edge polling must use the inset collision hitbox.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
