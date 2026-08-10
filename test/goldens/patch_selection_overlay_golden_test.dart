import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/patch_selection_overlay.dart';
import 'package:patch_world/game/core/run_state.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('Room 1 patch selection visual', (tester) async {
    final previousComparator = goldenFileComparator;
    goldenFileComparator = _TolerantGoldenFileComparator(
      Uri.parse('test/goldens/patch_selection_overlay_golden_test.dart'),
      precisionTolerance: 0.025,
    );
    addTearDown(() => goldenFileComparator = previousComparator);

    final game = PatchWorldGame()
      ..pendingPatchSelection = const PatchSelectionRequest(
        roomId: 'damage-lab',
        choices: PatchCatalog.roomOneChoices,
      );
    await game.localization.load('en');
    await tester.binding.setSurfaceSize(const Size(960, 540));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: RepaintBoundary(child: PatchSelectionOverlay(game: game)),
      ),
    );

    expect(find.text('MOTION TAX'), findsOneWidget);
    expect(find.text('RETALIATION ECHO'), findsOneWidget);
    expect(find.text('SELECT PATCH'), findsNWidgets(2));

    await expectLater(
      find.byType(PatchSelectionOverlay),
      matchesGoldenFile('files/patch_selection_en_100.png'),
    );
  });
}

final class _TolerantGoldenFileComparator extends LocalFileComparator {
  _TolerantGoldenFileComparator(
    super.testFile, {
    required double precisionTolerance,
  }) : assert(precisionTolerance >= 0 && precisionTolerance <= 1),
       _precisionTolerance = precisionTolerance;

  final double _precisionTolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _precisionTolerance) {
      result.dispose();
      return true;
    }

    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}
