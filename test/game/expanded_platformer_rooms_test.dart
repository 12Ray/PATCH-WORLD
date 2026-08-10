import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('wide platformer map uses features and a tracking camera', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.damageLab);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final room = game.world.activeRoom! as PlatformerRoomGeometry;
    expect(room.worldSize, Vector2(2880, 1080));
    expect(
      game.world.activeRoom!.children.whereType<RoomHazardComponent>(),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      game.world.activeRoom!.children.whereType<JumpPadComponent>(),
      hasLength(greaterThanOrEqualTo(2)),
    );
    expect(
      game.world.activeRoom!.children.whereType<CheckpointBeaconComponent>(),
      hasLength(2),
    );

    final firstCheckpoint = game.world.activeRoom!.children
        .whereType<CheckpointBeaconComponent>()
        .first;
    game.resumeEngine();
    game.world.player.position.setValues(
      firstCheckpoint.position.x,
      firstCheckpoint.position.y - 28,
    );
    game.update(.016);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(firstCheckpoint.isActive, isTrue);
    expect(
      room.respawnPointFor(Vector2(2500, room.killPlaneY)).x,
      closeTo(firstCheckpoint.position.x, 1),
    );

    game.world.player.position.x = 1500;
    game.world.player.position.y = 540;
    game.update(.016);
    expect(game.camera.viewfinder.position.x, closeTo(1500, .01));
    expect(game.camera.viewfinder.position.y, closeTo(540, 1));
    expect(room.killPlaneY, greaterThan(room.worldSize.y));
  });
}
