import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/survival_upgrade_overlay.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';

void main() {
  testWidgets('survival cards explain both power and side effect', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await game.localization.load('en');
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

    expect(find.text('LEVEL 2 // CHOOSE A PATCH'), findsOneWidget);
    expect(find.text('FIX / POWER'), findsNWidgets(3));
    expect(find.text('SIDE EFFECT'), findsNWidgets(3));
    expect(find.textContaining('Pulse deals +1 damage'), findsOneWidget);
    expect(find.textContaining('Moving builds Heat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
