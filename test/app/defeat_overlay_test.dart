import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/defeat_overlay.dart';
import 'package:patch_world/game/core/run_metrics.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('defeat overlay offers Assist after three failures', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.defeatSnapshot.value = const DefeatSnapshot(
      causeId: 'enemy.sentinel.projectile',
      deathStreak: 3,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: DefeatOverlay(game: game),
      ),
    );
    expect(find.text('SYSTEM FAILURE'), findsOneWidget);
    expect(find.text('ENABLE ASSIST & RETRY'), findsOneWidget);
  });
}
