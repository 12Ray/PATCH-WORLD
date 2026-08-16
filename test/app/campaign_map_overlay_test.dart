import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/campaign_map_overlay.dart';
import 'package:patch_world/game/campaign/campaign_world_graph.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() => SharedPreferencesAsyncPlatform.instance = null);

  testWidgets('full map and traversal abilities fit in all three locales', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = PatchWorldGame();
    for (final region in CampaignRegion.values) {
      game.campaignExploration.revealRegion(region, game.campaignWorld);
    }
    game.campaignExploration
      ..collectCoreSignature(CampaignRegion.damageLab)
      ..collectCoreSignature(CampaignRegion.temporalHall)
      ..collectCoreSignature(CampaignRegion.collisionArchive);

    for (final locale in const <String>['ko', 'en', 'ja']) {
      await tester.runAsync(() => game.localization.load(locale));
      await tester.pumpWidget(
        MaterialApp(
          home: CampaignMapOverlay(key: ValueKey(locale), game: game),
        ),
      );
      await tester.pump();
      expect(find.byKey(const Key('campaign-map-canvas')), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'locale=$locale');
    }
  });
}
