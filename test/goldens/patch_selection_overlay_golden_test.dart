import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/patch_selection_overlay.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('Room 1 patch selection visual', (tester) async {
    final game = PatchWorldGame()
      ..pendingPatchSelection = const PatchSelectionRequest(
        roomId: 'damage-lab',
        choices: PatchCatalog.roomOneChoices,
      );
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(child: PatchSelectionOverlay(game: game)),
      ),
    );
    await expectLater(
      find.byType(PatchSelectionOverlay),
      matchesGoldenFile('files/patch_selection_en_100.png'),
    );
  });
}
