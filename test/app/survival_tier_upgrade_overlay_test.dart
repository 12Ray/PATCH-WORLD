import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/survival_upgrade_overlay.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_upgrade_request.dart';

void main() {
  testWidgets('card describes the actual next tier interaction', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.survivalRun.upgradePatch(PatchCatalog.motionTax.id, riskTier: 1);
    game.survivalRun
      ..upgradePatch(PatchCatalog.phaseLeak.id, riskTier: 2)
      ..upgradePatch(PatchCatalog.phaseLeak.id, riskTier: 2);
    game.pendingSurvivalUpgrade = const SurvivalUpgradeRequest(
      level: 3,
      choices: <PatchDefinition>[PatchCatalog.motionTax],
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: SurvivalUpgradeOverlay(game: game)),
      ),
    );

    expect(find.textContaining('TIER 2'), findsOneWidget);
    expect(find.textContaining('Stand still for 0.75s'), findsOneWidget);
    expect(
      find.textContaining('overheating still causes damage'),
      findsOneWidget,
    );
    expect(find.text('FUSION READY'), findsOneWidget);
    expect(find.text('GHOST VENT'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
