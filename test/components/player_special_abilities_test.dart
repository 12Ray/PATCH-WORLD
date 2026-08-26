import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/effects/player_strike_component.dart';
import 'package:patch_world/game/components/player/player_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'xyz.luan/audioplayers.global/events',
          (message) async =>
              const StandardMethodCodec().encodeSuccessEnvelope(null),
        );
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler('xyz.luan/audioplayers.global/events', null);
  });

  test('gauntlet charge scales continuously up to ten seconds', () {
    expect(PlayerComponent.gauntletBlastDamageForCharge(0), 1);
    expect(PlayerComponent.gauntletBlastDamageForCharge(5), 3);
    expect(PlayerComponent.gauntletBlastDamageForCharge(10), 6);
    expect(PlayerComponent.gauntletBlastDamageForCharge(20), 6);
    expect(
      PlayerComponent.gauntletBlastRadiusForCharge(10),
      PlayerComponent.gauntletMaximumBlastRadius,
    );
    expect(
      PlayerComponent.gauntletBlastRadiusForCharge(5),
      greaterThan(PlayerComponent.gauntletBlastRadiusForCharge(1)),
    );
  });

  testWidgets('K drives the distinct sword gauntlet and gun specials', (
    tester,
  ) async {
    final game = await _loadCampaignRoom(tester);
    final player = game.world.player..selectWeapon(PlayerWeapon.sword);
    final startingIntegrity = player.integrity;

    // Sword: immediate dash with invulnerability limited to the dash window.
    expect(player.beginSpecialAbility(1), isTrue);
    expect(player.isDashing, isTrue);
    expect(player.isInvulnerable, isTrue);
    player.takeDamage(1);
    expect(player.integrity, startingIntegrity);

    await _pumpFrames(tester, 14);
    expect(player.isDashing, isFalse);
    expect(player.isInvulnerable, isFalse);
    player.takeDamage(1);
    expect(player.integrity, startingIntegrity - 1);

    // Gauntlet: K hold accumulates charge and release creates the blast.
    player.selectWeapon(PlayerWeapon.gauntlet);
    game.input.handleKeyDown(LogicalKeyboardKey.keyK);
    await _pumpFrames(tester, 65);
    expect(player.isGauntletCharging, isTrue);
    expect(player.gauntletChargeSeconds, greaterThan(.8));

    game.input.handleKeyUp(LogicalKeyboardKey.keyK);
    await _pumpFrames(tester, 2);
    expect(player.isGauntletCharging, isFalse);
    expect(
      game.world.children.whereType<PlayerStrikeComponent>().any(
        (strike) => strike.sourceId == 'player.gauntlet.campaign.chargeBurst',
      ),
      isTrue,
    );

    // Gun: K hold channels repeated bounded strikes; release starts cooldown.
    player.selectWeapon(PlayerWeapon.gun);
    game.input.handleKeyDown(LogicalKeyboardKey.keyK);
    await _pumpFrames(tester, 20);
    expect(player.isGunLaserActive, isTrue);
    expect(player.gunLaserRemaining, lessThan(5));
    expect(
      game.world.children.whereType<PlayerStrikeComponent>().any(
        (strike) => strike.sourceId == 'player.gun.campaign.channelLaser',
      ),
      isTrue,
    );

    game.input.handleKeyUp(LogicalKeyboardKey.keyK);
    await _pumpFrames(tester, 2);
    expect(player.isGunLaserActive, isFalse);
    expect(player.gunLaserCooldownRemaining, greaterThan(0));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<PatchWorldGame> _loadCampaignRoom(WidgetTester tester) async {
  final game = PatchWorldGame(initialRoom: RoomId.bootSector);
  await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
  await tester.runAsync(game.ready);
  await tester.runAsync(() => game.world.loaded);
  game.resumeEngine();
  final loading = game.world.loadCampaignNode(
    CampaignNodeId.damageWorkshop,
    entry: CampaignNodeEntry.west,
  );
  for (var frame = 0; frame < 180; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    final room = game.world.activeRoom;
    if (game.world.isReady &&
        room is DamageLabNodeController &&
        room.nodeId == CampaignNodeId.damageWorkshop) {
      await loading;
      return game;
    }
  }
  throw TestFailure('Timed out loading Damage Workshop.');
}

Future<void> _pumpFrames(WidgetTester tester, int count) async {
  for (var frame = 0; frame < count; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}
