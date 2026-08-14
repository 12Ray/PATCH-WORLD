import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/pause_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('pause menu exposes resume, restart, and title actions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 540);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('en');

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: PauseOverlay(game: game),
      ),
    );

    expect(find.text('RESUME'), findsOneWidget);
    expect(find.text('RESTART ROOM'), findsOneWidget);
    expect(find.text('TITLE SCREEN'), findsOneWidget);
    expect(find.byIcon(Icons.home_outlined), findsOneWidget);
  });
}
