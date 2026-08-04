import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/patch_selection_overlay.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('shows both Room 1 patch choices and their tradeoffs', (
    tester,
  ) async {
    final game = PatchWorldGame()
      ..pendingPatchSelection = const PatchSelectionRequest(
        roomId: 'damage-lab',
        choices: PatchCatalog.roomOneChoices,
      );

    await tester.pumpWidget(
      MaterialApp(home: PatchSelectionOverlay(game: game)),
    );

    expect(find.text('MOTION TAX'), findsOneWidget);
    expect(find.text('RETALIATION ECHO'), findsOneWidget);
    expect(find.text('FIX'), findsNWidgets(2));
    expect(find.text('SIDE EFFECT'), findsNWidgets(2));
    expect(find.text('TACTIC'), findsNWidgets(2));
    expect(find.text('APPLY PATCH'), findsNWidgets(2));
  });
}
