import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
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

  testWidgets('all three weapons keep a stationary grounded gameplay body', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    final player = game.world.player;
    game.resumeEngine();
    final room = game.world.activeRoom! as PlatformerRoomGeometry;

    for (final weapon in PlayerWeapon.values) {
      player.configureLoadout(weapon, assistMode: false);
      player.position.setFrom(room.playerSpawn);
      player.resetMotionForRoomTransition();
      for (var frame = 0; frame < 45 && !player.isGrounded; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(player.isGrounded, isTrue, reason: '${weapon.name} did not land');

      final bodyStart = player.position.clone();
      for (var frame = 0; frame < 30; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(player.position.x, closeTo(bodyStart.x, .001));
      expect(player.position.y, closeTo(bodyStart.y, .001));
    }

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
