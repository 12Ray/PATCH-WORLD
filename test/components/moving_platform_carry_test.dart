import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
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

  testWidgets('grounded player stays attached to a moving platform', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.collisionArchive);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    game.resumeEngine();

    final room = game.world.activeRoom! as RegionalCampaignNodeController;
    final platform = room.children.whereType<MovingPlatformComponent>().first;
    final player = game.world.player;
    player.position.setValues(
      platform.bounds.center.dx,
      platform.bounds.top - player.size.y / 2,
    );
    for (var frame = 0; frame < 12 && !player.isGrounded; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(player.isGrounded, isTrue);
    final relativeX = player.position.x - platform.position.x;
    final platformStartX = platform.position.x;

    for (var frame = 0; frame < 30; frame += 1) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(platform.position.x, greaterThan(platformStartX + 5));
    expect(player.position.x - platform.position.x, closeTo(relativeX, .75));
    expect(player.isGrounded, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
