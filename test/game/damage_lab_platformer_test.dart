import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/room_one_controller.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('Damage Lab boots with platform geometry and resets pit falls', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);

    final room = game.world.activeRoom! as RoomOneController;
    expect(room.children.whereType<PlatformSurfaceComponent>(), hasLength(9));
    expect(game.world.player.position, room.playerSpawn);

    game.resumeEngine();
    await tester.pump(const Duration(milliseconds: 16));
    game.world.player.position.y = PatchWorldGame.logicalHeight + 60;
    await tester.pump(const Duration(milliseconds: 16));

    expect(game.world.player.position, room.playerSpawn);
    expect(game.world.player.integrity, game.world.player.maxIntegrity - 1);
  });
}
