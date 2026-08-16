import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/survival_item_reward_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_items.dart';

void main() {
  testWidgets('item reward shows three localized choices and synergy tags', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.pendingSurvivalItemReward = const SurvivalItemRewardRequest(
      source: SurvivalItemRewardSource.regionBoss,
      choices: <SurvivalItemId>[
        SurvivalItemId.phaseWhetstone,
        SurvivalItemId.fractureEdge,
        SurvivalItemId.volatileKernel,
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SurvivalItemRewardOverlay(game: game),
      ),
    );

    expect(find.text('SALVAGE ONE PATCH ITEM'), findsOneWidget);
    expect(find.text('Phase Whetstone'), findsOneWidget);
    expect(find.text('Fracture Edge'), findsOneWidget);
    expect(find.text('Volatile Kernel'), findsOneWidget);
    expect(find.textContaining('ATTACK'), findsWidgets);
    expect(find.textContaining('EXPLOSION'), findsWidgets);
    expect(find.text('INSTALL'), findsNWidgets(3));
    for (final key in <String>['J', 'K', 'L']) {
      expect(
        find.byKey(ValueKey<String>('choice-shortcut-$key')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
