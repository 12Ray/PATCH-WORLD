import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/effects/patch_pulse_component.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/platformer_room_feature_component.dart';
import 'package:patch_world/game/components/projectiles/player_projectile_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/platformer_room_geometry.dart';
import 'package:patch_world/game/rooms/boss_room_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';

void main() {
  testWidgets('Optimizer Core is a side-view weapon arena', (tester) async {
    final game = PatchWorldGame(initialRoom: RoomId.optimizerCore);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
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
    expect(room.children.whereType<RoomHazardComponent>(), hasLength(2));
    expect(room.children.whereType<JumpPadComponent>(), hasLength(2));
    expect(room.boss.position, Vector2(960, 330));
    expect(room.terminal.position, Vector2(960, 980));

    game.world.player.configureLoadout(PlayerWeapon.gun, assistMode: false);
    game.resumeEngine();
    game.world.player.tryAttack();
    await tester.pump(const Duration(milliseconds: 1));
    expect(
      game.world.children.whereType<PlayerProjectileComponent>(),
      isNotEmpty,
    );
    expect(game.world.children.whereType<PatchPulseComponent>(), isEmpty);
  });
}
