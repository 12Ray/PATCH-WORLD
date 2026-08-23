import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/components/enemies/crawler_component.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rooms/regional_campaign_node_controller.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:patch_world/game/rules/rule_ids.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'a single J tap completes its weapon impact while Temporal Hall is stopped',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.temporalHall);
      await tester.pumpWidget(
        MaterialApp(home: GameWidget<PatchWorldGame>(game: game)),
      );
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);

      final room = game.world.activeRoom! as RegionalCampaignNodeController;
      expect(room.campaignNodeId, CampaignNodeId.temporalAscent);
      expect(room.layout, same(game.regionalRoomLayouts.room(room.nodeId)));

      // Entering Temporal Hall normally removes the Damage Lab anomaly.
      game.ruleEngine.removeRule(RuleIds.damageSignInverted);
      final target = CrawlerComponent(
        entityId: 'temporal-single-tap-target',
        position: game.world.player.position + Vector2(34, 0),
        initialHealth: 10,
        healthMaximum: 10,
        canDuplicate: false,
      );
      await tester.runAsync(() async {
        await game.world.activeRoom!.add(target);
      });
      game.update(0);
      await tester.runAsync(() => target.mounted);

      game.resumeEngine();
      await tester.pump(const Duration(milliseconds: 16));
      expect(game.clock.isSimulationFrozen, isTrue);

      game.input.handleKeyDown(LogicalKeyboardKey.keyJ);
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        game.input.hasGameplayIntent,
        isFalse,
        reason: 'the J tap must be consumed after starting the attack',
      );
      expect(game.world.player.hasActiveWeaponAction, isTrue);

      for (var frame = 0; frame < 60 && target.health == 10; frame += 1) {
        await tester.pump(const Duration(milliseconds: 16));
      }

      expect(
        target.health,
        lessThan(10),
        reason: 'the queued contact must resolve without another input',
      );
      expect(game.input.hasGameplayIntent, isFalse);

      for (
        var frame = 0;
        frame < 60 && game.world.player.hasActiveWeaponAction;
        frame += 1
      ) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(game.world.player.hasActiveWeaponAction, isFalse);
      expect(game.world.player.canAttack, isTrue);

      await tester.pump(const Duration(milliseconds: 16));
      expect(
        game.clock.isSimulationFrozen,
        isTrue,
        reason: 'idle Temporal Hall must freeze again after the action ends',
      );
    },
  );
}
