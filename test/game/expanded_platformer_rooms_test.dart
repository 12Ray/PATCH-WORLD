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
    expect(room.worldSize, Vector2(2880, 540));
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

    game.world.player.position.x = 1500;
    game.update(.016);
    expect(game.camera.viewfinder.position.x, closeTo(1500, .01));
    expect(room.respawnPointFor(Vector2(1500, 600)).x, greaterThan(960));
  });
}
