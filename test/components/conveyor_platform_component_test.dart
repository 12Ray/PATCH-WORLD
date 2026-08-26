import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/patch_world_game.dart';
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

  testWidgets('grounded player is carried by a Collision Archive conveyor', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.collisionArchive);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    game.resumeEngine();

    final room = game.world.activeRoom! as RegionalCampaignNodeController;
    final conveyor = room.children
        .whereType<ConveyorPlatformComponent>()
        .single;
    final player = game.world.player;
    player.position.setValues(
      conveyor.bounds.center.dx,
      conveyor.bounds.top - player.size.y / 2,
    );
    for (var frame = 0; frame < 8 && !player.isGrounded; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final groundedX = player.position.x;
    expect(player.isGrounded, isTrue);
    expect(
      player.resolvedMovementAnimationState,
      PlayerAnimationState.run,
      reason: 'Conveyor travel must not display a sliding idle pose.',
    );

    for (var frame = 0; frame < 10; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      player.position.x,
      greaterThan(groundedX + 8),
      reason: 'The visible belt direction must produce real gameplay motion.',
    );
    expect(player.isGrounded, isTrue);

    player.position.setValues(
      conveyor.bounds.right + player.size.x / 2 - .75,
      conveyor.bounds.top - player.size.y / 2,
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      player.position.x - player.size.x / 2,
      greaterThanOrEqualTo(conveyor.bounds.right),
      reason: 'A sub-pixel overlap must still be carried fully off the belt.',
    );
    expect(
      player.isGrounded,
      isFalse,
      reason: 'The player must fall instead of hanging from the belt edge.',
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('belt velocity applies only to a body standing on its top face', () {
    final conveyor = ConveyorPlatformComponent(
      position: Vector2(100, 200),
      size: Vector2(180, 22),
      direction: -1,
    );

    expect(
      conveyor.supportVelocityFor(const Rect.fromLTWH(140, 168, 32, 32))?.x,
      -ConveyorPlatformComponent.carrySpeed,
    );
    expect(
      conveyor.supportVelocityFor(const Rect.fromLTWH(140, 150, 32, 32)),
      isNull,
    );
    expect(
      conveyor.supportVelocityFor(const Rect.fromLTWH(300, 168, 32, 32)),
      isNull,
    );
  });

  test('moving and rewind platforms expose one-frame support displacement', () {
    final moving = MovingPlatformComponent(
      start: Vector2(100, 200),
      end: Vector2(100, 100),
      size: Vector2(140, 22),
      periodSeconds: 2,
    );
    const bodyAtMovingStart = Rect.fromLTWH(140, 168, 32, 32);
    moving.update(.25);
    final movingDisplacement = moving.supportDisplacementFor(bodyAtMovingStart);
    expect(movingDisplacement?.y, lessThan(0));
    expect(moving.supportVelocityFor(bodyAtMovingStart), isNull);

    final rewind = RewindPlatformComponent(
      timeline: <Vector2>[Vector2(300, 200), Vector2(360, 150)],
      size: Vector2(140, 22),
      periodSeconds: 2,
    );
    const bodyAtRewindStart = Rect.fromLTWH(330, 168, 32, 32);
    rewind.update(.2);
    final rewindDisplacement = rewind.supportDisplacementFor(bodyAtRewindStart);
    expect(rewindDisplacement?.length2, greaterThan(0));
  });
}
