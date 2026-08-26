import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_traversal_ability.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/platform_surface_component.dart';
import 'package:patch_world/game/components/environment/terrain_pulse_node_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/damage_lab_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('air dash is progression-gated and refreshes after landing', (
    tester,
  ) async {
    final game = PatchWorldGame(initialRoom: RoomId.bootSector);
    await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
    await tester.runAsync(game.ready);
    await tester.runAsync(() => game.world.loaded);
    await _loadDamageNode(tester, game, CampaignNodeId.damageWorkshop);

    final player = game.world.player..selectWeapon(PlayerWeapon.gun);
    player.position.setValues(700, 350);
    await tester.pump(const Duration(milliseconds: 16));
    expect(player.tryTraversalAirDash(1), isFalse);

    game.campaignExploration.unlockTraversalAbility(
      CampaignTraversalAbility.airDash,
    );
    expect(player.tryTraversalAirDash(1), isTrue);
    expect(player.traversalAirDashesRemaining, 0);
    expect(player.tryTraversalAirDash(1), isFalse);
  });

  test('terrain pulse bridge collision matches its visual activation', () {
    final bridge = TerrainPulseBridgeComponent(
      position: Vector2.zero(),
      size: Vector2(190, 20),
      style: PlatformSurfaceStyle.collision,
    );
    expect(bridge.isSolid, isFalse);
    bridge.activate();
    expect(bridge.isSolid, isTrue);
  });

  test('terrain pulse prompt explains its progression lock', () {
    expect(
      terrainPulsePromptLocalizationKey(isUnlocked: false),
      'interaction.terrainPulseLocked',
    );
    expect(
      terrainPulsePromptLocalizationKey(isUnlocked: true),
      'interaction.terrainPulse',
    );
  });
}

Future<DamageLabNodeController> _loadDamageNode(
  WidgetTester tester,
  PatchWorldGame game,
  CampaignNodeId nodeId,
) async {
  game.resumeEngine();
  final loading = game.world.loadCampaignNode(
    nodeId,
    entry: CampaignNodeEntry.west,
  );
  for (var frame = 0; frame < 180; frame += 1) {
    await tester.pump(const Duration(milliseconds: 16));
    final room = game.world.activeRoom;
    if (game.world.isReady &&
        room is DamageLabNodeController &&
        room.nodeId == nodeId) {
      await loading;
      return room;
    }
  }
  throw TestFailure('Timed out loading $nodeId');
}
