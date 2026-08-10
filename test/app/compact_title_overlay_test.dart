import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patch_world/app/overlays/title_overlay.dart';
import 'package:patch_world/game/patch_world_game.dart';
import 'package:patch_world/services/game_settings.dart';

void main() {
  testWidgets('compact title keeps primary destinations on screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 220);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = PatchWorldGame();
    await game.localization.load('en');
    game.settings.value = const GameSettings(
      languageCode: 'en',
      languageSetupComplete: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: TitleOverlay(game: game),
      ),
    );
    expect(find.text('START PATCHING'), findsOneWidget);
    expect(find.text('SETTINGS / ACCESSIBILITY'), findsOneWidget);
    expect(find.text('CREDITS / LICENSES'), findsOneWidget);
    expect(find.textContaining('WASD'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
