import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/settings_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';

void main() {
  testWidgets('exposes release accessibility and locale controls', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final game = PatchWorldGame();
    await game.localization.load('en');
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SettingsOverlay(game: game),
      ),
    );

    expect(find.text('BGM'), findsOneWidget);
    expect(find.text('SFX'), findsOneWidget);
    expect(find.text('Text'), findsOneWidget);
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Assist mode'), findsOneWidget);
    expect(find.text('Reduced flashes'), findsOneWidget);
    expect(find.text('Screen shake'), findsOneWidget);
  });
}
