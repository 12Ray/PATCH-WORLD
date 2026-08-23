import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/game/combat/player_weapon.dart';
import 'package:patch_world/game/components/environment/campaign_service_components.dart';
import 'package:patch_world/game/components/items/item_pedestal_component.dart';
import 'package:patch_world/game/components/presentation/item_discovery_presentation_component.dart';
import 'package:patch_world/game/items/campaign_loadout_reward_catalog.dart';
import 'package:patch_world/game/items/run_item_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/rules/rule_context.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets(
    'chapter terminals install distinct rewards and convert duplicates safely',
    (tester) async {
      final game = PatchWorldGame(initialRoom: RoomId.bootSector);
      await tester.pumpWidget(MaterialApp(home: GameWidget(game: game)));
      await tester.runAsync(game.ready);
      await tester.runAsync(() => game.world.loaded);
      game.resumeEngine();
      await tester.pump(const Duration(milliseconds: 16));
      final owner = game.world.activeRoom!;
      var resolvedCount = 0;

      for (final eventId in CampaignLoadoutEventId.values) {
        for (final weapon in PlayerWeapon.values) {
          game.world.player.configureLoadout(
            weapon,
            assistMode: game.settings.value.assistMode,
          );
          final terminal = LoadoutEventTerminalComponent(
            position: game.world.player.position.clone(),
            eventId: eventId,
            onResolved: () => resolvedCount += 1,
          );
          await tester.runAsync(() async {
            await owner.add(terminal);
            await terminal.loaded;
          });
          game.world.player.position.setFrom(terminal.position);

          expect(terminal.tryResolve(game.world.player), isTrue);
          expect(terminal.tryResolve(game.world.player), isTrue);
          await tester.pump(const Duration(milliseconds: 16));

          final expected = CampaignLoadoutRewardCatalog.rewardFor(
            eventId,
            weapon,
          );
          expect(game.runItems.contains(expected), isTrue);
          expect(
            owner.children
                .whereType<ItemDiscoveryPresentationComponent>()
                .last
                .tierLocalizationKey,
            'itemDiscovery.loadoutEvent',
          );
          terminal.removeFromParent();
        }
      }

      expect(resolvedCount, CampaignLoadoutRewardCatalog.rewards.length);
      expect(game.runItems.items, hasLength(9));
      final player = game.world.player;
      player.configureLoadout(
        PlayerWeapon.sword,
        assistMode: game.settings.value.assistMode,
      );
      final item = CampaignLoadoutRewardCatalog.rewardFor(
        CampaignLoadoutEventId.temporalHall,
        PlayerWeapon.sword,
      );
      game.runItems.acquire(item);
      player.integrity = player.maxIntegrity - 2;
      final maximumBefore = player.maxIntegrity;
      final terminal = LoadoutEventTerminalComponent(
        position: player.position.clone(),
        eventId: CampaignLoadoutEventId.temporalHall,
        onResolved: () {},
      );
      await tester.runAsync(() async {
        await owner.add(terminal);
        await terminal.loaded;
      });
      player.position.setFrom(terminal.position);

      expect(terminal.tryResolve(player), isTrue);
      await tester.pump(const Duration(milliseconds: 16));

      expect(player.maxIntegrity, maximumBefore);
      expect(player.integrity, maximumBefore - 1);
      final presentation = owner.children
          .whereType<ItemDiscoveryPresentationComponent>()
          .last;
      expect(presentation.result.isDuplicate, isTrue);
      expect(
        presentation.tierLocalizationKey,
        'itemDiscovery.duplicateConverted',
      );
      expect(game.runItems.items, hasLength(9));

      game.runItems.acquire(RunItemId.chronalBuffer);
      player.integrity = player.maxIntegrity - 2;
      var collectedCount = 0;
      final pedestal = ItemPedestalComponent(
        position: player.position.clone(),
        item: RunItemId.chronalBuffer,
        onCollected: (_) => collectedCount += 1,
      );
      await tester.runAsync(() async {
        await owner.add(pedestal);
        await pedestal.loaded;
      });
      player.position.setFrom(pedestal.position);
      expect(pedestal.tryCollect(player), isTrue);
      await tester.pump(const Duration(milliseconds: 16));

      expect(collectedCount, 1);
      expect(player.maxIntegrity, maximumBefore);
      expect(player.integrity, maximumBefore - 1);
      expect(
        owner.children
            .whereType<ItemDiscoveryPresentationComponent>()
            .last
            .result
            .isDuplicate,
        isTrue,
      );
      expect(game.runItems.items, hasLength(10));
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
