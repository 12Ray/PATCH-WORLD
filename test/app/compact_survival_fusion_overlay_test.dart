import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/survival_upgrade_overlay.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';

void main() {
  testWidgets('fusion paths remain scrollable on a compact viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('ko');
    game.pendingSurvivalUpgrade = const SurvivalUpgradeRequest(
      level: 2,
      choices: <PatchDefinition>[
        PatchCatalog.motionTax,
        PatchCatalog.retaliationEcho,
        PatchCatalog.hostileTurbo,
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: SurvivalUpgradeOverlay(game: game)),
      ),
    );

    expect(find.text('퓨전 경로'), findsWidgets);
    expect(find.text('재탐색 x1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
