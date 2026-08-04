import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/survival_result_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/game/survival/survival_run_state.dart';

void main() {
  testWidgets('survival result presents run stats and retry choices', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.survivalResult.value = const SurvivalResultSnapshot(
      elapsedSeconds: 91,
      kills: 42,
      eliteKills: 1,
      miniBossKills: 0,
      score: 4242,
      maxCombo: 12,
      patchTiers: <String, int>{'patch.motion_tax': 2},
      riskMultiplier: 1.24,
      firstPatchId: 'patch.motion_tax',
      isBestScore: true,
      isBestTime: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SurvivalResultOverlay(game: game),
      ),
    );

    expect(find.text('RUN OVER // SYSTEM COLLAPSE'), findsOneWidget);
    expect(find.text('1:31'), findsOneWidget);
    expect(find.text('4242'), findsOneWidget);
    expect(find.text('MOTION TAX  T2'), findsOneWidget);
    expect(find.text('INSTANT RETRY'), findsOneWidget);
    expect(find.text('KEEP FIRST PATCH'), findsOneWidget);
  });
}
