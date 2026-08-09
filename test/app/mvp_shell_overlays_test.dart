import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/title_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('title exposes controls and required destinations', (
    tester,
  ) async {
    final game = PatchWorldGame();
    await game.localization.load('en');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: TitleOverlay(game: game),
      ),
    );
    expect(find.text('PATCH//WORLD'), findsOneWidget);
    expect(find.text('START PATCHING'), findsOneWidget);
    expect(find.text('PATCH//SURVIVE'), findsOneWidget);
    expect(find.text('SETTINGS / ACCESSIBILITY'), findsOneWidget);
    expect(find.text('CREDITS / LICENSES'), findsOneWidget);
    expect(find.textContaining('JUMP'), findsOneWidget);
  });
}
