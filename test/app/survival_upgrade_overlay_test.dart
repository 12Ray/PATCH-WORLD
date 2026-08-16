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
    for (var index = 0; index < 20; index += 1) {
      game.survivalRun.recordKill();
    }
    expect(game.survivalRun.takePendingUpgradeLevel(), 2);
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
    expect(find.text('REROUTE x1'), findsOneWidget);
    expect(find.text('PATCH CHAIN // 2 PICKS REMAIN'), findsOneWidget);
    for (final key in <String>['J', 'K', 'L']) {
      expect(
        find.byKey(ValueKey<String>('choice-shortcut-$key')),
        findsOneWidget,
      );
    }
    expect(find.text('FRAME BURST'), findsNothing);
    await tester.tap(find.byKey(const ValueKey<String>('survival-reroute')));
    await tester.pump();
    expect(find.text('REROUTE x0'), findsOneWidget);
    expect(find.text('PATCH CHAIN // 2 PICKS REMAIN'), findsOneWidget);
    expect(find.text('MOTION TAX'), findsNothing);
    expect(find.text('FRAME BURST'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
