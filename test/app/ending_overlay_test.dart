import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/ending_overlay.dart';
import 'package:patch_world/game/core/run_metrics.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('ending renders both choices and the completed run summary', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await game.localization.load('en');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: EndingOverlay(game: game),
      ),
    );
    expect(find.text('PRESERVE THE GLITCH'), findsOneWidget);
    expect(find.text('PURGE THE ARCHIVE'), findsOneWidget);
    game.completedRun.value = const RunSummary(
      elapsedSeconds: 72,
      deaths: 1,
      damageTaken: 3,
      overflowCount: 3,
      score: 1800,
      selectedPatchIds: <String>['patch.motion_tax'],
      endingId: 'preserve',
    );
    game.bestScore = 1800;
    await tester.pump();
    expect(find.text('RUN SUMMARY'), findsOneWidget);
    expect(find.text('1:12'), findsOneWidget);
    expect(find.text('1800'), findsNWidgets(2));
  });
}
